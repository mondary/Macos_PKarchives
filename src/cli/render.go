package main

import (
	"fmt"
	"math"
	"strings"

	"github.com/charmbracelet/lipgloss"
	colorful "github.com/lucasb-eyer/go-colorful"
)

const (
	animFactor    = 0.18
	graphHeight   = 9
	cardWidth     = 64
	innerCardWidth = 60
)

// ── Lerp & easing ──────────────────────────────────────────────

func lerp(a, b, t float64) float64 { return a + (b-a)*t }
func clampF(v, min, max float64) float64 {
	if v < min { return min }
	if v > max { return max }
	return v
}
func easeOutQuad(t float64) float64 { return 1 - (1-t)*(1-t) }

// ── Color blending (CIE-Lab for natural mid-stops) ─────────────

func lerpColor(bottom, top colorful.Color, t float64) colorful.Color {
	return bottom.BlendLab(top, clampF(t, 0, 1))
}

func blendTo(hex string, target colorful.Color, factor float64) colorful.Color {
	c, err := colorful.Hex(hex)
	if err != nil { return target }
	return c.BlendLab(target, clampF(factor, 0, 1))
}

func dimColor(hex string, factor float64) lipgloss.Color {
	c, _ := colorful.Hex(hex)
	dimmed, _ := colorful.Hex("#0e1419")
	blend := dimmed.BlendLab(c, clampF(factor, 0, 1))
	return lipgloss.Color(blend.Clamped().Hex())
}

func brighten(hex string, factor float64) lipgloss.Color {
	c, _ := colorful.Hex(hex)
	white, _ := colorful.Hex("#f0f6fc")
	blend := c.BlendLab(white, clampF(factor, 0, 1))
	return lipgloss.Color(blend.Clamped().Hex())
}

func peakSpark(topHex string) lipgloss.Color {
	top, _ := colorful.Hex(topHex)
	white, _ := colorful.Hex("#f0f6fc")
	blend := top.BlendLab(white, 0.55)
	return lipgloss.Color(blend.Clamped().Hex())
}

func colorToHex(c lipgloss.Color) string { return string(c) }

// ── Sparkline graph ────────────────────────────────────────────

var barRamp = []rune{' ', '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█'}

type graph struct {
	width, height int
	data          []float64
	bottom, top   lipgloss.Color
}

func newGraph(w, h int, bottom, top lipgloss.Color) *graph {
	return &graph{width: w, height: h, data: make([]float64, 0, w), bottom: bottom, top: top}
}

func (g *graph) push(v float64) {
	g.data = append(g.data, v)
	if len(g.data) > g.width {
		g.data = g.data[len(g.data)-g.width:]
	}
}

func (g *graph) resize(w, h int) { g.width, g.height = w, h }

func (g *graph) view() string {
	if len(g.data) == 0 {
		return g.renderEmpty()
	}
	maxV := 0.0
	for _, v := range g.data {
		if v > maxV { maxV = v }
	}
	if maxV <= 0 { maxV = 1 }
	scale := maxV * 1.12

	totalEighths := g.height * 8
	offset := g.width - len(g.data)
	peakCol := -1
	peakVal := 0.0
	for i, v := range g.data {
		if v > peakVal { peakVal = v; peakCol = i }
	}

	gridRows := map[int]bool{}
	for _, pct := range []float64{0.25, 0.5, 0.75} {
		gridRows[int(float64(g.height-1)*(1-pct))] = true
	}
	peakRow := g.height - 1 - int(float64(g.height)*clampF(peakVal/scale, 0, 1))

	bottomC, _ := colorful.Hex(string(g.bottom))
	topC, _ := colorful.Hex(string(g.top))

	var sb strings.Builder
	for row := 0; row < g.height; row++ {
		rowBase := (g.height - 1 - row) * 8
		t := easeOutQuad(float64(g.height-row) / float64(g.height))
		rowColor := lerpColor(bottomC, topC, t).Clamped().Hex()

		for col := 0; col < g.width; col++ {
			dataIdx := col - offset
			if dataIdx < 0 || dataIdx >= len(g.data) {
				if row == peakRow && col > offset {
					if col%2 == 0 {
						sb.WriteString(lipgloss.NewStyle().Foreground(g.top).Render("·"))
					} else {
						sb.WriteString(" ")
					}
				} else if gridRows[row] && col%3 == 0 {
					sb.WriteString(lipgloss.NewStyle().Foreground(dimColor(string(g.bottom), 0.3)).Render("·"))
				} else {
					sb.WriteString(" ")
				}
				continue
			}
			lv := g.data[dataIdx] / scale * float64(totalEighths)
			ageF := 0.58 + 0.42*float64(dataIdx)/math.Max(float64(len(g.data)-1), 1)

			if lv >= float64(rowBase+8) {
				if dataIdx == peakCol {
					sb.WriteString(lipgloss.NewStyle().Foreground(peakSpark(string(g.top))).Render("█"))
				} else {
					sb.WriteString(lipgloss.NewStyle().Foreground(dimColor(rowColor, ageF)).Render("█"))
				}
			} else if lv > float64(rowBase) {
				partial := int(lv) - rowBase
				if partial < 0 { partial = 0 }
				if partial > 8 { partial = 8 }
				brightened := brighten(rowColor, 0.35)
				sb.WriteString(lipgloss.NewStyle().Foreground(brightened).Render(string(barRamp[partial])))
			} else {
				if row == peakRow && col >= offset && col%2 == 0 {
					sb.WriteString(lipgloss.NewStyle().Foreground(dimColor(string(g.top), 0.4)).Render("·"))
				} else if gridRows[row] && col%3 == 0 {
					sb.WriteString(lipgloss.NewStyle().Foreground(dimColor(rowColor, 0.25)).Render("·"))
				} else {
					sb.WriteString(" ")
				}
			}
		}
		if row < g.height-1 { sb.WriteString("\n") }
	}
	return sb.String()
}

