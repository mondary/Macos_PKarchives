package main

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type settingsFocus int

const (
	focusSearch settingsFocus = iota
	focusConfig
	focusThemes
)

type settingsModel struct {
	theme    Theme
	compact  bool
	width    int
	height   int
	cfg      Config

	search    textinput.Model
	focus     settingsFocus
	inputs    []textinput.Model
	inputFocus int

	themeIdx     int
	filteredThemes []int

	flash    string
	flashOK  bool
}

func newSettings(t Theme, compact bool, w, h int, cfg Config) settingsModel {
	si := textinput.New()
	si.Placeholder = "Search settings or themes…"
	si.Prompt = "› "
	si.PromptStyle = lipgloss.NewStyle().Foreground(t.Accent).Bold(true)
	si.TextStyle = lipgloss.NewStyle().Foreground(t.Foreground)
	si.CharLimit = 40

	labels := []struct{ placeholder, value string }{
		{"Drive Folder ID", cfg.DriveFolderID},
		{"Desktop path", cfg.DesktopPath},
		{"rclone remote", cfg.RcloneRemote},
		{"Desktop link name", cfg.LinkName},
	}
	inputs := make([]textinput.Model, len(labels))
	for i, l := range labels {
		inputs[i] = textinput.New()
		inputs[i].Placeholder = l.placeholder
		inputs[i].SetValue(l.value)
		inputs[i].CharLimit = 80
	}

	s := settingsModel{
		theme:   t,
		compact: compact,
		width:   w,
		height:  h,
		cfg:     cfg,
		search:  si,
		inputs:  inputs,
	}
	s.refilter()
	return s
}

func (s *settingsModel) refilter() {
	s.filteredThemes = nil
	q := strings.ToLower(s.search.Value())
	for i, t := range themes {
		if q == "" || strings.Contains(strings.ToLower(t.Name), q) || strings.Contains(strings.ToLower(t.Display), q) || strings.Contains(strings.ToLower(t.Tagline), q) {
			s.filteredThemes = append(s.filteredThemes, i)
		}
	}
	if len(s.filteredThemes) > 0 {
		found := false
		for _, idx := range s.filteredThemes {
			if idx == s.themeIdx {
				found = true
				break
			}
		}
		if !found {
			s.themeIdx = s.filteredThemes[0]
		}
	}
}

func (s settingsModel) showConfig() bool {
	q := strings.ToLower(s.search.Value())
	return q == "" || strings.Contains("config path drive folder remote link", q)
}

func (s settingsModel) showThemes() bool {
	q := strings.ToLower(s.search.Value())
	return q == "" || strings.Contains("theme color palette style skin", q) || strings.Contains("theme", q)
}

func (s settingsModel) init() tea.Cmd { return textinput.Blink }

func (s *settingsModel) update(msg tea.Msg) (settingsModel, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		key := msg.String()
		if s.focus == focusSearch {
			if key == "enter" {
				if len(s.filteredThemes) > 0 && s.showThemes() && !s.showConfig() {
					s.themeIdx = s.filteredThemes[0]
					return *s, themeChangeCmd(themes[s.themeIdx].Name)
				}
				s.focus = focusConfig
				s.inputs[0].Focus()
				return *s, textinput.Blink
			}
			if key == "tab" || key == "down" {
				s.focus = focusConfig
				s.inputs[0].Focus()
				return *s, textinput.Blink
			}
			if key == "esc" {
				s.search.SetValue("")
				s.refilter()
				return *s, nil
			}
			var cmd tea.Cmd
			s.search, cmd = s.search.Update(msg)
			s.refilter()
			return *s, cmd
		}

		if s.focus == focusConfig {
			if key == "tab" || key == "down" {
				s.inputs[s.inputFocus].Blur()
				s.inputFocus = (s.inputFocus + 1) % len(s.inputs)
				s.inputs[s.inputFocus].Focus()
				return *s, textinput.Blink
			}
			if key == "shift+tab" || key == "up" {
				s.inputs[s.inputFocus].Blur()
				s.inputFocus = (s.inputFocus + len(s.inputs) - 1) % len(s.inputs)
				s.inputs[s.inputFocus].Focus()
				return *s, textinput.Blink
			}
			if key == "enter" {
				return s.saveSettings()
			}
			if key == "esc" {
				for i := range s.inputs {
					s.inputs[i].Blur()
				}
				s.focus = focusSearch
				s.search.Focus()
				return *s, textinput.Blink
			}
			var cmd tea.Cmd
			s.inputs[s.inputFocus], cmd = s.inputs[s.inputFocus].Update(msg)
			return *s, cmd
		}
	}
	return *s, nil
}

func (s *settingsModel) navigateThemes(delta int) {
	if len(s.filteredThemes) == 0 {
		return
	}
	currentPos := -1
	for i, idx := range s.filteredThemes {
		if idx == s.themeIdx {
			currentPos = i
			break
		}
	}
	if currentPos == -1 {
		s.themeIdx = s.filteredThemes[0]
		return
	}
	newPos := (currentPos + delta + len(s.filteredThemes)) % len(s.filteredThemes)
	s.themeIdx = s.filteredThemes[newPos]
}

