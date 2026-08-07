package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/charmbracelet/lipgloss"
)

type historyEntry struct {
	Date    time.Time `json:"date"`
	Mode    string    `json:"mode"`
	Items   int       `json:"items"`
	Success int       `json:"success"`
	Bytes   int64     `json:"bytes_freed"`
	MountOK bool      `json:"mount_ok"`
}

func historyPath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config", "pkarchives", "history.json")
}

func loadHistory() []historyEntry {
	data, err := os.ReadFile(historyPath())
	if err != nil {
		return nil
	}
	var entries []historyEntry
	if json.Unmarshal(data, &entries) != nil {
		return nil
	}
	return entries
}

func saveHistory(entries []historyEntry) error {
	path := historyPath()
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return err
	}
	data, err := json.MarshalIndent(entries, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, append(data, '\n'), 0600)
}

// ── History view rendering ─────────────────────────────────────

func historyView(t Theme, w, h int, histories []historyEntry) string {
	header := logoGradient(t) + "\n\n" +
		titlePill(t, "ARCHIVE HISTORY", t.SolidViolet) + "\n\n"

	if len(histories) == 0 {
		empty := lipgloss.NewStyle().Foreground(t.Muted).Render("No archive runs recorded yet.") + "\n" +
			lipgloss.NewStyle().Foreground(t.Muted).Render("History is stored in ~/.config/pkarchives/history.json")
		body := renderCard(t, empty, clamp(w-8, 44, 80), false, t.SolidViolet, t.AppBg)
		hints := hintBar(t, []hint{{"esc", "back"}, {"q", "quit"}})
		stack := lipgloss.JoinVertical(lipgloss.Center, header, body, "", hints)
		return paintScreen(t, w, h, stack)
	}

	limit := 10
	if len(histories) < limit {
		limit = len(histories)
	}
	shown := histories[:limit]

	var rows []string
	for _, entry := range shown {
		status := lipgloss.NewStyle().Foreground(t.Success).Bold(true).Render("✓ OK")
		if !entry.MountOK {
			status = lipgloss.NewStyle().Foreground(t.Amber).Bold(true).Render("⚠ MOUNT")
		}
		date := entry.Date.Local().Format("02 Jan 15:04")
		freed := formatBytes(entry.Bytes)
		modeColor := t.Accent
		if strings.Contains(entry.Mode, "folders") {
			modeColor = t.Amber
		}
		modeStr := lipgloss.NewStyle().Foreground(modeColor).Render(entry.Mode)
		line := fmt.Sprintf("%s  %s  %s  %d/%d items  %s freed  %s",
			status,
			lipgloss.NewStyle().Foreground(t.Muted).Render(date),
			modeStr,
			entry.Success, entry.Items,
			lipgloss.NewStyle().Foreground(t.Accent).Bold(true).Render(freed),
			lipgloss.NewStyle().Foreground(t.Muted).Render(""),
		)
		rows = append(rows, line)
	}
	body := strings.Join(rows, "\n")
	cardBody := renderCard(t, body, clamp(w-8, 52, 88), false, t.SolidViolet, t.AppBg)

	chart := historyChart(t, shown, clamp(w-8, 52, 88))

	hints := hintBar(t, []hint{{"esc", "back"}, {"q", "quit"}})

	stack := lipgloss.JoinVertical(lipgloss.Center, header, cardBody, "", chart, "", hints)
	return paintScreen(t, w, h, stack)
}

func historyChart(t Theme, entries []historyEntry, width int) string {
	if len(entries) == 0 {
		return ""
	}
	maxBytes := int64(0)
	for _, e := range entries {
		if e.Bytes > maxBytes {
			maxBytes = e.Bytes
		}
	}
	if maxBytes <= 0 {
		maxBytes = 1
	}

	header := titlePill(t, "SPACE FREED — LAST 10 RUNS", t.SolidAccent)
	chartW := width - 6
	if chartW < 20 {
		chartW = 20
	}
	barAreaW := chartW - 24
	if barAreaW < 10 {
		barAreaW = 10
	}

	var lines []string
	reversed := make([]historyEntry, len(entries))
	for i, e := range entries {
		reversed[len(entries)-1-i] = e
	}

	for _, e := range reversed {
		pct := float64(e.Bytes) / float64(maxBytes)
		filled := int(pct * float64(barAreaW))
		if filled > barAreaW {
			filled = barAreaW
		}
		bar := lipgloss.NewStyle().Foreground(t.Accent).Render(strings.Repeat("█", filled)) +
			lipgloss.NewStyle().Foreground(lipgloss.AdaptiveColor{Dark: "#2a3b3a", Light: "#c7d4d0"}).Render(strings.Repeat("░", barAreaW-filled))
		date := e.Date.Local().Format("02 Jan")
		bytes := formatBytes(e.Bytes)
		line := fmt.Sprintf("%s  %s  %s",
			lipgloss.NewStyle().Foreground(t.Muted).Width(6).Render(date),
			bar,
			lipgloss.NewStyle().Foreground(t.Accent).Bold(true).Width(9).Align(lipgloss.Right).Render(bytes),
		)
		lines = append(lines, line)
	}

	body := strings.Join(lines, "\n")
	return renderPanel(t, header+"\n\n"+body, width)
}
