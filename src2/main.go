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
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// ── Styles (palette sombre style Riptide) ─────────────────────

var (
	fg        = lipgloss.AdaptiveColor{Dark: "#e6edf3"}
	muted     = lipgloss.AdaptiveColor{Dark: "#7d8590"}
	borderCol = lipgloss.AdaptiveColor{Dark: "#30363d"}
	accent    = lipgloss.AdaptiveColor{Dark: "#39d0d8"}
	green     = lipgloss.AdaptiveColor{Dark: "#7ee787"}
	red       = lipgloss.AdaptiveColor{Dark: "#ff7b72"}
	yellow    = lipgloss.AdaptiveColor{Dark: "#f0c674"}

	yellowStyle = lipgloss.NewStyle().Foreground(yellow)

	cardStyle   = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(borderCol).Padding(1, 3)
	titleStyle  = lipgloss.NewStyle().Bold(true).Foreground(accent).MarginBottom(1)
	labelStyle  = lipgloss.NewStyle().Foreground(muted)
	valueStyle  = lipgloss.NewStyle().Foreground(fg).Bold(true)
	doneStyle   = lipgloss.NewStyle().Foreground(green).Bold(true)
	errStyle    = lipgloss.NewStyle().Foreground(red).Bold(true)
	hintStyle   = lipgloss.NewStyle().Foreground(muted).MarginTop(1)
	boldStyle   = lipgloss.NewStyle().Bold(true)
)

// ── Config ────────────────────────────────────────────────────

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

	// Env vars
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

	// Fichier ~/.pkarchives.conf
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
	month := now.Format("01")
	monthName := strings.ToLower(now.Format("January"))
	return fmt.Sprintf("%d_%s_%s", now.Year(), month, monthName)
}

// ── Archive logic ─────────────────────────────────────────────

type fileItem struct {
	Path  string
	Name  string
	IsDir bool
	Size  int64
}

func scanDesktop(cfg Config) ([]fileItem, error) {
	entries, err := os.ReadDir(cfg.DesktopPath)
	if err != nil {
		return nil, err
	}

	var files, dirs []fileItem
	for _, e := range entries {
		name := e.Name()
		if name == cfg.LinkName || name == ".DS_Store" {
			continue
		}

		fullPath := filepath.Join(cfg.DesktopPath, name)
		info, err := e.Info()
		if err != nil {
			continue
		}

		if e.IsDir() {
			dirs = append(dirs, fileItem{Path: fullPath, Name: name, IsDir: true, Size: info.Size()})
		} else {
			files = append(files, fileItem{Path: fullPath, Name: name, IsDir: false, Size: info.Size()})
		}
	}

	// Files triés par taille (plus petit d'abord), puis dossiers
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

// ── Messages ──────────────────────────────────────────────────

type scanDoneMsg struct {
	items []fileItem
	err   error
}

type uploadProgressMsg struct {
	index    int
	subIndex int
	subTotal int
	name     string
	ok       bool
	err      error
}

type deleteProgressMsg struct {
	index int
	name  string
}

type allDoneMsg struct {
	success int
	total   int
	err     error
}

type errMsg struct{ err error }

// ── Model ─────────────────────────────────────────────────────

type phase int

const (
	phaseIntro phase = iota
	phaseScanning
	phaseUploading
	phaseDeleting
	phaseDone
	phaseFailed
	phaseEmpty
)

type model struct {
	width   int
	height  int
	phase   phase
	spinner spinner.Model
	cfg     Config

	// Scan
	items   []fileItem
	scanErr error

	// Upload
	currentIdx int
	success    int
	uploadLog  string

	// Delete
	deletedIdx int

	// Result
	failErr error

	// System info
	os     string
	arch   string
	macOS  string
	shell  string
	rclone string
}

func initialModel() model {
	cfg := loadConfig()
	s := spinner.New()
	s.Spinner = spinner.Dot

	home, _ := os.UserHomeDir()
	shell := filepath.Base(os.Getenv("SHELL"))
	if shell == "" {
		shell = filepath.Base(home + "/.shellrc")
	}

	macOS := "N/A"
	if out, err := exec.Command("sw_vers", "-productVersion").Output(); err == nil {
		macOS = strings.TrimSpace(string(out))
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

	return model{
		phase:   phaseIntro,
		spinner: s,
		cfg:     cfg,
		os:      runtime.GOOS,
		arch:    runtime.GOARCH,
		macOS:   macOS,
		shell:   shell,
		rclone:  rcloneVer,
	}
}

func (m model) Init() tea.Cmd { return nil }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		return m, nil

	case tea.KeyMsg:
		switch msg.String() {
		case "q", "esc", "ctrl+c":
			return m, tea.Quit
		case "enter":
			switch m.phase {
			case phaseIntro:
				if m.cfg.DriveFolderID == "" {
					m.phase = phaseFailed
					m.failErr = fmt.Errorf("PKARCHIVES_DRIVE_FOLDER_ID not set.\n   Run setup first or set the env var.")
					return m, nil
				}
				m.phase = phaseScanning
				return m, tea.Batch(m.spinner.Tick, scanDesktopCmd(m.cfg))
			case phaseDone, phaseFailed, phaseEmpty:
				return m, tea.Quit
			}
		}

	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		return m, cmd

	case scanDoneMsg:
		if msg.err != nil {
			m.phase = phaseFailed
			m.failErr = msg.err
			return m, nil
		}
		m.items = msg.items
		if len(msg.items) == 0 {
			m.phase = phaseEmpty
			return m, nil
		}
		m.phase = phaseUploading
		m.currentIdx = 0
		return m, tea.Batch(m.spinner.Tick, uploadItemCmd(m.cfg, m.items, 0))

	case uploadProgressMsg:
		if msg.err != nil {
			m.uploadLog += fmt.Sprintf("  ✗ %s: %v\n", msg.name, msg.err)
		} else {
			m.uploadLog += fmt.Sprintf("  ✓ %s\n", msg.name)
			m.success++
		}
		next := msg.index + 1
		if next >= len(m.items) {
			m.phase = phaseDeleting
			m.deletedIdx = 0
			return m, tea.Batch(m.spinner.Tick, deleteItemCmd(m.items, 0))
		}
		m.currentIdx = next
		return m, tea.Batch(m.spinner.Tick, uploadItemCmd(m.cfg, m.items, next))

	case deleteProgressMsg:
		next := msg.index + 1
		if next >= m.success {
			m.phase = phaseDone
			return m, nil
		}
		m.deletedIdx = next
		return m, tea.Batch(m.spinner.Tick, deleteItemCmd(m.items, next))

	case errMsg:
		m.phase = phaseFailed
		m.failErr = msg.err
		return m, nil
	}

	return m, nil
}

