package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

var (
	teal         = lipgloss.AdaptiveColor{Dark: "#55d6c2", Light: "#087f73"}
	amber        = lipgloss.AdaptiveColor{Dark: "#f2bd62", Light: "#a05b00"}
	charcoal     = lipgloss.AdaptiveColor{Dark: "#111719", Light: "#f1f4f2"}
	muted        = lipgloss.AdaptiveColor{Dark: "#80918f", Light: "#536260"}
	ink          = lipgloss.AdaptiveColor{Dark: "#e8f0ed", Light: "#182220"}
	danger       = lipgloss.AdaptiveColor{Dark: "#ef8278", Light: "#a52f2b"}
	line         = lipgloss.AdaptiveColor{Dark: "#29403e", Light: "#c7d4d0"}
	titleStyle   = lipgloss.NewStyle().Bold(true).Foreground(teal)
	mutedStyle   = lipgloss.NewStyle().Foreground(muted)
	card         = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(line).Padding(1, 2)
	selectedCard = card.BorderForeground(teal)
)

type Config struct{ DriveFolderID, DesktopPath, LinkName, RcloneRemote string }

func loadConfig() Config {
	home, _ := os.UserHomeDir()
	cfg := Config{DesktopPath: filepath.Join(home, "Desktop"), LinkName: "DesktopArchive", RcloneRemote: "gdrive"}
	for k, dst := range map[string]*string{
		"PKARCHIVES_DRIVE_FOLDER_ID": &cfg.DriveFolderID, "PKARCHIVES_DESKTOP_PATH": &cfg.DesktopPath,
		"PKARCHIVES_DESKTOP_LINK_NAME": &cfg.LinkName, "PKARCHIVES_RCLONE_REMOTE": &cfg.RcloneRemote,
	} {
		if v := os.Getenv(k); v != "" {
			*dst = v
		}
	}
	for _, path := range []string{filepath.Join(home, ".pkarchives.conf"), filepath.Join(home, ".config", "pkarchives", "pkarchives.conf")} {
		data, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		for _, raw := range strings.Split(string(data), "\n") {
			p := strings.SplitN(strings.TrimSpace(raw), "=", 2)
			if len(p) != 2 {
				continue
			}
			key, val := p[0], strings.Trim(strings.TrimSpace(p[1]), `"'`)
			if val == "" {
				continue
			}
			switch key {
			case "PKARCHIVES_DRIVE_FOLDER_ID":
				if cfg.DriveFolderID == "" {
					cfg.DriveFolderID = val
				}
			case "PKARCHIVES_DESKTOP_PATH":
				cfg.DesktopPath = val
			case "PKARCHIVES_DESKTOP_LINK_NAME":
				cfg.LinkName = val
			case "PKARCHIVES_RCLONE_REMOTE":
				cfg.RcloneRemote = val
			}
		}
	}
	return cfg
}

func saveConfig(cfg Config) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	data := fmt.Sprintf("PKARCHIVES_DRIVE_FOLDER_ID=\"%s\"\nPKARCHIVES_DESKTOP_PATH=\"%s\"\nPKARCHIVES_DESKTOP_LINK_NAME=\"%s\"\nPKARCHIVES_RCLONE_REMOTE=\"%s\"\n", cfg.DriveFolderID, cfg.DesktopPath, cfg.LinkName, cfg.RcloneRemote)
	return os.WriteFile(filepath.Join(home, ".pkarchives.conf"), []byte(data), 0600)
}

func driveURL(cfg Config) string {
	if cfg.DriveFolderID == "" {
		return "https://drive.google.com"
	}
	return "https://drive.google.com/drive/folders/" + cfg.DriveFolderID
}
func archiveRemote(cfg Config) string { return cfg.RcloneRemote + ":" }

type fileItem struct {
	Path, Name string
	IsDir      bool
	Size       int64
}