func (g *graph) renderEmpty() string {
	gridRows := map[int]bool{}
	for _, pct := range []float64{0.25, 0.5, 0.75} {
		gridRows[int(float64(g.height-1)*(1-pct))] = true
	}
	var sb strings.Builder
	for row := 0; row < g.height; row++ {
		for col := 0; col < g.width; col++ {
			if gridRows[row] && col%3 == 0 {
				sb.WriteString(lipgloss.NewStyle().Foreground(dimColor(string(g.bottom), 0.2)).Render("·"))
			} else {
				sb.WriteString(" ")
			}
		}
		if row < g.height-1 { sb.WriteString("\n") }
	}
	return sb.String()
}

// ── Card rendering ─────────────────────────────────────────────

func renderCard(t Theme, body string, width int, selected bool, accent lipgloss.Color, fill lipgloss.Color) string {
	borderColor := t.Border
	bg := t.AppBg
	if selected {
		borderColor = lipgloss.AdaptiveColor{}
		borderColor = lipgloss.AdaptiveColor{}
		bg = fill
	}
	style := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(borderColor).
		Background(bg).
		Padding(1, 2).
		Width(width)
	if selected {
		style = style.BorderForeground(accent)
	}
	return style.Render(body)
}

func renderPanel(t Theme, body string, width int) string {
	return lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(t.Border).
		Background(t.AppBg).
		Padding(0, 1).
		Width(width).
		Render(body)
}

// ── Title pills (ink-on-accent bold) ───────────────────────────

func titlePill(t Theme, text string, accent lipgloss.Color) string {
	return lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("#0a0e14")).
		Background(accent).
		Padding(0, 1).
		Render(text)
}

func keyPill(t Theme, key string, accent lipgloss.AdaptiveColor) string {
	return lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("#0a0e14")).
		Background(accent).
		Padding(0, 1).
		Render(key)
}

// ── Hint bar (inline style matching Riptide) ───────────────────

type hint struct {
	key  string
	desc string
}

func hintBar(t Theme, hints []hint) string {
	hl := lipgloss.NewStyle().Foreground(t.Success).Bold(true)
	mt := lipgloss.NewStyle().Foreground(t.Muted)
	var parts []string
	for i, h := range hints {
		if i > 0 {
			parts = append(parts, mt.Render("  ·  "))
		}
		parts = append(parts, hl.Render(h.key), mt.Render(" "+h.desc))
	}
	return lipgloss.NewStyle().Align(lipgloss.Center).Render(strings.Join(parts, ""))
}

// ── Progress bar ───────────────────────────────────────────────

func progressBar(done, total, width int, color lipgloss.AdaptiveColor) string {
	if total <= 0 { total = 1 }
	pct := clampF(float64(done)/float64(total), 0, 1)
	filled := int(pct * float64(width))
	if filled > width { filled = width }
	bar := lipgloss.NewStyle().Foreground(color).Render(strings.Repeat("█", filled)) +
		lipgloss.NewStyle().Foreground(lipgloss.AdaptiveColor{Dark: "#2a3b3a", Light: "#c7d4d0"}).Render(strings.Repeat("░", width-filled))
	return bar
}

// ── Logo (ANSI Shadow FIGlet + 4-stop gradient) ────────────────

var logoLines = []string{
	"██████╗ ██╗  ██╗ █████╗ ",
	"██╔══██╗██║ ██╔╝██╔══██╗",
	"██████╔╝█████╔╝ ███████║",
	"██╔═══╝ ██╔═██╗ ██╔══██║",
	"██║     ██║  ██╗██║  ██║",
	"╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝",
}