// ── Commands ──────────────────────────────────────────────────

func scanDesktopCmd(cfg Config) tea.Cmd {
	return func() tea.Msg {
		items, err := scanDesktop(cfg)
		return scanDoneMsg{items: items, err: err}
	}
}

func uploadItemCmd(cfg Config, items []fileItem, idx int) tea.Cmd {
	return func() tea.Msg {
		item := items[idx]
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
		defer cancel()

		rcloneDir := fmt.Sprintf("%s:%s", cfg.RcloneRemote, monthYear())

		if item.IsDir {
			// Upload tous les fichiers du dossier
			var subFiles []string
			filepath.Walk(item.Path, func(path string, info os.FileInfo, err error) error {
				if err != nil || info.IsDir() || strings.HasPrefix(info.Name(), ".") {
					return nil
				}
				subFiles = append(subFiles, path)
				return nil
			})

			for _, sf := range subFiles {
				rcloneUpload(ctx, cfg, sf, rcloneDir)
			}
		} else {
			rcloneUpload(ctx, cfg, item.Path, rcloneDir)
		}

		return uploadProgressMsg{index: idx, name: item.Name, ok: true}
	}
}

func deleteItemCmd(items []fileItem, idx int) tea.Cmd {
	return func() tea.Msg {
		// Supprime seulement les items uploadés avec succès (idx < success)
		if idx < len(items) {
			os.RemoveAll(items[idx].Path)
		}
		return deleteProgressMsg{index: idx, name: items[idx].Name}
	}
}

// ── Views ─────────────────────────────────────────────────────

func (m model) View() string {
	var body string
	switch m.phase {
	case phaseIntro:
		body = m.introView()
	case phaseScanning:
		body = m.scanningView()
	case phaseUploading:
		body = m.uploadingView()
	case phaseDeleting:
		body = m.deletingView()
	case phaseDone:
		body = m.doneView()
	case phaseFailed:
		body = m.failedView()
	case phaseEmpty:
		body = m.emptyView()
	}

	if m.width > 0 && m.height > 0 {
		return lipgloss.Place(m.width, m.height, lipgloss.Center, lipgloss.Center, body)
	}
	return body
}

