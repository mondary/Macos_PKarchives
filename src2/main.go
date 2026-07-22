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

// ═══════════════════════════════════════════════════════════════
//  Styles
// ═══════════════════════════════════════════════════════════════

var (
	accent    = lipgloss.AdaptiveColor{Dark: "#39d0d8"}
	green     = lipgloss.AdaptiveColor{Dark: "#7ee787"}
	red       = lipgloss.AdaptiveColor{Dark: "#ff7b72"}
	yellow    = lipgloss.AdaptiveColor{Dark: "#f0c674"}
	orange    = lipgloss.AdaptiveColor{Dark: "#f0883e"}
	gray      = lipgloss.AdaptiveColor{Dark: "#7d8590"}
	white     = lipgloss.AdaptiveColor{Dark: "#e6edf3"}
	borderCol = lipgloss.AdaptiveColor{Dark: "#30363d"}
	darkBg    = lipgloss.AdaptiveColor{Dark: "#121214"}

	appTitle   = lipgloss.NewStyle().Bold(true).Foreground(accent)
	labelStyle = lipgloss.NewStyle().Foreground(gray)
	valueStyle = lipgloss.NewStyle().Foreground(white).Bold(true)
	okStyle    = lipgloss.NewStyle().Foreground(green).Bold(true)
	errStyle   = lipgloss.NewStyle().Foreground(red).Bold(true)
	warnStyle  = lipgloss.NewStyle().Foreground(yellow).Bold(true)
	hintStyle  = lipgloss.NewStyle().Foreground(gray)

	outputStyle = lipgloss.NewStyle().
			Background(darkBg).
			Foreground(white).
			Padding(1, 2)

	cardStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(borderCol).
			Padding(1, 3)

	dimLabel = lipgloss.NewStyle().Foreground(gray)
)

// ═══════════════════════════════════════════════════════════════
//  Config
// ═══════════════════════════════════════════════════════════════

type Config struct {
	DriveFolderID string
	DesktopPath   string
	LinkName      string
	RcloneRemote  string
}

func loadConfig() Config {
	home, _ := os.UserHomeDir()
	cfg := Config{
		DesktopPath:  filepath.Join(home, "Desktop"),
		LinkName:     "DesktopArchive",
		RcloneRemote: "gdrive",
	}

	if v := os.Getenv("PKARCHIVES_DRIVE_FOLDER_ID"); v != "" {
		cfg.DriveFolderID = v
	}
	if v := os.Getenv("PKARCHIVES_DESKTOP_PATH"); v != "" {
		cfg.DesktopPath = v
	}
	if v := os.Getenv("PKARCHIVES_DESKTOP_LINK_NAME"); v != "" {
		cfg.LinkName = v
	}
	if v := os.Getenv("PKARCHIVES_RCLONE_REMOTE"); v != "" {
		cfg.RcloneRemote = v
	}

	for _, p := range []string{
		filepath.Join(home, ".pkarchives.conf"),
		filepath.Join(home, ".config", "pkarchives", "pkarchives.conf"),
	} {
		data, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		for _, line := range strings.Split(string(data), "\n") {
			line = strings.TrimSpace(line)
			if strings.HasPrefix(line, "#") || line == "" {
				continue
			}
			parts := strings.SplitN(line, "=", 2)
			if len(parts) != 2 {
				continue
			}
			key := strings.TrimSpace(parts[0])
			val := strings.Trim(strings.TrimSpace(parts[1]), `"'`)
			switch key {
			case "PKARCHIVES_DRIVE_FOLDER_ID":
				if cfg.DriveFolderID == "" {
					cfg.DriveFolderID = val
				}
			case "PKARCHIVES_DESKTOP_PATH":
				if val != "" {
					cfg.DesktopPath = val
				}
			case "PKARCHIVES_DESKTOP_LINK_NAME":
				if val != "" {
					cfg.LinkName = val
				}
			case "PKARCHIVES_RCLONE_REMOTE":
				if val != "" {
					cfg.RcloneRemote = val
				}
			}
		}
	}
	return cfg
}

func monthYear() string {
	now := time.Now()
	return fmt.Sprintf("%d_%02d_%s", now.Year(), int(now.Month()), strings.ToLower(now.Month().String()))
}

func driveURL(cfg Config) string {
	if cfg.DriveFolderID == "" {
		return "https://drive.google.com"
	}
	return fmt.Sprintf("https://drive.google.com/drive/folders/%s", cfg.DriveFolderID)
}