func hasBureauTag(path string) bool {
	if runtime.GOOS != "darwin" {
		return false
	}
	out, err := exec.Command("mdls", "-name", "kMDItemUserTags", "-raw", path).Output()
	return err == nil && strings.Contains(string(out), "Bureau")
}
func scanDesktop(cfg Config, mode string) ([]fileItem, error) {
	entries, err := os.ReadDir(cfg.DesktopPath)
	if err != nil {
		return nil, err
	}
	var files, dirs []fileItem
	for _, e := range entries {
		name := e.Name()
		if strings.HasPrefix(name, ".") || name == cfg.LinkName {
			continue
		}
		path := filepath.Join(cfg.DesktopPath, name)
		if hasBureauTag(path) {
			continue
		}
		info, err := e.Info()
		if err != nil {
			continue
		}
		if e.IsDir() {
			if mode != "files" {
				dirs = append(dirs, fileItem{path, name, true, info.Size()})
			}
		} else {
			files = append(files, fileItem{path, name, false, info.Size()})
		}
	}
	sort.Slice(files, func(i, j int) bool { return files[i].Size < files[j].Size })
	return append(files, dirs...), nil
}

func rcloneUpload(ctx context.Context, cfg Config, path, destination string) error {
	return exec.CommandContext(ctx, "rclone", "copy", path, destination+"/", "--drive-root-folder-id", cfg.DriveFolderID, "--drive-chunk-size", "32M", "--buffer-size", "32M", "--drive-upload-cutoff", "32M", "--drive-pacer-min-sleep", "10ms", "--drive-pacer-burst", "200", "--quiet").Run()
}

type phase int

const (
	phaseMain phase = iota
	phaseSettings
	phaseHistory
	phaseScanning
	phaseUploading
	phaseDeleting
	phaseMounting
	phaseDone
	phaseFailed
	phaseEmpty
)

type scanDoneMsg struct {
	items []fileItem
	err   error
}
type dirScannedMsg struct {
	parentIdx    int
	paths, names []string
}
type subFileDoneMsg struct {
	parentIdx, subIdx, subTotal int
	name                        string
	err                         error
}
type itemDoneMsg struct {
	index int
	name  string
	isDir bool
	err   error
}
type deleteDoneMsg struct {
	index, total int
	err          error
}
type mountDoneMsg struct {
	mountPath string
	err       error
}

type model struct {
	width, height                               int
	phase                                       phase
	cfg                                         Config
	spinner                                     spinner.Model
	menu, inputFocus                            int
	inputs                                      []textinput.Model
	items                                       []fileItem
	current, success, deleted, subIdx, subTotal int
	subPaths, subNames                          []string
	status, output                              string
	running                                     bool
	started                                     time.Time
	sessionBytes                                int64
	lastMount                                   string
	histories                                   []historyEntry
}