var logoStops = [4][3]uint8{
	{0x0e, 0x4d, 0x64},
	{0x08, 0x83, 0x95},
	{0x14, 0xc4, 0xd4},
	{0x9a, 0xf5, 0xf8},
}

func lerpU8(a, b uint8, t float64) uint8 {
	return uint8(float64(a) + (float64(b)-float64(a))*t + 0.5)
}

func logoGradientAt(t float64) (uint8, uint8, uint8) {
	if t < 0 {
		t = 0
	}
	if t > 1 {
		t = 1
	}
	segment := t * 3.0
	idx := int(segment)
	if idx >= 3 {
		idx = 2
		segment = 3.0
	}
	u := segment - float64(idx)
	a, b := logoStops[idx], logoStops[idx+1]
	return lerpU8(a[0], b[0], u), lerpU8(a[1], b[1], u), lerpU8(a[2], b[2], u)
}

func logoGradient(t Theme) string {
	n := len(logoLines)
	lines := make([]string, n)
	for i, line := range logoLines {
		rowT := 0.0
		if n > 1 {
			rowT = float64(i) / float64(n-1)
		}
		r, g, b := logoGradientAt(rowT)
		color := lipgloss.Color(fmt.Sprintf("#%02x%02x%02x", r, g, b))
		lines[i] = lipgloss.NewStyle().Foreground(color).Bold(true).Render(line)
	}
	logo := lipgloss.JoinVertical(lipgloss.Left, lines...)
	tag := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#94a3b8")).
		Render("archive console — Desktop → Google Drive")
	return lipgloss.JoinVertical(lipgloss.Center, logo, "", tag)
}

func compactHeader(t Theme) string {
	return lipgloss.NewStyle().
		Foreground(lipgloss.Color("#56d364")).
		Bold(true).
		Render("PKarchives  ·  archive console")
}

// ── Help overlay ───────────────────────────────────────────────

func helpOverlay(t Theme, w, h int) string {
	nav := []string{
		keyPill(t, "↑↓", t.Accent) + lipgloss.NewStyle().Foreground(t.Muted).Render(" navigate"),
		keyPill(t, "1-4", t.Accent) + lipgloss.NewStyle().Foreground(t.Muted).Render(" jump"),
		keyPill(t, "↵", t.Accent) + lipgloss.NewStyle().Foreground(t.Muted).Render(" select"),
		keyPill(t, "esc", t.Accent) + lipgloss.NewStyle().Foreground(t.Muted).Render(" back"),
	}
	ctrl := []string{
		keyPill(t, "t", t.Violet) + lipgloss.NewStyle().Foreground(t.Muted).Render(" compact mode"),
		keyPill(t, "o", t.Amber) + lipgloss.NewStyle().Foreground(t.Muted).Render(" open Drive"),
		keyPill(t, "?", t.Success) + lipgloss.NewStyle().Foreground(t.Muted).Render(" help"),
		keyPill(t, "q", t.Danger) + lipgloss.NewStyle().Foreground(t.Muted).Render(" quit"),
	}
	divider := lipgloss.NewStyle().Foreground(t.Border).Render(strings.Repeat("─", 40))
	body := strings.Join(nav, "\n") + "\n\n" + divider + "\n\n" + strings.Join(ctrl, "\n")
	return lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(t.SolidSuccess).
		Background(t.AppBg).
		Padding(1, 2).
		Width(44).
		Render(body)
}

// ── Format helpers ─────────────────────────────────────────────

func formatBytes(n int64) string {
	if n < 1024 { return fmt.Sprintf("%d B", n) }
	units := []string{"KB", "MB", "GB", "TB", "PB"}
	v := float64(n)
	i := 0
	for v >= 1024 && i < len(units)-1 { v /= 1024; i++ }
	return fmt.Sprintf("%.1f %s", v, units[i])
}

func formatSpeed(bytesPerSec float64) string {
	if bytesPerSec <= 0 { return "0 MB/s" }
	return formatBytes(int64(bytesPerSec)) + "/s"
}

func truncate(s string, n int) string {
	if len(s) <= n { return s }
	if n <= 3 { return s[:n] }
	return s[:n-3] + "..."
}

func clamp(v, min, max int) int {
	if v < min { return min }
	if v > max { return max }
	return v
}

func center(s string, w int) string {
	lines := strings.Split(s, "\n")
	for i, line := range lines {
		pad := (w - lipgloss.Width(line)) / 2
		if pad < 0 { pad = 0 }
		lines[i] = strings.Repeat(" ", pad) + line
	}
	return strings.Join(lines, "\n")
}

func hyperlink(url, text string) string {
	return fmt.Sprintf("\x1b]8;;%s\x1b\\%s\x1b]8;;\x1b\\", url, text)
}