// ═══════════════════════════════════════════════════════════════
//  Archive logic
// ═══════════════════════════════════════════════════════════════

type fileItem struct {
	Path  string
	Name  string
	IsDir bool
	Size  int64
}

func hasBureauTag(path string) bool {
	if runtime.GOOS != "darwin" {
		return false
	}
	out, err := exec.Command("mdls", "-name", "kMDItemUserTags", "-raw", path).Output()
	if err != nil {
		return false
	}
	return strings.Contains(string(out), "Bureau")
}

func scanDesktop(cfg Config, mode string) ([]fileItem, error) {
	entries, err := os.ReadDir(cfg.DesktopPath)
	if err != nil {
		return nil, err
	}

	var files, dirs []fileItem
	for _, e := range entries {
		name := e.Name()
		// Skip hidden, link, DS_Store
		if strings.HasPrefix(name, ".") || name == cfg.LinkName {
			continue
		}

		fullPath := filepath.Join(cfg.DesktopPath, name)

		// Skip files tagged "Bureau" (macOS tag)
		if hasBureauTag(fullPath) {
			continue
		}

		info, err := e.Info()
		if err != nil {
			continue
		}

		if e.IsDir() {
			if mode == "files" {
				continue
			}
			dirs = append(dirs, fileItem{Path: fullPath, Name: name, IsDir: true, Size: info.Size()})
		} else {
			files = append(files, fileItem{Path: fullPath, Name: name, IsDir: false, Size: info.Size()})
		}
	}

	sort.Slice(files, func(i, j int) bool { return files[i].Size < files[j].Size })
	return append(files, dirs...), nil
}

func rcloneUpload(ctx context.Context, cfg Config, filePath, rcloneDir string) error {
	cmd := exec.CommandContext(ctx, "rclone", "copy", filePath, rcloneDir+"/",
		"--drive-root-folder-id", cfg.DriveFolderID,
		"--drive-chunk-size", "32M",
		"--buffer-size", "32M",
		"--drive-upload-cutoff", "32M",
		"--drive-pacer-min-sleep", "10ms",
		"--drive-pacer-burst", "200",
		"--quiet",
	)
	return cmd.Run()
}

// ═══════════════════════════════════════════════════════════════
//  Messages
// ═══════════════════════════════════════════════════════════════

type logMsg struct{ text string }

type scanDoneMsg struct {
	items []fileItem
	err   error
}

type dirScannedMsg struct {
	parentIdx int
	subFiles  []string
	subNames  []string
}

type subFileDoneMsg struct {
	parentIdx int
	subIdx    int
	subTotal  int
	subName   string
}

type itemDoneMsg struct {
	index int
	name  string
	isDir bool
}

type allDoneMsg struct {
	success int
	total   int
}

type deleteDoneMsg struct {
	index int
	total int
	name  string
}

type mountDoneMsg struct {
	mountPath string
	err       error
}

type errMsg struct{ err error }

// ═══════════════════════════════════════════════════════════════
//  Phases
// ═══════════════════════════════════════════════════════════════

type phase int

const (
	phaseMain phase = iota
	phaseSettings
	phaseScanning
	phaseUploading
	phaseDeleting
	phaseMounting
	phaseDone
	phaseFailed
	phaseEmpty
)

type modeChoice int

const (
	modeFiles modeChoice = iota
	modeAll
)

type focusArea int

const (
	focusNone focusArea = iota
	focusModePicker
	focusArchiveBtn
	focusDriveBtn
	focusSettingsBtn
	focusCancelBtn
	focusInput
)

// ═══════════════════════════════════════════════════════════════
//  Model
// ═══════════════════════════════════════════════════════════════

type model struct {
	width   int
	height  int
	phase   phase
	spinner spinner.Model
	cfg     Config

	// Main screen
	mode       modeChoice
	focus      focusArea
	output     string
	status     string
	isRunning  bool
	items      []fileItem
	currentIdx int
	success    int

	// Directory upload tracking
	subFiles   []string
	subNames   []string
	subIdx     int
	subTotal   int

	// Delete phase
	deletedIdx  int
	deletedTotal int

	// Settings
	settingsFocus focusArea
	inputs        []textinput.Model
	inputFocus    int

	// System info
	osName     string
	arch       string
	macOS      string
	shellName  string
	rcloneVer  string
}