func initialModel() model {
	cfg := loadConfig()
	fields := []struct{ placeholder, value string }{{"Drive Folder ID", cfg.DriveFolderID}, {"Desktop path", cfg.DesktopPath}, {"rclone remote", cfg.RcloneRemote}, {"Link name", cfg.LinkName}}
	inputs := make([]textinput.Model, len(fields))
	for i, f := range fields {
		inputs[i] = textinput.New()
		inputs[i].Placeholder = f.placeholder
		inputs[i].SetValue(f.value)
	}
	s := spinner.New()
	s.Spinner = spinner.Dot
	return model{cfg: cfg, phase: phaseMain, spinner: s, status: "Ready", inputs: inputs, histories: loadHistory()}
}
func (m model) Init() tea.Cmd { return nil }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		if m.running {
			return m, cmd
		}
	case tea.KeyMsg:
		key := msg.String()
		if key == "ctrl+c" || key == "q" {
			if m.running {
				return m, nil
			}
			return m, tea.Quit
		}
		if key == "esc" {
			if m.running {
				m.running = false
				m.phase = phaseMain
				m.status = "Cancelled"
				return m, nil
			}
			if m.phase != phaseMain {
				m.phase = phaseMain
				m.blurInput()
				return m, nil
			}
		}
		if m.phase == phaseSettings {
			if key == "tab" || key == "shift+tab" {
				m.moveInput(key == "shift+tab")
				return m, nil
			}
			if key == "enter" {
				return m.saveSettings()
			}
			var cmd tea.Cmd
			m.inputs[m.inputFocus], cmd = m.inputs[m.inputFocus].Update(msg)
			return m, cmd
		}
		if m.running {
			return m, nil
		}
		if m.phase == phaseMain {
			if key == "d" || key == "o" {
				openURL(driveURL(m.cfg))
				return m, nil
			}
			if key >= "1" && key <= "5" {
				m.menu = int(key[0] - '1')
				return m, nil
			}
			if key == "tab" || key == "down" {
				m.menu = (m.menu + 1) % 5
				return m, nil
			}
			if key == "shift+tab" || key == "up" {
				m.menu = (m.menu + 4) % 5
				return m, nil
			}
			if key == "enter" {
				return m.activateMenu()
			}
		}
		if (m.phase == phaseHistory) && (key == "up" || key == "down") {
			return m, nil
		}
	case scanDoneMsg:
		if msg.err != nil {
			return m.fail(msg.err)
		}
		m.items = msg.items
		if len(msg.items) == 0 {
			m.phase, m.status = phaseEmpty, "Nothing to archive"
			m.running = false
			return m, nil
		}
		m.phase, m.current, m.success = phaseUploading, 0, 0
		m.output = ""
		return m, tea.Batch(m.spinner.Tick, startUploadCmd(m.cfg, m.items, 0))
	case dirScannedMsg:
		m.subPaths, m.subNames, m.subIdx, m.subTotal = msg.paths, msg.names, 0, len(msg.paths)
		if m.subTotal == 0 {
			return m, itemDoneCmd(m.current, m.items[m.current].Name, true, nil)
		}
		return m, uploadSubFileCmd(m.cfg, msg.parentIdx, m.subPaths, m.subNames, 0)
	case subFileDoneMsg:
		if msg.err != nil {
			return m.fail(msg.err)
		}
		m.subIdx = msg.subIdx + 1
		if m.subIdx >= m.subTotal {
			return m, itemDoneCmd(m.current, m.items[m.current].Name, true, nil)
		}
		return m, uploadSubFileCmd(m.cfg, msg.parentIdx, m.subPaths, m.subNames, m.subIdx)
	case itemDoneMsg:
		if msg.err != nil {
			return m.fail(msg.err)
		}
		if msg.index < len(m.items) {
			m.sessionBytes += itemBytes(m.items[msg.index].Path)
		}
		m.success++
		m.current = msg.index + 1
		if m.current < len(m.items) {
			return m, startUploadCmd(m.cfg, m.items, m.current)
		}
		m.phase, m.deleted = phaseDeleting, 0
		return m, tea.Batch(m.spinner.Tick, deleteItemCmd(m.items, 0, m.success))
	case deleteDoneMsg:
		if msg.err != nil {
			return m.fail(msg.err)
		}
		m.deleted = msg.index + 1
		if m.deleted < msg.total {
			return m, deleteItemCmd(m.items, m.deleted, msg.total)
		}
		m.phase = phaseMounting
		return m, tea.Batch(m.spinner.Tick, mountDriveCmd(m.cfg))
	case mountDoneMsg:
		m.lastMount = msg.mountPath
		m.running = false
		if msg.err != nil {
			m.status = "Archived; mount unavailable"
		} else {
			m.status = "Archive complete"
		}
		m.phase = phaseDone
		record := historyEntry{Date: time.Now(), Mode: modeName(m.items), Items: len(m.items), Success: m.success, Bytes: m.sessionBytes, MountOK: msg.err == nil}
		m.histories = append([]historyEntry{record}, m.histories...)
		saveHistory(m.histories)
		return m, nil
	}
	return m, nil
}