func (m model) introView() string {
	var b strings.Builder
	b.WriteString(titleStyle.Render("📦  PKarchives") + "\n\n")
	b.WriteString(labelStyle.Render("System:    "))
	b.WriteString(valueStyle.Render(fmt.Sprintf("%s/%s", m.os, m.arch)) + "\n")
	b.WriteString(labelStyle.Render("macOS:     "))
	b.WriteString(valueStyle.Render(m.macOS) + "\n")
	b.WriteString(labelStyle.Render("Shell:     "))
	b.WriteString(valueStyle.Render(m.shell) + "\n")
	b.WriteString(labelStyle.Render("rclone:    "))
	if strings.Contains(m.rclone, "not found") {
		b.WriteString(errStyle.Render(m.rclone) + "\n")
	} else {
		b.WriteString(valueStyle.Render(m.rclone))
		b.WriteString(" " + doneStyle.Render("(installed)") + "\n")
	}
	b.WriteString(labelStyle.Render("Folder:    "))
	b.WriteString(valueStyle.Render(m.cfg.DesktopPath) + "\n")
	b.WriteString(labelStyle.Render("Remote:    "))
	b.WriteString(valueStyle.Render(m.cfg.RcloneRemote) + "\n")
	b.WriteString(labelStyle.Render("Drive ID:  "))
	if m.cfg.DriveFolderID == "" {
		b.WriteString(errStyle.Render("(not configured)") + "\n")
	} else {
		b.WriteString(doneStyle.Render("configured") + "\n")
	}
	b.WriteString("\n" + hintStyle.Render("Enter: start archiving  ·  Esc: cancel"))
	return cardStyle.Render(b.String())
}

func (m model) scanningView() string {
	var b strings.Builder
	b.WriteString(titleStyle.Render("📦  PKarchives"))
	b.WriteString("\n\n")
	b.WriteString(m.spinner.View() + "  ")
	b.WriteString(labelStyle.Render("Scanning Desktop…"))
	return cardStyle.Render(b.String())
}

func (m model) uploadingView() string {
	var b strings.Builder
	b.WriteString(titleStyle.Render("📤  Uploading"))
	b.WriteString("\n\n")
	b.WriteString(fmt.Sprintf("%s  %d/%d — %s\n",
		m.spinner.View(),
		m.currentIdx+1, len(m.items),
		valueStyle.Render(m.items[m.currentIdx].Name)))
	b.WriteString("\n" + hintStyle.Render("Working…  ·  Esc to cancel"))

	// Log tail
	if m.uploadLog != "" {
		lines := strings.Split(strings.TrimSpace(m.uploadLog), "\n")
		if len(lines) > 6 {
			lines = lines[len(lines)-6:]
		}
		b.WriteString("\n\n" + labelStyle.Render(strings.Join(lines, "\n")))
	}
	return cardStyle.Render(b.String())
}

func (m model) deletingView() string {
	var b strings.Builder
	b.WriteString(titleStyle.Render("🧹  Cleaning up"))
	b.WriteString("\n\n")
	b.WriteString(fmt.Sprintf("%s  Deleting %d/%d items\n",
		m.spinner.View(),
		m.deletedIdx+1, m.success))
	b.WriteString("\n" + hintStyle.Render("Working…"))
	return cardStyle.Render(b.String())
}

func (m model) doneView() string {
	var b strings.Builder
	b.WriteString(doneStyle.Render("✓  Archive complete!") + "\n\n")
	b.WriteString(labelStyle.Render("Uploaded:  "))
	b.WriteString(valueStyle.Render(fmt.Sprintf("%d/%d items", m.success, len(m.items))) + "\n")
	b.WriteString(labelStyle.Render("Folder:    "))
	b.WriteString(valueStyle.Render(monthYear()) + "\n")
	b.WriteString("\n" + hintStyle.Render("Enter or q to finish"))
	return cardStyle.Render(b.String())
}

func (m model) failedView() string {
	var b strings.Builder
	b.WriteString(errStyle.Render("✗  Error") + "\n\n")
	b.WriteString(labelStyle.Render(m.failErr.Error()) + "\n")
	b.WriteString("\n" + hintStyle.Render("Enter or q to exit"))
	return cardStyle.Render(b.String())
}

func (m model) emptyView() string {
	var b strings.Builder
	b.WriteString(yellowStyle.Render("📭  Nothing to archive") + "\n\n")
	b.WriteString(labelStyle.Render("Your Desktop is already clean.") + "\n")
	b.WriteString("\n" + hintStyle.Render("Enter or q to exit"))
	return cardStyle.Render(b.String())
}

// ── Main ──────────────────────────────────────────────────────

func main() {
	p := tea.NewProgram(initialModel(), tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