func initialModel() model {
	cfg := loadConfig()
	s := spinner.New()
	s.Spinner = spinner.Dot

	shell := filepath.Base(os.Getenv("SHELL"))
	if shell == "" {
		shell = "bash"
	}

	macOS := "N/A"
	if runtime.GOOS == "darwin" {
		if out, err := exec.Command("sw_vers", "-productVersion").Output(); err == nil {
			macOS = strings.TrimSpace(string(out))
		}
	} else {
		macOS = runtime.GOOS
	}

	rcloneVer := "not found"
	if out, err := exec.Command("rclone", "version").Output(); err == nil {
		lines := strings.Split(string(out), "\n")
		if len(lines) > 0 {
			parts := strings.Fields(lines[0])
			if len(parts) >= 2 {
				rcloneVer = parts[1]
			}
		}
	}

	// Settings inputs
	driveInput := textinput.New()
	driveInput.Placeholder = "Drive Folder ID"
	driveInput.SetValue(cfg.DriveFolderID)

	desktopInput := textinput.New()
	desktopInput.Placeholder = "Desktop path"
	desktopInput.SetValue(cfg.DesktopPath)

	remoteInput := textinput.New()
	remoteInput.Placeholder = "rclone remote"
	remoteInput.SetValue(cfg.RcloneRemote)

	return model{
		phase:       phaseMain,
		spinner:     s,
		cfg:         cfg,
		mode:        modeFiles,
		focus:       focusArchiveBtn,
		status:      "Ready",
		settingsFocus: focusInput,
		inputs:      []textinput.Model{driveInput, desktopInput, remoteInput},
		osName:      runtime.GOOS,
		arch:        runtime.GOARCH,
		macOS:       macOS,
		shellName:   shell,
		rcloneVer:   rcloneVer,
	}
}

func (m model) Init() tea.Cmd { return nil }

