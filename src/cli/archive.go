package main

import (
	"context"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type archivePhase int

const (
	archiveIdle archivePhase = iota
	archiveScanning
	archiveUploading
	archiveDeleting
	archiveMounting
	archiveDone
	archiveFailed
	archiveEmpty
)

type archiveModel struct {
	theme   Theme
	compact bool
	width   int
	height  int
	cfg     Config
	mode    string

	phase   archivePhase
	spinner spinner.Model
	running bool

	items   []fileItem
	current int
	success int
	deleted int

	subPaths []string
	subNames []string
	subIdx   int
	subTotal int

	started      time.Time
	fileStart    time.Time
	fileSize     int64
	sessionBytes int64

	graph     *graph
	speedDisp float64
	speedTgt  float64

	output    []string
	status    string
	lastMount string
	history   []historyEntry
}

func newArchive(t Theme, compact bool, w, h int, cfg Config, hist []historyEntry) archiveModel {
	s := spinner.New()
	s.Spinner = spinner.Dot
	s.Style = lipgloss.NewStyle().Foreground(t.Accent)
	gw := clamp(w-12, 30, 56)
	return archiveModel{
		theme:   t,
		compact: compact,
		width:   w,
		height:  h,
		cfg:     cfg,
		phase:   archiveIdle,
		spinner: s,
		graph:   newGraph(gw, graphHeight, t.GraphBottom, t.GraphTop),
		history: hist,
	}
}

func (a *archiveModel) start(mode string) tea.Cmd {
	if a.cfg.DriveFolderID == "" {
		a.status = "Drive Folder ID required — configure in Settings"
		a.phase = archiveFailed
		return nil
	}
	a.mode = mode
	a.phase = archiveScanning
	a.running = true
	a.started = time.Now()
	a.sessionBytes = 0
	a.output = a.output[:0]
	a.graph = newGraph(a.graph.width, graphHeight, a.theme.GraphBottom, a.theme.GraphTop)
	return tea.Batch(a.spinner.Tick, scanCmd(a.cfg, mode))
}

func (a *archiveModel) cancel() {
	a.phase = archiveIdle
	a.running = false
	a.status = "Cancelled"
}

func (a archiveModel) init() tea.Cmd { return nil }

func (a *archiveModel) update(msg tea.Msg) (archiveModel, tea.Cmd) {
	switch msg := msg.(type) {
	case spinner.TickMsg:
		var cmd tea.Cmd
		a.spinner, cmd = a.spinner.Update(msg)
		if a.running {
			a.tickAnim()
			return *a, tea.Batch(cmd, a.spinner.Tick)
		}
		return *a, nil

	case scanDoneMsg:
		if msg.err != nil {
			return a.fail(msg.err.Error())
		}
		a.items = msg.items
		if len(msg.items) == 0 {
			a.phase = archiveEmpty
			a.running = false
			a.status = "Desktop is clean — nothing to archive"
			return *a, nil
		}
		a.phase = archiveUploading
		a.phase, a.current, a.success = archiveUploading, 0, 0
		a.output = a.output[:0]
		a.fileStart = time.Now()
		return *a, tea.Batch(a.spinner.Tick, startUploadCmd(a.cfg, a.items, 0))

	case dirScannedMsg:
		a.subPaths = msg.paths
		a.subNames = msg.names
		a.subIdx = 0
		a.subTotal = len(msg.paths)
		if a.subTotal == 0 {
			return *a, itemDoneCmd(a.current, a.items[a.current].Name, true, nil)
		}
		a.fileStart = time.Now()
		return *a, uploadSubFileCmd(a.cfg, msg.parentIdx, a.subPaths, a.subNames, 0)

	case subFileDoneMsg:
		if msg.err != nil {
			return a.fail(msg.err.Error())
		}
		a.subIdx = msg.subIdx + 1
		if msg.subIdx < len(a.subPaths) {
			bytes := itemBytes(a.subPaths[msg.subIdx])
			uploadDuration := time.Since(a.fileStart).Seconds()
			if uploadDuration > 0 && bytes > 0 {
				a.speedTgt = float64(bytes) / uploadDuration
			}
			a.sessionBytes += bytes
		}
		if a.subIdx >= a.subTotal {
			return *a, itemDoneCmd(a.current, a.items[a.current].Name, true, nil)
		}
		a.fileStart = time.Now()
		return *a, uploadSubFileCmd(a.cfg, msg.parentIdx, a.subPaths, a.subNames, a.subIdx)

	case itemDoneMsg:
		if msg.err != nil {
			return a.fail(msg.err.Error())
		}
		if !msg.isDir && msg.index < len(a.items) {
			bytes := itemBytes(a.items[msg.index].Path)
			uploadDuration := time.Since(a.fileStart).Seconds()
			if uploadDuration > 0 && bytes > 0 {
				a.speedTgt = float64(bytes) / uploadDuration
			}
			a.sessionBytes += bytes
		}
		a.phase = archiveDeleting
		a.deleted = msg.index
		return *a, tea.Batch(a.spinner.Tick, deleteItemCmd(a.items, msg.index, len(a.items)))

	case deleteDoneMsg:
		if msg.err != nil {
			return a.fail(msg.err.Error())
		}
		a.success++
		a.current = msg.index + 1
		name := ""
		if msg.index < len(a.items) {
			name = a.items[msg.index].Name
		}
		a.output = append(a.output, fmt.Sprintf("✓ %s → archived & deleted", truncate(name, 36)))
		if len(a.output) > 8 {
			a.output = a.output[len(a.output)-8:]
		}
		if a.current < len(a.items) {
			a.phase = archiveUploading
			a.fileStart = time.Now()
			return *a, startUploadCmd(a.cfg, a.items, a.current)
		}
		a.phase = archiveMounting
		return *a, tea.Batch(a.spinner.Tick, mountCmd(a.cfg))

	case mountDoneMsg:
		a.lastMount = msg.mountPath
		a.running = false
		if msg.err != nil {
			a.status = "Archive complete — mount unavailable"
		} else {
			a.status = "Archive complete"
		}
		a.phase = archiveDone
		record := historyEntry{
			Date:    time.Now(),
			Mode:    modeName(a.items),
			Items:   len(a.items),
			Success: a.success,
			Bytes:   a.sessionBytes,
			MountOK: msg.err == nil,
		}
		a.history = append([]historyEntry{record}, a.history...)
		_ = saveHistory(a.history)
		return *a, nil
	}
	return *a, nil
}

func (a *archiveModel) tickAnim() {
	// Decay speed target — set on file completion, decays each tick
	// This creates a wave pattern: spike when file completes, slow fade while next uploads
	a.speedTgt *= 0.93
	a.speedDisp = lerp(a.speedDisp, a.speedTgt, animFactor)
	a.graph.push(a.speedDisp)
}

func (a *archiveModel) fail(msg string) (archiveModel, tea.Cmd) {
	a.phase = archiveFailed
	a.running = false
	a.status = msg
	return *a, nil
}

// ── Engine commands ────────────────────────────────────────────

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

func scanCmd(cfg Config, mode string) tea.Cmd {
	return func() tea.Msg {
		items, err := scanDesktop(cfg, mode)
		return scanDoneMsg{items, err}
	}
}

func startUploadCmd(cfg Config, items []fileItem, idx int) tea.Cmd {
	return func() tea.Msg {
		item := items[idx]
		if item.IsDir {
			paths, names := walkDir(item.Path)
			return dirScannedMsg{idx, paths, names}
		}
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
		defer cancel()
		err := rcloneUpload(ctx, cfg, item.Path, archiveDestination(cfg))
		return itemDoneMsg{idx, item.Name, false, err}
	}
}

func uploadSubFileCmd(cfg Config, parent int, paths, names []string, idx int) tea.Cmd {
	return func() tea.Msg {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
		defer cancel()
		err := rcloneUpload(ctx, cfg, paths[idx], archiveDestination(cfg))
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

func mountCmd(cfg Config) tea.Cmd {
	return func() tea.Msg {
		mount, err := mountDrive(cfg)
		return mountDoneMsg{mount, err}
	}
}

// ── View ───────────────────────────────────────────────────────

func (a archiveModel) view() string {
	t := a.theme
	header := compactHeader(t)

	// ── Build card body ──
	statusLine := a.renderStatus()
	total := len(a.items)
	if total == 0 {
		total = 1
	}
	progress := a.current
	if a.phase == archiveDone {
		progress = total
	}

	metricBlock := a.renderMetricBlock()

	bar := progressBar(progress, total, clamp(a.graph.width, 20, 52), t.Accent)
	progressLabel := lipgloss.NewStyle().Foreground(t.Muted).Render(
		fmt.Sprintf("  %d / %d", progress, total),
	)

	// ── Assemble inner card ──
	titleChip := titlePill(t, "ARCHIVE", t.SolidAccent)
	innerW := cardWidth - 4

	cardBody := lipgloss.JoinVertical(lipgloss.Left,
		center(titleChip, innerW),
		"",
		center(statusLine, innerW),
		"",
		metricBlock,
		"",
		center(bar+progressLabel, innerW),
	)

	mainCard := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(t.Border).
		Background(t.AppBg).
		Padding(1, 2).
		Width(cardWidth).
		Align(lipgloss.Left).
		Render(cardBody)

	// ── Stats row ──
	stats := a.renderStats()

	// ── Log section ──
	var logSection string
	if len(a.output) > 0 {
		logLines := make([]string, len(a.output))
		for i, line := range a.output {
			logLines[i] = lipgloss.NewStyle().Foreground(t.Foreground).Render(line)
		}
		logSection = renderPanel(t, strings.Join(logLines, "\n"), clamp(a.width-8, 40, 72))
	}

	hints := hintBar(t, []hint{
		{"esc", ternary(a.phase == archiveDone, "back", "cancel")},
		{"o", "Drive"},
		{"q", "quit"},
	})

	sections := []string{header, "", mainCard}
	if stats != "" {
		sections = append(sections, "", stats)
	}
	if logSection != "" {
		sections = append(sections, "", logSection)
	}
	sections = append(sections, "", hints)

	stack := lipgloss.JoinVertical(lipgloss.Center, sections...)
	return paintScreen(t, a.width, a.height, stack)
}

func (a archiveModel) renderMetricBlock() string {
	t := a.theme
	speedStr := formatSpeed(a.speedDisp)
	speedNum := lipgloss.NewStyle().Foreground(t.Accent).Bold(true).Width(10).Align(lipgloss.Right).Render(speedStr)
	label := lipgloss.NewStyle().Foreground(t.Accent).Bold(true).Render("↓ transfer rate")
	muted := lipgloss.NewStyle().Foreground(t.Muted)

	head := lipgloss.JoinHorizontal(lipgloss.Left,
		label, "  ", speedNum,
	)

	graphStr := a.graph.view()
	if graphStr == "" {
		graphStr = strings.Repeat(" ", a.graph.width)
	}

	rail := lipgloss.NewStyle().Foreground(t.Accent).Render("▌")
	corner := lipgloss.NewStyle().Foreground(t.Accent).Render("└")
	border := lipgloss.NewStyle().Foreground(t.Border).Render(strings.Repeat("─", a.graph.width))

	framed := make([]string, 0, a.graph.height+1)
	for _, line := range strings.Split(graphStr, "\n") {
		framed = append(framed, rail+line)
	}
	framed = append(framed, corner+border)

	peakInfo := muted.Render("")
	_ = peakInfo

	return head + "\n" + strings.Join(framed, "\n")
}

func (a archiveModel) renderStatus() string {
	t := a.theme
	var status string
	switch a.phase {
	case archiveIdle:
		status = lipgloss.NewStyle().Foreground(t.Muted).Render("Ready to archive")
	case archiveScanning:
		status = a.spinner.View() + " " +
			lipgloss.NewStyle().Foreground(t.Accent).Render("Scanning Desktop") +
			lipgloss.NewStyle().Foreground(t.Muted).Render(" — looking for files to archive")
	case archiveUploading:
		item := ""
		if a.current < len(a.items) {
			item = truncate(a.items[a.current].Name, 28)
		}
		status = a.spinner.View() + " " +
			lipgloss.NewStyle().Foreground(t.Accent).Bold(true).Render(
				fmt.Sprintf("Uploading %d/%d", a.current+1, len(a.items))) +
			lipgloss.NewStyle().Foreground(t.Muted).Render(" — "+item)
		if a.subTotal > 0 {
			status += lipgloss.NewStyle().Foreground(t.Muted).Render(
				fmt.Sprintf("  [sub-file %d/%d]", a.subIdx+1, a.subTotal))
		}
	case archiveDeleting:
		status = a.spinner.View() + " " +
			lipgloss.NewStyle().Foreground(t.Amber).Render(
				fmt.Sprintf("Deleting %d/%d", a.deleted+1, len(a.items)))
	case archiveMounting:
		status = a.spinner.View() + " " +
			lipgloss.NewStyle().Foreground(t.Violet).Render("Mounting Drive") +
			lipgloss.NewStyle().Foreground(t.Muted).Render(" — ~/Desktop/"+a.cfg.LinkName)
	case archiveDone:
		status = lipgloss.NewStyle().Foreground(t.Success).Bold(true).Render("✓") + " " +
			lipgloss.NewStyle().Foreground(t.Success).Render(
				fmt.Sprintf("%d/%d items archived", a.success, len(a.items))) +
			lipgloss.NewStyle().Foreground(t.Muted).Render(
				fmt.Sprintf("  ·  %s freed  ·  %s", formatBytes(a.sessionBytes), time.Since(a.started).Round(time.Second)))
	case archiveFailed:
		status = lipgloss.NewStyle().Foreground(t.Danger).Render("✗ " + a.status)
	case archiveEmpty:
		status = lipgloss.NewStyle().Foreground(t.Muted).Render("✓ Desktop is clean — nothing to archive")
	}
	return status
}

func (a archiveModel) renderStats() string {
	t := a.theme
	total := len(a.items)
	if total == 0 {
		total = 1
	}

	stat := func(label string, value string, accent lipgloss.AdaptiveColor) string {
		return lipgloss.JoinVertical(lipgloss.Left,
			lipgloss.NewStyle().Foreground(t.Muted).Render(label),
			lipgloss.NewStyle().Foreground(accent).Bold(true).Render(value),
		)
	}

	cols := []string{
		stat("ITEMS", fmt.Sprintf("%d / %d", a.success, total), t.Accent),
		stat("FREED", formatBytes(a.sessionBytes), t.Amber),
		stat("ELAPSED", time.Since(a.started).Round(time.Second).String(), t.Violet),
	}

	mountStat := "offline"
	mountColor := t.Danger
	if a.lastMount != "" && isMountActive(a.lastMount) {
		mountStat = "mounted"
		mountColor = t.Success
	}
	if a.phase == archiveDone || a.phase == archiveMounting {
		cols = append(cols, stat("MOUNT", mountStat, mountColor))
	}

	cardW := clamp((a.width-12)/len(cols), 14, 22)
	rendered := make([]string, len(cols))
	for i, c := range cols {
		rendered[i] = renderPanel(t, lipgloss.NewStyle().Width(cardW-4).Align(lipgloss.Center).Render(c), cardW)
	}
	gap := lipgloss.NewStyle().Width(2).Render(" ")
	return lipgloss.JoinHorizontal(lipgloss.Top, joinWithGap(rendered, gap)...)
}

func joinWithGap(items []string, gap string) []string {
	if len(items) == 0 {
		return nil
	}
	result := []string{items[0]}
	for _, item := range items[1:] {
		result = append(result, gap, item)
	}
	return result
}

func ternary(cond bool, a, b string) string {
	if cond {
		return a
	}
	return b
}