func (m model) fail(err error) (tea.Model, tea.Cmd) {
	m.phase, m.running, m.status = phaseFailed, false, err.Error()
	return m, nil
}
func (m *model) blurInput() {
	for i := range m.inputs {
		m.inputs[i].Blur()
	}
}
func (m *model) moveInput(reverse bool) {
	m.inputs[m.inputFocus].Blur()
	if reverse {
		m.inputFocus = (m.inputFocus + len(m.inputs) - 1) % len(m.inputs)
	} else {
		m.inputFocus = (m.inputFocus + 1) % len(m.inputs)
	}
	m.inputs[m.inputFocus].Focus()
}
func (m model) activateMenu() (tea.Model, tea.Cmd) {
	switch m.menu {
	case 0, 1:
		return m.startArchive(m.menu == 1)
	case 2:
		m.phase = phaseHistory
		return m, nil
	case 3:
		m.phase = phaseSettings
		m.inputFocus = 0
		m.inputs[0].Focus()
		return m, textinput.Blink
	default:
		return m, tea.Quit
	}
}
func (m model) saveSettings() (tea.Model, tea.Cmd) {
	m.cfg.DriveFolderID, m.cfg.DesktopPath, m.cfg.RcloneRemote, m.cfg.LinkName = m.inputs[0].Value(), m.inputs[1].Value(), m.inputs[2].Value(), m.inputs[3].Value()
	if m.cfg.LinkName == "" {
		m.cfg.LinkName = "DesktopArchive"
	}
	if err := saveConfig(m.cfg); err != nil {
		m.status = err.Error()
	} else {
		m.status = "Settings saved"
	}
	m.blurInput()
	m.phase = phaseMain
	return m, nil
}
func (m model) startArchive(all bool) (tea.Model, tea.Cmd) {
	if m.cfg.DriveFolderID == "" {
		m.status = "Drive Folder ID required in Settings"
		return m, nil
	}
	m.phase, m.running, m.started, m.sessionBytes = phaseScanning, true, time.Now(), 0
	mode := "files"
	if all {
		mode = "all"
	}
	return m, tea.Batch(m.spinner.Tick, scanCmd(m.cfg, mode))
}

func scanCmd(cfg Config, mode string) tea.Cmd {
	return func() tea.Msg { items, err := scanDesktop(cfg, mode); return scanDoneMsg{items, err} }
}
func startUploadCmd(cfg Config, items []fileItem, idx int) tea.Cmd {
	return func() tea.Msg {
		item := items[idx]
		if item.IsDir {
			var paths, names []string
			filepath.Walk(item.Path, func(path string, info os.FileInfo, err error) error {
				if err != nil || info == nil || info.IsDir() || strings.HasPrefix(info.Name(), ".") || hasBureauTag(path) {
					return nil
				}
				paths = append(paths, path)
				names = append(names, strings.TrimPrefix(path, item.Path+string(os.PathSeparator)))
				return nil
			})
			return dirScannedMsg{idx, paths, names}
		}
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
		defer cancel()
		err := rcloneUpload(ctx, cfg, item.Path, archiveRemote(cfg))
		return itemDoneMsg{idx, item.Name, false, err}
	}
}
func uploadSubFileCmd(cfg Config, parent int, paths, names []string, idx int) tea.Cmd {
	return func() tea.Msg {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
		defer cancel()
		err := rcloneUpload(ctx, cfg, paths[idx], archiveRemote(cfg))
		return subFileDoneMsg{parent, idx, len(paths), names[idx], err}
	}
}
func itemDoneCmd(idx int, name string, dir bool, err error) tea.Cmd {
	return func() tea.Msg { return itemDoneMsg{idx, name, dir, err} }
}
func deleteItemCmd(items []fileItem, idx, total int) tea.Cmd {
	return func() tea.Msg {
		var err error
		if idx < len(items) {
			err = os.RemoveAll(items[idx].Path)
		}
		return deleteDoneMsg{idx, total, err}
	}
}
func mountDriveCmd(cfg Config) tea.Cmd {
	return func() tea.Msg {
		home, _ := os.UserHomeDir()
		mount := filepath.Join(home, ".local", "share", "pkarchives", "mount")
		os.MkdirAll(mount, 0755)
		var err error
		if !isMountActive(mount) {
			err = exec.Command("rclone", "mount", archiveRemote(cfg), mount, "--drive-root-folder-id", cfg.DriveFolderID, "--daemon", "--vfs-cache-mode", "minimal", "--volname", "PKarchives").Run()
			if err == nil {
				for i := 0; i < 10 && !isMountActive(mount); i++ {
					time.Sleep(500 * time.Millisecond)
				}
			}
		}
		link := filepath.Join(cfg.DesktopPath, cfg.LinkName)
		os.Remove(link)
		if linkErr := os.Symlink(mount, link); linkErr != nil && err == nil {
			err = linkErr
		}
		return mountDoneMsg{mount, err}
	}
}
func isMountActive(path string) bool {
	entries, err := os.ReadDir(path)
	return err == nil && len(entries) > 0
}
func modeName(items []fileItem) string {
	for _, item := range items {
		if item.IsDir {
			return "files + folders"
		}
	}
	return "files"
}