// ═══════════════════════════════════════════════════════════════
//  Update
// ═══════════════════════════════════════════════════════════════

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		return m, nil

	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q":
			if m.phase == phaseSettings {
				m.phase = phaseMain
				return m, nil
			}
			if m.isRunning {
				return m, nil // Don't quit during upload
			}
			return m, tea.Quit

		case "esc":
			if m.phase == phaseSettings {
				m.phase = phaseMain
				m.inputs[m.inputFocus].Blur()
				return m, nil
			}
			if m.isRunning {
				m.isRunning = false
				m.phase = phaseMain
				m.status = "Cancelled"
				m.output += "\n🛑 Cancelled.\n"
				return m, nil
			}

		case "tab", "shift+tab":
			return m.handleTab()

		case "enter":
			return m.handleEnter()

		case "left", "right", "h", "l":
			if m.phase == phaseMain && m.focus == focusModePicker {
				if msg.String() == "left" || msg.String() == "h" {
					m.mode = modeFiles
				} else {
					m.mode = modeAll
				}
				return m, nil
			}
		}

	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		if m.isRunning || m.phase == phaseScanning || m.phase == phaseUploading || m.phase == phaseDeleting {
			return m, cmd
		}
		return m, nil

	case logMsg:
		m.output += msg.text
		return m, nil

	case scanDoneMsg:
		if msg.err != nil {
			m.phase = phaseFailed
			m.status = fmt.Sprintf("Error: %v", msg.err)
			return m, nil
		}
		m.items = msg.items
		if len(msg.items) == 0 {
			m.phase = phaseEmpty
			m.status = "Nothing to archive"
			return m, nil
		}
		m.phase = phaseUploading
		m.isRunning = true
		m.currentIdx = 0
		m.success = 0
		m.output += fmt.Sprintf("\n📦 %d item(s) to archive\n", len(m.items))
		m.output += "🚀 Upload first, delete after\n\n"
		return m, tea.Batch(m.spinner.Tick, startUploadCmd(m.cfg, m.items, 0))

	case dirScannedMsg:
		m.subFiles = msg.subFiles
		m.subNames = msg.subNames
		m.subIdx = 0
		m.subTotal = len(msg.subFiles)
		if m.subTotal == 0 {
			return m, tea.Cmd(itemDoneCmd(m.currentIdx, m.items[m.currentIdx].Name, true))
		}
		return m, uploadSubFileCmd(m.cfg, msg.parentIdx, msg.subFiles, msg.subNames, 0)

	case subFileDoneMsg:
		m.subIdx = msg.subIdx + 1
		if m.subIdx >= m.subTotal {
			m.output += fmt.Sprintf("  ✓ %s/ (%d files)\n\n", m.items[m.currentIdx].Name, m.subTotal)
			return m, itemDoneCmd(m.currentIdx, m.items[m.currentIdx].Name, true)
		}
		m.output += fmt.Sprintf("  📄 %s\n", m.subNames[msg.subIdx])
		return m, uploadSubFileCmd(m.cfg, msg.parentIdx, m.subFiles, m.subNames, m.subIdx)

	case itemDoneMsg:
		if !msg.isDir {
			m.output += fmt.Sprintf("📄 [%d/%d] %s\n  ✓ uploaded\n\n", msg.index+1, len(m.items), msg.name)
		}
		m.success++
		next := msg.index + 1
		if next >= len(m.items) {
			// Phase delete
			m.phase = phaseDeleting
			m.deletedIdx = 0
			m.deletedTotal = m.success
			m.output += "\n🧹 Cleaning up Desktop...\n"
			return m, tea.Batch(m.spinner.Tick, deleteItemCmd(m.items, 0, m.success))
		}
		m.currentIdx = next
		return m, startUploadCmd(m.cfg, m.items, next)

	case deleteDoneMsg:
		m.deletedIdx = msg.index + 1
		if msg.index+1 >= msg.total {
			// Phase mount — monter le Drive et créer le symlink
			m.phase = phaseMounting
			m.output += "\n📁 Mounting Google Drive...\n"
			m.status = "Mounting..."
			return m, tea.Batch(m.spinner.Tick, mountDriveCmd(m.cfg))
		}
		return m, deleteItemCmd(m.items, msg.index+1, msg.total)

	case mountDoneMsg:
		if msg.err != nil {
			m.output += fmt.Sprintf("  ⚠ mount failed: %v\n", msg.err)
		} else {
			m.output += fmt.Sprintf("  ✓ Mounted → %s\n", msg.mountPath)
			m.output += fmt.Sprintf("  ✓ Symlink → ~/Desktop/%s\n", m.cfg.LinkName)
		}
		m.phase = phaseDone
		m.isRunning = false
		m.status = "Done"
		m.output += fmt.Sprintf("\n✅ %d/%d archived + deleted\n", m.success, len(m.items))
		m.output += fmt.Sprintf("📁 %s\n", monthYear())
		return m, nil

	case errMsg:
		m.phase = phaseFailed
		m.status = fmt.Sprintf("Error: %v", msg.err)
		m.isRunning = false
		return m, nil
	}

	// Handle text input updates in settings
	if m.phase == phaseSettings {
		var cmd tea.Cmd
		m.inputs[m.inputFocus], cmd = m.inputs[m.inputFocus].Update(msg)
		return m, cmd
	}

	return m, nil
}

func (m model) handleTab() (tea.Model, tea.Cmd) {
	if m.phase == phaseMain {
		focusOrder := []focusArea{focusModePicker, focusArchiveBtn, focusDriveBtn, focusSettingsBtn}
		for i, f := range focusOrder {
			if m.focus == f {
				m.focus = focusOrder[(i+1)%len(focusOrder)]
				break
			}
		}
	}
	if m.phase == phaseSettings {
		m.inputs[m.inputFocus].Blur()
		m.inputFocus = (m.inputFocus + 1) % len(m.inputs)
		m.inputs[m.inputFocus].Focus()
	}
	return m, nil
}

func (m model) handleEnter() (tea.Model, tea.Cmd) {
	switch m.phase {
	case phaseMain:
		switch m.focus {
		case focusArchiveBtn:
			return m.startArchive()
		case focusDriveBtn:
			openURL(driveURL(m.cfg))
			return m, nil
		case focusSettingsBtn:
			m.phase = phaseSettings
			m.inputFocus = 0
			m.inputs[0].Focus()
			return m, textinput.Blink
		}
	case phaseSettings:
		// Save config
		m.cfg.DriveFolderID = m.inputs[0].Value()
		if m.inputs[1].Value() != "" {
			m.cfg.DesktopPath = m.inputs[1].Value()
		}
		if m.inputs[2].Value() != "" {
			m.cfg.RcloneRemote = m.inputs[2].Value()
		}
		saveConfig(m.cfg)
		m.inputs[m.inputFocus].Blur()
		m.phase = phaseMain
		m.status = "Settings saved"
		return m, nil
	case phaseDone, phaseFailed, phaseEmpty:
		return m, tea.Quit
	}
	return m, nil
}