func (s settingsModel) saveSettings() (settingsModel, tea.Cmd) {
	s.cfg.DriveFolderID = s.inputs[0].Value()
	s.cfg.DesktopPath = s.inputs[1].Value()
	s.cfg.RcloneRemote = s.inputs[2].Value()
	s.cfg.LinkName = s.inputs[3].Value()
	if s.cfg.LinkName == "" {
		s.cfg.LinkName = "DesktopArchive"
	}
	if err := saveConfig(s.cfg); err != nil {
		s.flash = err.Error()
		s.flashOK = false
	} else {
		s.flash = "Settings saved"
		s.flashOK = true
	}
	for i := range s.inputs {
		s.inputs[i].Blur()
	}
	return s, nil
}

type themeChangedMsg struct{ name string }

func themeChangeCmd(name string) tea.Cmd {
	return func() tea.Msg { return themeChangedMsg{name} }
}

func (s settingsModel) view() string {
	t := s.theme
	header := compactHeader(t)

	title := titlePill(t, "SETTINGS", t.SolidSuccess)

	searchLine := s.search.View()

	var sections []string
	sections = append(sections, header, "", title, "", searchLine)

	if s.showConfig() {
		sections = append(sections, "", s.renderConfigSection())
	}

	if s.showThemes() {
		sections = append(sections, "", s.renderThemeSection())
	}

	if s.flash != "" {
		flashColor := t.Danger
		if s.flashOK {
			flashColor = t.Success
		}
		sections = append(sections, "",
			lipgloss.NewStyle().Foreground(flashColor).Bold(true).Align(lipgloss.Center).Width(clamp(s.width-4, 40, 80)).Render(s.flash))
	}

	hints := hintBar(t, []hint{
		{"tab", "next field"},
		{"↵", "save / apply"},
		{"esc", "back"},
		{"q", "quit"},
	})
	sections = append(sections, "", hints)

	stack := lipgloss.JoinVertical(lipgloss.Center, sections...)
	return paintScreen(t, s.width, s.height, stack)
}

func (s settingsModel) renderConfigSection() string {
	t := s.theme
	labels := []string{"Drive Folder ID", "Desktop path", "rclone remote", "Desktop link name"}
	var lines []string
	lines = append(lines, lipgloss.NewStyle().Foreground(t.Muted).Bold(true).Render("Configuration"))
	for i, input := range s.inputs {
		marker := "  "
		if i == s.inputFocus && s.focus == focusConfig {
			marker = lipgloss.NewStyle().Foreground(t.Accent).Bold(true).Render("› ")
		}
		label := lipgloss.NewStyle().Foreground(t.Foreground).Render(labels[i])
		inputCard := renderPanel(t, input.View(), clamp(s.width-12, 36, 68))
		lines = append(lines, marker+label, inputCard)
	}
	return strings.Join(lines, "\n")
}

func (s settingsModel) renderThemeSection() string {
	t := s.theme
	var lines []string
	lines = append(lines, lipgloss.NewStyle().Foreground(t.Muted).Bold(true).Render(
		fmt.Sprintf("Themes  (%d)", len(themes))))

	maxShow := clamp((s.height-20)/3, 3, 8)
	start := 0
	themePos := 0
	for i, idx := range s.filteredThemes {
		if idx == s.themeIdx {
			themePos = i
			break
		}
	}
	if themePos > maxShow-1 {
		start = themePos - maxShow + 2
	}
	if start < 0 {
		start = 0
	}
	end := start + maxShow
	if end > len(s.filteredThemes) {
		end = len(s.filteredThemes)
	}

	if start > 0 {
		lines = append(lines, lipgloss.NewStyle().Foreground(t.Muted).Render(fmt.Sprintf("↑ %d more", start)))
	}

	for i := start; i < end; i++ {
		idx := s.filteredThemes[i]
		th := themes[idx]
		isSelected := idx == s.themeIdx
		isActive := th.Name == t.Name

		marker := "  "
		if isSelected {
			marker = lipgloss.NewStyle().Foreground(t.Accent).Bold(true).Render("› ")
		}

		name := lipgloss.NewStyle().Foreground(t.Foreground).Bold(isSelected).Render(th.Display)
		tagline := lipgloss.NewStyle().Foreground(t.Muted).Render("  " + th.Tagline)

		dots := lipgloss.NewStyle().Foreground(th.SolidAccent).Render("●") +
			lipgloss.NewStyle().Foreground(th.SolidAmber).Render(" ●") +
			lipgloss.NewStyle().Foreground(th.SolidViolet).Render(" ●") +
			lipgloss.NewStyle().Foreground(th.SolidSuccess).Render(" ●")

		active := ""
		if isActive {
			active = lipgloss.NewStyle().Foreground(t.Success).Bold(true).Render("  ✓ active")
		}

		line := marker + name + tagline + "  " + dots + active
		lines = append(lines, line)
	}

	if end < len(s.filteredThemes) {
		lines = append(lines, lipgloss.NewStyle().Foreground(t.Muted).Render(fmt.Sprintf("↓ %d more", len(s.filteredThemes)-end)))
	}

	lines = append(lines, "",
		lipgloss.NewStyle().Foreground(t.Muted).Render("↵ apply theme  ↑↓ browse"))

	return strings.Join(lines, "\n")
}
