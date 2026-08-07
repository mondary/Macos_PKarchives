package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type screenID int

const (
	screenMenu screenID = iota
	screenArchive
	screenHistory
	screenSettings
)

type menuSelectMsg struct {
	screen      screenID
	archiveMode string
}

type backToMenuMsg struct{}

type app struct {
	theme   Theme
	compact bool
	width   int
	height  int
	cfg     Config
	history []historyEntry

	screen      screenID
	archiveMode string

	menu     menuModel
	archive  archiveModel
	settings settingsModel

	showHelp bool
}

func loadThemeName() string {
	home, _ := os.UserHomeDir()
	data, err := os.ReadFile(filepath.Join(home, ".config", "pkarchives", "theme"))
	if err == nil && len(strings.TrimSpace(string(data))) > 0 {
		return strings.TrimSpace(string(data))
	}
	if env := os.Getenv("PKARCHIVES_THEME"); env != "" {
		return env
	}
	return "ocean"
}

func saveThemeName(name string) error {
	home, _ := os.UserHomeDir()
	path := filepath.Join(home, ".config", "pkarchives", "theme")
	_ = os.MkdirAll(filepath.Dir(path), 0700)
	return os.WriteFile(path, []byte(name), 0600)
}

func setTerminalColors(bgHex string) {
	fmt.Printf("\x1b]11;%s\a", bgHex)
	fmt.Printf("\x1b]10;%s\a", "#e8f0ed")
	lipgloss.SetHasDarkBackground(true)
}

func resetTerminalColors() {
	fmt.Print("\x1b]111\a\x1b]110\a")
}

func initialModel() app {
	themeName := loadThemeName()
	t := getTheme(themeName)
	cfg := loadConfig()
	hist := loadHistory()
	w, h := terminalSize()
	return app{
		theme:   t,
		compact: false,
		width:   w,
		height:  h,
		cfg:     cfg,
		history: hist,
		screen:  screenMenu,
		menu:    newMenu(t, false, w, h),
	}
}

func terminalSize() (int, int) {
	return 80, 24
}

func (a app) Init() tea.Cmd {
	return a.menu.init()
}

func (a app) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		a.width, a.height = msg.Width, msg.Height
		a.menu.width, a.menu.height = msg.Width, msg.Height
		a.menu.theme = a.theme
		a.menu.items = menuItems(a.theme)
		if a.screen == screenArchive {
			a.archive.width, a.archive.height = msg.Width, msg.Height
			gw := clamp(msg.Width-12, 30, 56)
			a.archive.graph.resize(gw, graphHeight)
		}
		if a.screen == screenSettings {
			a.settings.width, a.settings.height = msg.Width, msg.Height
		}
		return a, nil

	case tea.KeyMsg:
		key := msg.String()
		if key == "ctrl+c" {
			return a, tea.Quit
		}
		if key == "?" {
			a.showHelp = !a.showHelp
			return a, nil
		}
		if a.showHelp {
			if key == "esc" || key == "?" {
				a.showHelp = false
			}
			return a, nil
		}
		if key == "t" {
			a.compact = !a.compact
			a.menu.compact = a.compact
			return a, nil
		}

		switch a.screen {
		case screenMenu:
			return a.updateMenu(msg)
		case screenArchive:
			return a.updateArchive(msg)
		case screenHistory:
			if key == "esc" || key == "m" {
				a.screen = screenMenu
				return a, nil
			}
		case screenSettings:
			return a.updateSettings(msg)
		}

	case menuSelectMsg:
		return a.enterScreen(msg)

	case backToMenuMsg:
		a.screen = screenMenu
		a.menu = newMenu(a.theme, a.compact, a.width, a.height)
		return a, a.menu.init()

	case themeChangedMsg:
		a.theme = getTheme(msg.name)
		a.menu.theme = a.theme
		a.menu.items = menuItems(a.theme)
		a.archive.theme = a.theme
		a.archive.graph.bottom = a.theme.GraphBottom
		a.archive.graph.top = a.theme.GraphTop
		a.settings.theme = a.theme
		setTerminalColors(string(a.theme.AppBg))
		_ = saveThemeName(msg.name)
		return a, nil

	case spinner.TickMsg:
		_ = msg
		if a.screen == screenMenu {
			var cmd tea.Cmd
			a.menu, cmd = a.menu.update(msg)
			return a, cmd
		}
		if a.screen == screenArchive {
			var cmd tea.Cmd
			a.archive, cmd = a.archive.update(msg)
			return a, cmd
		}

	default:
		// Route engine messages (scanDoneMsg, itemDoneMsg, etc.) to active screen
		if a.screen == screenArchive {
			var cmd tea.Cmd
			a.archive, cmd = a.archive.update(msg)
			return a, cmd
		}
	}

	return a, nil
}

func (a app) updateMenu(msg tea.Msg) (tea.Model, tea.Cmd) {
	key := ""
	if k, ok := msg.(tea.KeyMsg); ok {
		key = k.String()
	}

	switch key {
	case "q", "esc":
		return a, tea.Quit
	case "1":
		return a, menuSelectCmd(screenArchive, "files")
	case "2":
		return a, menuSelectCmd(screenArchive, "all")
	case "3":
		return a, menuSelectCmd(screenHistory, "")
	case "4":
		return a, menuSelectCmd(screenSettings, "")
	case "o", "d":
		openURL(driveURL(a.cfg))
		return a, nil
	case "up", "k":
		a.menu.move(-1)
		return a, nil
	case "down", "j":
		a.menu.move(1)
		return a, nil
	case "left", "h":
		a.menu.move(-1)
		return a, nil
	case "right", "l":
		a.menu.move(1)
		return a, nil
	case "enter", " ":
		return a.menuSelectFromCursor()
	}

	var cmd tea.Cmd
	a.menu, cmd = a.menu.update(msg)
	return a, cmd
}