func (m model) startArchive() (tea.Model, tea.Cmd) {
	if m.cfg.DriveFolderID == "" {
		m.status = "❌ Drive Folder ID not set — open Settings"
		return m, nil
	}
	modeStr := "files"
	if m.mode == modeAll {
		modeStr = "all"
	}
	m.phase = phaseScanning
	m.isRunning = true
	m.output = ""
	m.status = "Scanning..."
	return m, tea.Batch(m.spinner.Tick, scanCmd(m.cfg, modeStr))
}

func saveConfig(cfg Config) {
	home, _ := os.UserHomeDir()
	confPath := filepath.Join(home, ".pkarchives.conf")
	content := fmt.Sprintf(`PKARCHIVES_DRIVE_FOLDER_ID="%s"
PKARCHIVES_DESKTOP_PATH="%s"
PKARCHIVES_RCLONE_REMOTE="%s"
`, cfg.DriveFolderID, cfg.DesktopPath, cfg.RcloneRemote)
	os.WriteFile(confPath, []byte(content), 0600)
}

// ═══════════════════════════════════════════════════════════════
//  Commands
// ═══════════════════════════════════════════════════════════════

func scanCmd(cfg Config, mode string) tea.Cmd {
	return func() tea.Msg {
		items, err := scanDesktop(cfg, mode)
		return scanDoneMsg{items: items, err: err}
	}
}

func startUploadCmd(cfg Config, items []fileItem, idx int) tea.Cmd {
	return func() tea.Msg {
		item := items[idx]
		rcloneDir := fmt.Sprintf("%s:%s", cfg.RcloneRemote, monthYear())

		if item.IsDir {
			// Scan directory for sub-files
			var subFiles []string
			var subNames []string
			filepath.Walk(item.Path, func(path string, info os.FileInfo, err error) error {
				if err != nil || info.IsDir() || strings.HasPrefix(info.Name(), ".") {
					return nil
				}
				subFiles = append(subFiles, path)
				subNames = append(subNames, strings.TrimPrefix(path, item.Path+"/"))
				return nil
			})
			return dirScannedMsg{parentIdx: idx, subFiles: subFiles, subNames: subNames}
		}

		// Single file
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
		defer cancel()
		rcloneUpload(ctx, cfg, item.Path, rcloneDir)
		return itemDoneMsg{index: idx, name: item.Name, isDir: false}
	}
}

func uploadSubFileCmd(cfg Config, parentIdx int, subFiles, subNames []string, subIdx int) tea.Cmd {
	return func() tea.Msg {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
		defer cancel()

		rcloneDir := fmt.Sprintf("%s:%s", cfg.RcloneRemote, monthYear())
		rcloneUpload(ctx, cfg, subFiles[subIdx], rcloneDir)

		return subFileDoneMsg{
			parentIdx: parentIdx,
			subIdx:    subIdx,
			subTotal:  len(subFiles),
			subName:   subNames[subIdx],
		}
	}
}

func itemDoneCmd(idx int, name string, isDir bool) tea.Cmd {
	return func() tea.Msg {
		return itemDoneMsg{index: idx, name: name, isDir: isDir}
	}
}

func deleteItemCmd(items []fileItem, idx, total int) tea.Cmd {
	return func() tea.Msg {
		if idx < total && idx < len(items) {
			os.RemoveAll(items[idx].Path)
		}
		name := ""
		if idx < len(items) {
			name = items[idx].Name
		}
		return deleteDoneMsg{index: idx, total: total, name: name}
	}
}