func itemBytes(path string) int64 {
	var total int64
	_ = filepath.Walk(path, func(_ string, info os.FileInfo, err error) error {
		if err == nil && info != nil && !info.IsDir() {
			total += info.Size()
		}
		return nil
	})
	return total
}

func (m model) View() string {
	if m.width > 0 && m.width < 58 {
		return m.compactView()
	}
	switch m.phase {
	case phaseSettings:
		return m.settingsView()
	case phaseHistory:
		return m.historyView()
	default:
		return m.dashboardView()
	}
}
func (m model) header() string {
	return titleStyle.Render("PKarchives") + "  " + mutedStyle.Render("RIPTIDE / archive console") + "\n" + mutedStyle.Render(strings.Repeat("-", clamp(m.width, 44, 96)))
}
func (m model) dashboardView() string {
	var b strings.Builder
	b.WriteString(m.header() + "\n\n")
	b.WriteString(titleStyle.Render("Archive dashboard") + "\n\n")
	b.WriteString(m.cards() + "\n\n")
	b.WriteString(m.stats() + "\n\n")
	if m.phase != phaseMain || m.output != "" {
		b.WriteString(m.progressView() + "\n\n")
	} else {
		b.WriteString(mutedStyle.Render("Select a mode, then press Enter. Hidden files and Bureau-tagged items are excluded.") + "\n\n")
	}
	b.WriteString(mutedStyle.Render("1/2 mode  3 history  4 settings  5 quit  Tab move  Enter select  Esc back  q quit"))
	return b.String()
}
func (m model) cards() string {
	labels := []string{"ARCHIVE FILES", "FILES + FOLDERS", "HISTORY", "SETTINGS", "QUIT"}
	var out []string
	for i, label := range labels {
		text := fmt.Sprintf("%d  %s", i+1, label)
		if i == m.menu {
			out = append(out, selectedCard.Width(16).Render(lipgloss.NewStyle().Bold(true).Foreground(teal).Render(text)))
		} else {
			out = append(out, card.Width(16).Render(text))
		}
	}
	if m.width < 90 {
		return lipgloss.JoinVertical(lipgloss.Left, out...)
	}
	return lipgloss.JoinHorizontal(lipgloss.Top, out...)
}
func (m model) stats() string {
	last := "No runs yet"
	if len(m.histories) > 0 {
		h := m.histories[0]
		last = fmt.Sprintf("%s / %d items", h.Date.Local().Format("02 Jan 15:04"), h.Items)
	}
	mount := "offline"
	if m.lastMount != "" && isMountActive(m.lastMount) {
		mount = "mounted"
	}
	parts := []string{fmt.Sprintf("LAST SESSION\n%s", last), fmt.Sprintf("SUCCESS\n%d", m.lastSuccess()), fmt.Sprintf("SPACE EST. FREED\n%s", formatBytes(m.lastBytes())), fmt.Sprintf("MOUNT\n%s", short(mount, 24))}
	var cards []string
	for _, p := range parts {
		cards = append(cards, card.Width(20).Render(p))
	}
	return lipgloss.JoinHorizontal(lipgloss.Top, cards...)
}
func (m model) lastSuccess() int {
	if len(m.histories) > 0 {
		return m.histories[0].Success
	}
	return 0
}
func (m model) lastBytes() int64 {
	if len(m.histories) > 0 {
		return m.histories[0].Bytes
	}
	return 0
}
func (m model) progressView() string {
	status := m.status
	if m.phase == phaseScanning {
		status = m.spinner.View() + " scanning Desktop"
	}
	if m.phase == phaseUploading && m.current < len(m.items) {
		status = fmt.Sprintf("%s uploading %d/%d: %s", m.spinner.View(), m.current+1, len(m.items), m.items[m.current].Name)
		if m.subTotal > 0 {
			status += fmt.Sprintf("  sub-file %d/%d", m.subIdx+1, m.subTotal)
		}
	}
	if m.phase == phaseDeleting {
		status = fmt.Sprintf("%s deleting %d/%d", m.spinner.View(), m.deleted+1, m.success)
	}
	if m.phase == phaseMounting {
		status = m.spinner.View() + " mounting Drive and linking DesktopArchive"
	}
	if m.phase == phaseDone {
		status = fmt.Sprintf("%s %d/%d archived and deleted", ok("OK"), m.success, len(m.items))
	}
	if m.phase == phaseFailed {
		status = dangerStyle(m.status)
	}
	if m.phase == phaseEmpty {
		status = mutedStyle.Render("Nothing to archive")
	}
	progress := 0
	total := len(m.items)
	if total > 0 {
		progress = m.current
		if m.phase == phaseDone {
			progress = total
		}
	}
	return card.Width(clamp(m.width-4, 40, 96)).Render(status + "\n\n" + sparkline(progress, total, 34) + "\n" + mutedStyle.Render(strings.TrimSpace(m.output)))
}
func (m model) settingsView() string {
	var b strings.Builder
	b.WriteString(m.header() + "\n\n" + titleStyle.Render("Settings") + "\n\n")
	labels := []string{"Drive Folder ID", "Desktop path", "rclone remote", "Desktop link name"}
	for i, input := range m.inputs {
		mark := "  "
		if i == m.inputFocus {
			mark = "> "
		}
		b.WriteString(mark + labels[i] + "\n" + card.Width(clamp(m.width-8, 32, 82)).Render(input.View()) + "\n")
	}
	b.WriteString("\n" + mutedStyle.Render("Enter save  Tab next field  Esc cancel") + "\n" + mutedStyle.Render("Config: ~/.pkarchives.conf"))
	return b.String()
}
func (m model) historyView() string {
	var b strings.Builder
	b.WriteString(m.header() + "\n\n" + titleStyle.Render("Archive history") + "\n\n")
	if len(m.histories) == 0 {
		b.WriteString(card.Render("No archive runs recorded yet.\nHistory is stored in ~/.config/pkarchives/history.json"))
	} else {
		for _, h := range m.histories {
			state := "OK"
			if !h.MountOK {
				state = "MOUNT WARN"
			}
			b.WriteString(card.Width(clamp(m.width-4, 42, 96)).Render(fmt.Sprintf("%s  %-11s  %d/%d items  %8s freed  %s", h.Date.Local().Format("2006-01-02 15:04"), state, h.Success, h.Items, formatBytes(h.Bytes), h.Mode)) + "\n")
		}
	}
	b.WriteString("\n" + mutedStyle.Render("Esc back  q quit"))
	return b.String()
}
func (m model) compactView() string {
	return titleStyle.Render("PKarchives") + "\n\n" + fmt.Sprintf("[%d/5] %s\n\n", m.menu+1, []string{"Archive files", "Files + folders", "History", "Settings", "Quit"}[m.menu]) + mutedStyle.Render("1-5 select  Tab move  Enter  Esc  q") + "\n" + m.status
}