func (a app) menuSelectFromCursor() (tea.Model, tea.Cmd) {
	switch a.menu.cursor {
	case 0:
		return a, menuSelectCmd(screenArchive, "files")
	case 1:
		return a, menuSelectCmd(screenArchive, "all")
	case 2:
		return a, menuSelectCmd(screenHistory, "")
	case 3:
		return a, menuSelectCmd(screenSettings, "")
	}
	return a, nil
}

func menuSelectCmd(s screenID, mode string) tea.Cmd {
	return func() tea.Msg { return menuSelectMsg{s, mode} }
}

func (a app) enterScreen(msg menuSelectMsg) (tea.Model, tea.Cmd) {
	switch msg.screen {
	case screenArchive:
		a.archive = newArchive(a.theme, a.compact, a.width, a.height, a.cfg, a.history)
		a.screen = screenArchive
		cmd := a.archive.start(msg.archiveMode)
		return a, cmd
	case screenHistory:
		a.screen = screenHistory
		a.history = loadHistory()
		return a, nil
	case screenSettings:
		a.settings = newSettings(a.theme, a.compact, a.width, a.height, a.cfg)
		a.screen = screenSettings
		a.settings.search.Focus()
		return a, a.settings.init()
	}
	return a, nil
}

func (a app) updateArchive(msg tea.Msg) (tea.Model, tea.Cmd) {
	key := ""
	if k, ok := msg.(tea.KeyMsg); ok {
		key = k.String()
	}

	if key == "o" || key == "d" {
		openURL(driveURL(a.cfg))
		return a, nil
	}
	if key == "esc" {
		if a.archive.running {
			a.archive.cancel()
			return a, nil
		}
		if a.archive.phase == archiveDone || a.archive.phase == archiveFailed || a.archive.phase == archiveEmpty {
			a.screen = screenMenu
			a.menu = newMenu(a.theme, a.compact, a.width, a.height)
			return a, a.menu.init()
		}
		a.archive.cancel()
		return a, nil
	}
	if key == "q" {
		if a.archive.running {
			return a, nil
		}
		a.screen = screenMenu
		a.menu = newMenu(a.theme, a.compact, a.width, a.height)
		return a, a.menu.init()
	}

	var cmd tea.Cmd
	a.archive, cmd = a.archive.update(msg)
	return a, cmd
}

func (a app) updateSettings(msg tea.Msg) (tea.Model, tea.Cmd) {
	key := ""
	if k, ok := msg.(tea.KeyMsg); ok {
		key = k.String()
	}

	if key == "esc" {
		if a.settings.focus == focusSearch && a.settings.search.Value() == "" {
			a.screen = screenMenu
			a.cfg = a.settings.cfg
			a.menu = newMenu(a.theme, a.compact, a.width, a.height)
			return a, a.menu.init()
		}
	}
	if key == "q" && a.settings.focus == focusSearch {
		a.screen = screenMenu
		a.cfg = a.settings.cfg
		a.menu = newMenu(a.theme, a.compact, a.width, a.height)
		return a, a.menu.init()
	}

	var cmd tea.Cmd
	a.settings, cmd = a.settings.update(msg)
	a.cfg = a.settings.cfg
	return a, cmd
}

func (a app) View() string {
	if a.showHelp {
		base := a.viewCurrentScreen()
		overlay := helpOverlay(a.theme, a.width, a.height)
		return lipgloss.JoinVertical(lipgloss.Center, base, "", overlay)
	}
	return a.viewCurrentScreen()
}

func (a app) viewCurrentScreen() string {
	switch a.screen {
	case screenMenu:
		return a.menu.view()
	case screenArchive:
		return a.archive.view()
	case screenHistory:
		return historyView(a.theme, a.width, a.height, a.history)
	case screenSettings:
		return a.settings.view()
	}
	return ""
}

func main() {
	if len(os.Args) > 1 && os.Args[1] == "--render-test" {
		screen := "menu"
		if len(os.Args) > 2 {
			screen = os.Args[2]
		}
		t := getTheme(loadThemeName())
		cfg := loadConfig()
		hist := loadHistory()
		w, h := 110, 50
		switch screen {
		case "menu":
			m := newMenu(t, false, w, h)
			fmt.Println(m.view())
		case "archive":
			a := newArchive(t, false, w, h, cfg, hist)
			fmt.Println(a.view())
		case "history":
			fmt.Println(historyView(t, w, h, hist))
		case "settings":
			s := newSettings(t, false, w, h, cfg)
			fmt.Println(s.view())
		case "help":
			fmt.Println(helpOverlay(t, w, h))
		}
		return
	}

	themeName := loadThemeName()
	t := getTheme(themeName)
	setTerminalColors(string(t.AppBg))
	defer resetTerminalColors()

	p := tea.NewProgram(initialModel(),
		tea.WithAltScreen(),
		tea.WithMouseCellMotion(),
	)
	if _, err := p.Run(); err != nil {
		fmt.Fprintln(os.Stderr, "Error:", err)
		os.Exit(1)
	}
}