func mountDriveCmd(cfg Config) tea.Cmd {
	return func() tea.Msg {
		home, _ := os.UserHomeDir()

		// Point de montage stable
		mountPath := filepath.Join(home, ".local", "share", "pkarchives", "mount")
		os.MkdirAll(mountPath, 0755)

		// Vérifier si déjà monté
		if isMountActive(mountPath) {
			// Créer le symlink quand même
			symlinkPath := filepath.Join(cfg.DesktopPath, cfg.LinkName)
			os.Remove(symlinkPath)
			os.Symlink(mountPath, symlinkPath)
			return mountDoneMsg{mountPath: mountPath, err: nil}
		}

		// Monter avec rclone mount --daemon
		cmd := exec.Command("rclone", "mount",
			fmt.Sprintf("%s:", cfg.RcloneRemote),
			mountPath,
			"--drive-root-folder-id", cfg.DriveFolderID,
			"--daemon",
			"--vfs-cache-mode", "minimal",
			"--volname", "PKarchives",
		)
		err := cmd.Run()

		// Attendre que le mount soit actif (max 5s)
		if err == nil {
			for i := 0; i < 10; i++ {
				time.Sleep(500 * time.Millisecond)
				if isMountActive(mountPath) {
					break
				}
			}
		}

		// Créer le symlink sur le Bureau
		symlinkPath := filepath.Join(cfg.DesktopPath, cfg.LinkName)
		os.Remove(symlinkPath)
		symlinkErr := os.Symlink(mountPath, symlinkPath)
		if symlinkErr != nil {
			return mountDoneMsg{mountPath: mountPath, err: fmt.Errorf("symlink: %w", symlinkErr)}
		}

		return mountDoneMsg{mountPath: mountPath, err: err}
	}
}

func isMountActive(path string) bool {
	// Sur macOS/Linux: vérifier si le path est un mount point
	entries, err := os.ReadDir(path)
	if err != nil || len(entries) == 0 {
		return false
	}
	return true
}

// ═══════════════════════════════════════════════════════════════
//  Views
// ═══════════════════════════════════════════════════════════════

func (m model) View() string {
	var body string
	switch m.phase {
	case phaseMain:
		body = m.mainView()
	case phaseSettings:
		body = m.settingsView()
	case phaseScanning:
		body = m.mainView()
	case phaseUploading:
		body = m.mainView()
	case phaseDeleting:
		body = m.mainView()
	case phaseMounting:
		m.status = "📁 Mounting Google Drive..."
		body = m.mainView()
	case phaseDone:
		body = m.mainView()
	case phaseFailed:
		body = m.mainView()
	case phaseEmpty:
		body = m.mainView()
	default:
		body = m.mainView()
	}

	return body
}

// ── Main view (reproduit l'app Swift) ─────────────────────────

func (m model) mainView() string {
	var b strings.Builder

	// Header
	b.WriteString(m.headerView())
	b.WriteString("\n")

	// Output area
	b.WriteString(m.outputAreaView())
	b.WriteString("\n")

	// Status bar
	b.WriteString(m.statusBarView())
	b.WriteString("\n")

	// Controls
	b.WriteString(m.controlsView())

	return b.String()
}

func (m model) headerView() string {
	var b strings.Builder
	b.WriteString(appTitle.Render("📦 PKarchives"))

	if m.isRunning {
		b.WriteString("  " + m.spinner.View())
	}

	b.WriteString(strings.Repeat(" ", max(1, m.width-30)))
	b.WriteString(dimLabel.Render(fmt.Sprintf("macOS %s · rclone %s", m.macOS, m.rcloneVer)))

	return b.String()
}

func (m model) outputAreaView() string {
	width := m.width - 4
	if width < 40 {
		width = 40
	}
	height := m.height - 12
	if height < 8 {
		height = 8
	}

	output := m.output
	if output == "" {
		output = faint("Ready. Press Tab to navigate, Enter to archive.")
	}

	// Truncate to visible lines
	lines := strings.Split(output, "\n")
	if len(lines) > height {
		lines = lines[len(lines)-height:]
	}

	// Truncate wide lines
	for i, line := range lines {
		if len(line) > width {
			lines[i] = line[:width-3] + "..."
		}
	}

	truncated := strings.Join(lines, "\n")

	styled := outputStyle.Width(width).Height(height)
	return styled.Render(truncated)
}

func (m model) statusBarView() string {
	icon := "✓"
	iconColor := green
	if m.isRunning {
		icon = "↑"
		iconColor = orange
	}
	if strings.Contains(m.status, "Error") || strings.Contains(m.status, "❌") {
		icon = "✗"
		iconColor = red
	}

	statusText := m.status
	if m.isRunning && m.phase == phaseUploading && m.currentIdx < len(m.items) {
		item := m.items[m.currentIdx]
		if m.subTotal > 0 {
			statusText = fmt.Sprintf("📁 [%d/%d] %s/ — %d/%d — %s",
				m.currentIdx+1, len(m.items), item.Name, m.subIdx+1, m.subTotal, m.subNames[m.subIdx])
		} else {
			statusText = fmt.Sprintf("📄 [%d/%d] %s", m.currentIdx+1, len(m.items), item.Name)
		}
	}
	if m.phase == phaseDeleting {
		statusText = fmt.Sprintf("🧹 Deleting %d/%d", m.deletedIdx+1, m.deletedTotal)
	}

	statusStyle := lipgloss.NewStyle().Foreground(iconColor)
	return fmt.Sprintf("%s %s",
		statusStyle.Render(icon),
		dimLabel.Render(statusText))
}

