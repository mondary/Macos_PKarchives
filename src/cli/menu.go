package main

import (
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type menuItem struct {
	title    string
	subtitle string
	badge    string
	hotkey   string
	features [3]string
	accent   lipgloss.AdaptiveColor
	fill     lipgloss.Color
}

func menuItems(t Theme) []menuItem {
	return []menuItem{
		{
			title: "ARCHIVE FILES", subtitle: "Desktop files only",
			badge: "ONE-SHOT", hotkey: "1",
			features: [3]string{"Files only", "Folders excluded", "Fast scan & upload"},
			accent:   t.Accent, fill: t.SelectArchive,
		},
		{
			title: "FILES + FOLDERS", subtitle: "Everything on Desktop",
			badge: "RECURSIVE", hotkey: "2",
			features: [3]string{"Files + folders", "Recursive walk", "Full cleanup"},
			accent:   t.Amber, fill: t.SelectHistory,
		},
		{
			title: "HISTORY", subtitle: "Past runs & stats",
			badge: "LOG", hotkey: "3",
			features: [3]string{"Bar chart", "Space freed", "Run details"},
			accent:   t.Violet, fill: t.SelectSettings,
		},
		{
			title: "SETTINGS", subtitle: "Config & themes",
			badge: "TUNE", hotkey: "4",
			features: [3]string{"Drive config", "10 themes", "Path setup"},
			accent:   t.Success, fill: t.SelectExit,
		},
	}
}

type menuModel struct {
	theme   Theme
	compact bool
	width   int
	height  int
	cursor  int
	hovered int
	pulse   float64
	spinner spinner.Model
	items   []menuItem
}

type menuTickMsg struct{}

func menuTick() tea.Cmd {
	return tea.Tick(100*time.Millisecond, func(t time.Time) tea.Msg { return menuTickMsg{} })
}

func newMenu(t Theme, compact bool, w, h int) menuModel {
	s := spinner.New()
	s.Spinner = spinner.Dot
	s.Style = lipgloss.NewStyle().Foreground(t.Accent)
	return menuModel{
		theme:   t,
		compact: compact,
		width:   w,
		height:  h,
		cursor:  0,
		hovered: -1,
		items:   menuItems(t),
	}
}

func (m menuModel) init() tea.Cmd {
	return tea.Batch(m.spinner.Tick, menuTick())
}

func (m menuModel) update(msg tea.Msg) (menuModel, tea.Cmd) {
	switch msg := msg.(type) {
	case menuTickMsg:
		m.pulse += 0.08
		if m.pulse >= 1.0 {
			m.pulse = 0
		}
		return m, menuTick()
	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		return m, cmd
	}
	return m, nil
}

func (m *menuModel) move(delta int) {
	m.cursor = (m.cursor + delta + len(m.items)) % len(m.items)
}

func (m menuModel) view() string {
	t := m.theme

	// ── Header ─────────────────────────────────
	var header string
	if m.compact || m.height < 36 {
		header = compactHeader(t)
	} else {
		header = logoGradient(t)
	}

	rule := lipgloss.NewStyle().Foreground(t.Border).Render(strings.Repeat("─", 36))

	// ── Cards ──────────────────────────────────
	mode, boxW := m.computeLayout()

	boxes := make([]string, len(m.items))
	for i, it := range m.items {
		boxes[i] = m.renderBox(i, it, boxW)
	}

	var cards string
	gap := 2
	switch mode {
	case "vertical":
		parts := make([]string, len(boxes))
		for i, b := range boxes {
			if i < len(boxes)-1 {
				parts[i] = lipgloss.NewStyle().MarginBottom(1).Render(b)
			} else {
				parts[i] = b
			}
		}
		cards = lipgloss.JoinVertical(lipgloss.Left, parts...)
	case "grid":
		row0 := lipgloss.JoinHorizontal(lipgloss.Top,
			lipgloss.NewStyle().MarginRight(gap).Render(boxes[0]),
			boxes[1],
		)
		row1 := lipgloss.JoinHorizontal(lipgloss.Top,
			lipgloss.NewStyle().MarginRight(gap).Render(boxes[2]),
			boxes[3],
		)
		cards = lipgloss.JoinVertical(lipgloss.Center, row0, lipgloss.NewStyle().Height(1).Render(""), row1)
	default:
		parts := make([]string, len(boxes))
		for i, b := range boxes {
			if i < len(boxes)-1 {
				parts[i] = lipgloss.NewStyle().MarginRight(gap).Render(b)
			} else {
				parts[i] = b
			}
		}
		cards = lipgloss.JoinHorizontal(lipgloss.Top, parts...)
	}

	// ── Hint bar ───────────────────────────────
	hl := lipgloss.NewStyle().Foreground(t.Success).Bold(true)
	mt := lipgloss.NewStyle().Foreground(t.Muted)
	hint := lipgloss.JoinHorizontal(lipgloss.Center,
		hl.Render("←→↑↓"), mt.Render(" move  ·  "),
		hl.Render("1-4"), mt.Render(" pick  ·  "),
		hl.Render("enter"), mt.Render(" select  ·  "),
		hl.Render("o"), mt.Render(" Drive  ·  "),
		hl.Render("t"), mt.Render(" compact  ·  "),
		hl.Render("?"), mt.Render(" help  ·  "),
		hl.Render("q"), mt.Render(" quit"),
	)

	stack := lipgloss.JoinVertical(lipgloss.Center,
		header,
		rule,
		"",
		cards,
		"",
		hint,
	)

	return paintScreen(t, m.width, m.height, stack)
}

func (m menuModel) computeLayout() (string, int) {
	w := m.width
	if w <= 0 {
		w = 100
	}
	maxEach := 34
	each := (w - 4 - 2*2) / 2
	if each > maxEach {
		each = maxEach
	}
	if each < 22 {
		each = 22
	}
	if w >= 88 {
		return "grid", each
	}
	// vertical fallback
	return "vertical", clamp(each, 22, 42)
}

func (m menuModel) renderBox(i int, it menuItem, cardWidth int) string {
	t := m.theme
	selected := i == m.cursor

	accent := it.accent
	fill := it.fill

	var bg lipgloss.TerminalColor
	if selected {
		bg = fill
	} else {
		bg = t.IdleFill
	}

	innerW := cardWidth - 4
	if innerW < 12 {
		innerW = 12
	}

	ink := lipgloss.Color("#0a0e14")

	cell := func(fg lipgloss.TerminalColor, bold bool) lipgloss.Style {
		s := lipgloss.NewStyle().Foreground(fg).Background(bg)
		if bold {
			s = s.Bold(true)
		}
		return s
	}
	space := lipgloss.NewStyle().Background(bg)
	line := func(parts ...string) string {
		joined := strings.Join(parts, "")
		return lipgloss.NewStyle().Width(innerW).Background(bg).Inline(true).Render(joined)
	}

	// ── Title row: [hotkey chip] [space] [title pill] ──
	var chip, titleBlock string
	if selected {
		chip = lipgloss.NewStyle().Foreground(ink).Background(accent).Bold(true).Padding(0, 1).Render(it.hotkey)
		titleBlock = lipgloss.NewStyle().Foreground(ink).Background(accent).Bold(true).Padding(0, 1).Render(it.title)
	} else {
		chip = lipgloss.NewStyle().Foreground(accent).Background(bg).Bold(true).Padding(0, 1).Render(it.hotkey)
		titleBlock = lipgloss.NewStyle().Foreground(accent).Background(bg).Bold(true).Padding(0, 1).Render(it.title)
	}
	titleRow := line(chip, space.Render(" "), titleBlock)

	// ── Subtitle ──
	subFG := t.Muted
	if selected {
		subFG = t.Foreground
	}
	subRow := line(space.Render("  "), cell(subFG, false).Render(it.subtitle))

	// ── Divider ──
	divCh := "─"
	if selected {
		divCh = "━"
	}
	div := line(cell(accent, false).Render(strings.Repeat(divCh, min(innerW, 22))))

	// ── Feature rows ──
	featRows := make([]string, 3)
	for j := 0; j < 3; j++ {
		if j < len(it.features) {
			bullet := cell(accent, false).Render("› ")
			if !selected {
				bullet = cell(t.Border, false).Render("· ")
			}
			featRows[j] = line(space.Render(" "), bullet, cell(t.Muted, false).Render(it.features[j]))
		} else {
			featRows[j] = line("")
		}
	}

	// ── Badge row ──
	var badgeRow string
	if it.badge != "" {
		var badge string
		if selected {
			badge = lipgloss.NewStyle().Foreground(ink).Background(accent).Bold(true).Padding(0, 1).Render(it.badge)
		} else {
			badge = lipgloss.NewStyle().Foreground(accent).Background(bg).Bold(true).Render(" " + it.badge + " ")
		}
		badgeRow = line(space.Render(" "), badge)
	} else if selected {
		badgeRow = line(space.Render(" "), cell(accent, true).Render("↵ enter"))
	} else {
		badgeRow = line("")
	}

	// ── Top accent bar (selected only) ──
	topBar := line("")
	if selected {
		topBar = line(cell(accent, false).Render(strings.Repeat("▀", innerW)))
	}

	// ── Assemble body ──
	body := strings.Join([]string{
		topBar,
		titleRow,
		subRow,
		line(""),
		div,
		line(""),
		featRows[0],
		featRows[1],
		featRows[2],
		line(""),
		badgeRow,
		line(""),
	}, "\n")

	// ── Card frame ──
	borderCol := t.Border
	if selected {
		borderCol = accent
	}

	box := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(borderCol).
		Background(bg).
		Padding(1, 2).
		Width(cardWidth).
		Align(lipgloss.Left).
		Render(body)

	// ── Glow bar BELOW the card (external) ──
	if selected {
		pf := pulseFactor(m.pulse)
		gw := int(float64(cardWidth) * (0.72 + 0.28*pf))
		if gw < cardWidth/2 {
			gw = cardWidth / 2
		}
		if gw > cardWidth {
			gw = cardWidth
		}
		bar := lipgloss.NewStyle().Foreground(accent).Bold(true).Render(strings.Repeat("▀", gw))
		pad := (cardWidth - gw) / 2
		if pad < 0 {
			pad = 0
		}
		under := strings.Repeat(" ", pad) + bar
		box = lipgloss.JoinVertical(lipgloss.Left, box, under)
	} else {
		box = lipgloss.JoinVertical(lipgloss.Left, box, strings.Repeat(" ", cardWidth))
	}
	return box
}

func pulseFactor(p float64) float64 {
	frac := p - float64(int(p))
	if frac < 0.5 {
		return 0.6 + frac*0.8
	}
	return 1.0 - (frac-0.5)*0.8
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