func sparkline(value, total, width int) string {
	if total <= 0 {
		return mutedStyle.Render(strings.Repeat(".", width))
	}
	n := value * width / total
	return lipgloss.NewStyle().Foreground(teal).Render(strings.Repeat("#", n)) + mutedStyle.Render(strings.Repeat(".", width-n))
}
func formatBytes(n int64) string {
	if n < 1024 {
		return fmt.Sprintf("%d B", n)
	}
	units := []string{"KB", "MB", "GB", "TB"}
	v := float64(n)
	i := 0
	for v >= 1024 && i < len(units)-1 {
		v /= 1024
		i++
	}
	return fmt.Sprintf("%.1f %s", v, units[i])
}
func short(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n-3] + "..."
}
func clamp(v, min, max int) int {
	if v < min {
		return min
	}
	if v > max {
		return max
	}
	return v
}
func ok(s string) string          { return lipgloss.NewStyle().Foreground(teal).Bold(true).Render(s) }
func dangerStyle(s string) string { return lipgloss.NewStyle().Foreground(danger).Render(s) }
func openURL(url string) {
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "darwin":
		cmd = exec.Command("open", url)
	case "linux":
		cmd = exec.Command("xdg-open", url)
	case "windows":
		cmd = exec.Command("rundll32", "url.dll,FileProtocolHandler", url)
	}
	if cmd != nil {
		_ = cmd.Start()
	}
}

func main() {
	p := tea.NewProgram(initialModel(), tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Fprintln(os.Stderr, "Error:", err)
		os.Exit(1)
	}
}