func (m model) controlsView() string {
	var b strings.Builder

	// Mode picker
	filesLabel := "Files"
	allLabel := "Files + Dirs"
	if m.mode == modeFiles {
		filesLabel = "[" + filesLabel + "]"
	} else {
		allLabel = "[" + allLabel + "]"
	}

	modeFocus := ""
	if m.focus == focusModePicker {
		modeFocus = "▶ "
	}

	modeStyle := lipgloss.NewStyle().Foreground(gray)
	if m.focus == focusModePicker {
		modeStyle = lipgloss.NewStyle().Foreground(accent).Bold(true)
	}
	b.WriteString(modeStyle.Render(fmt.Sprintf("%s← %s | %s →", modeFocus, filesLabel, allLabel)))

	b.WriteString(strings.Repeat(" ", max(1, m.width-70)))

	// Buttons
	buttons := []struct {
		label  string
		focus  bool
		color  lipgloss.AdaptiveColor
	}{
		{"⚙ Settings", m.focus == focusSettingsBtn, gray},
		{"📁 Drive", m.focus == focusDriveBtn, accent},
	}

	if m.isRunning {
		buttons = append(buttons, struct {
			label  string
			focus  bool
			color  lipgloss.AdaptiveColor
		}{"🛑 Cancel", m.focus == focusCancelBtn, red})
	} else {
		buttons = append(buttons, struct {
			label  string
			focus  bool
			color  lipgloss.AdaptiveColor
		}{"📦 Archive", m.focus == focusArchiveBtn, green})
	}

	for _, btn := range buttons {
		style := lipgloss.NewStyle().Foreground(btn.color)
		if btn.focus {
			style = style.Bold(true)
			b.WriteString(style.Render("[" + btn.label + "]"))
		} else {
			b.WriteString(style.Render(" " + btn.label + " "))
		}
		b.WriteString("  ")
	}

	return b.String()
}

// ── Settings view ─────────────────────────────────────────────

func (m model) settingsView() string {
	var b strings.Builder

	b.WriteString(appTitle.Render("📦 PKarchives") + "  " + warnStyle.Render("⚙ Settings"))
	b.WriteString("\n\n")

	// System info card
	content := fmt.Sprintf(
		"%s %s/%s\n%s %s\n%s %s\n%s %s",
		labelStyle.Render("System:    "), valueStyle.Render(fmt.Sprintf("%s/%s", m.osName, m.arch)),
		"",
		labelStyle.Render("macOS:     "), valueStyle.Render(m.macOS),
		"",
		labelStyle.Render("rclone:    "), valueStyle.Render(m.rcloneVer),
		"",
	)
	_ = content

	// Settings inputs
	labels := []string{"Drive Folder ID", "Desktop Path", "rclone Remote"}
	for i, input := range m.inputs {
		focusMark := "  "
		if i == m.inputFocus {
			focusMark = "▶ "
		}
		b.WriteString(fmt.Sprintf("%s%s ", focusMark, labelStyle.Render(labels[i]+":")))
		b.WriteString(input.View())
		b.WriteString("\n\n")
	}

	b.WriteString(hintStyle.Render("Enter: save · Tab: next field · Esc: cancel"))
	b.WriteString("\n")
	b.WriteString(hintStyle.Render(fmt.Sprintf("Config: ~/.pkarchives.conf")))

	return cardStyle.Render(b.String())
}

// ── Helpers ───────────────────────────────────────────────────

func faint(s string) string {
	return lipgloss.NewStyle().Foreground(gray).Render(s)
}

func openURL(url string) {
	switch runtime.GOOS {
	case "darwin":
		exec.Command("open", url).Start()
	case "linux":
		exec.Command("xdg-open", url).Start()
	case "windows":
		exec.Command("rundll32", "url.dll,FileProtocolHandler", url).Start()
	}
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

// ═══════════════════════════════════════════════════════════════
//  Main
// ═══════════════════════════════════════════════════════════════

func main() {
	p := tea.NewProgram(initialModel(), tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
