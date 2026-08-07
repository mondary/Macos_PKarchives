package main

import (
	"strings"

	"github.com/charmbracelet/lipgloss"
)

type Theme struct {
	Name    string
	Display string
	Tagline string

	AppBg     lipgloss.Color
	Foreground lipgloss.AdaptiveColor
	Muted      lipgloss.AdaptiveColor
	Border     lipgloss.AdaptiveColor

	Accent  lipgloss.AdaptiveColor
	Amber   lipgloss.AdaptiveColor
	Violet  lipgloss.AdaptiveColor
	Success lipgloss.AdaptiveColor
	Danger  lipgloss.AdaptiveColor

	GraphBottom lipgloss.Color
	GraphTop    lipgloss.Color

	IdleFill      lipgloss.Color
	SelectArchive lipgloss.Color
	SelectHistory lipgloss.Color
	SelectSettings lipgloss.Color
	SelectExit     lipgloss.Color

	SolidAccent  lipgloss.Color
	SolidAmber   lipgloss.Color
	SolidViolet  lipgloss.Color
	SolidSuccess lipgloss.Color
	SolidDanger  lipgloss.Color
}

var themes = []Theme{
	{
		Name: "ocean", Display: "Ocean", Tagline: "Teal & amber on deep charcoal",
		AppBg: "#0e1419",
		Foreground: lipgloss.AdaptiveColor{Dark: "#e8f0ed", Light: "#182220"},
		Muted:      lipgloss.AdaptiveColor{Dark: "#7d8b89", Light: "#536260"},
		Border:     lipgloss.AdaptiveColor{Dark: "#2a3b3a", Light: "#c7d4d0"},
		Accent:     lipgloss.AdaptiveColor{Dark: "#39d0d8", Light: "#087f73"},
		Amber:      lipgloss.AdaptiveColor{Dark: "#f2bd62", Light: "#a05b00"},
		Violet:     lipgloss.AdaptiveColor{Dark: "#a371f7", Light: "#0969da"},
		Success:    lipgloss.AdaptiveColor{Dark: "#7ee787", Light: "#1a7f37"},
		Danger:     lipgloss.AdaptiveColor{Dark: "#ef8278", Light: "#a52f2b"},
		GraphBottom: "#0b5563", GraphTop: "#56e1e8",
		IdleFill: "#161d22",
		SelectArchive: lipgloss.Color("#1a2e34"), SelectHistory: lipgloss.Color("#2e2418"),
		SelectSettings: lipgloss.Color("#241a2e"), SelectExit: lipgloss.Color("#1a2a1e"),
		SolidAccent: "#39d0d8", SolidAmber: "#f2bd62", SolidViolet: "#a371f7",
		SolidSuccess: "#7ee787", SolidDanger: "#ef8278",
	},
	{
		Name: "midnight", Display: "Midnight", Tagline: "Electric blue & violet night",
		AppBg: "#0a0e27",
		Foreground: lipgloss.AdaptiveColor{Dark: "#e3e6ff", Light: "#1a1a2e"},
		Muted:      lipgloss.AdaptiveColor{Dark: "#6b7faa", Light: "#555580"},
		Border:     lipgloss.AdaptiveColor{Dark: "#1e2a4a", Light: "#b0bbe0"},
		Accent:     lipgloss.AdaptiveColor{Dark: "#5b8def", Light: "#1565d8"},
		Amber:      lipgloss.AdaptiveColor{Dark: "#c792ea", Light: "#7b3fa3"},
		Violet:     lipgloss.AdaptiveColor{Dark: "#7e57c2", Light: "#4527a0"},
		Success:    lipgloss.AdaptiveColor{Dark: "#c3e88d", Light: "#558b2f"},
		Danger:     lipgloss.AdaptiveColor{Dark: "#ff5370", Light: "#c62828"},
		GraphBottom: "#1a2a5a", GraphTop: "#82aaff",
		IdleFill: "#11173a",
		SelectArchive: lipgloss.Color("#16203a"), SelectHistory: lipgloss.Color("#241a35"),
		SelectSettings: lipgloss.Color("#1e1635"), SelectExit: lipgloss.Color("#152a1e"),
		SolidAccent: "#5b8def", SolidAmber: "#c792ea", SolidViolet: "#7e57c2",
		SolidSuccess: "#c3e88d", SolidDanger: "#ff5370",
	},
	{
		Name: "sunset", Display: "Sunset", Tagline: "Coral dusk & warm gold",
		AppBg: "#1a0e14",
		Foreground: lipgloss.AdaptiveColor{Dark: "#fce8df", Light: "#2a1018"},
		Muted:      lipgloss.AdaptiveColor{Dark: "#a07060", Light: "#80504a"},
		Border:     lipgloss.AdaptiveColor{Dark: "#3a1e2a", Light: "#e0c0b0"},
		Accent:     lipgloss.AdaptiveColor{Dark: "#ff6b6b", Light: "#d63340"},
		Amber:      lipgloss.AdaptiveColor{Dark: "#ffc15e", Light: "#b8740a"},
		Violet:     lipgloss.AdaptiveColor{Dark: "#e0407b", Light: "#ad1457"},
		Success:    lipgloss.AdaptiveColor{Dark: "#7ee787", Light: "#1a7f37"},
		Danger:     lipgloss.AdaptiveColor{Dark: "#ef6b6b", Light: "#c62828"},
		GraphBottom: "#4a1020", GraphTop: "#ff9a6b",
		IdleFill: "#211418",
		SelectArchive: lipgloss.Color("#2a1218"), SelectHistory: lipgloss.Color("#2a2014"),
		SelectSettings: lipgloss.Color("#2a1424"), SelectExit: lipgloss.Color("#1a2a18"),
		SolidAccent: "#ff6b6b", SolidAmber: "#ffc15e", SolidViolet: "#e0407b",
		SolidSuccess: "#7ee787", SolidDanger: "#ef6b6b",
	},
	{
		Name: "forest", Display: "Forest", Tagline: "Moss & gold canopy",
		AppBg: "#0f1a0f",
		Foreground: lipgloss.AdaptiveColor{Dark: "#d8f0d0", Light: "#1a2a1a"},
		Muted:      lipgloss.AdaptiveColor{Dark: "#6a8a60", Light: "#507048"},
		Border:     lipgloss.AdaptiveColor{Dark: "#1e3a1e", Light: "#b0d0a8"},
		Accent:     lipgloss.AdaptiveColor{Dark: "#56d364", Light: "#2e7d32"},
		Amber:      lipgloss.AdaptiveColor{Dark: "#daaa3f", Light: "#8b6914"},
		Violet:     lipgloss.AdaptiveColor{Dark: "#82aaff", Light: "#1565c0"},
		Success:    lipgloss.AdaptiveColor{Dark: "#7ee787", Light: "#1a7f37"},
		Danger:     lipgloss.AdaptiveColor{Dark: "#ff6b6b", Light: "#c62828"},
		GraphBottom: "#143a18", GraphTop: "#7ee87e",
		IdleFill: "#152215",
		SelectArchive: lipgloss.Color("#162a16"), SelectHistory: lipgloss.Color("#2a2414"),
		SelectSettings: lipgloss.Color("#161a2a"), SelectExit: lipgloss.Color("#162a18"),
		SolidAccent: "#56d364", SolidAmber: "#daaa3f", SolidViolet: "#82aaff",
		SolidSuccess: "#7ee787", SolidDanger: "#ff6b6b",
	},
	{
		Name: "nord", Display: "Nord", Tagline: "Frost & polar aurora",
		AppBg: "#2e3440",
		Foreground: lipgloss.AdaptiveColor{Dark: "#eceff4", Light: "#2e3440"},
		Muted:      lipgloss.AdaptiveColor{Dark: "#7b8a9e", Light: "#54667a"},
		Border:     lipgloss.AdaptiveColor{Dark: "#434c5e", Light: "#bcc4d4"},
		Accent:     lipgloss.AdaptiveColor{Dark: "#88c0d0", Light: "#2e6c80"},
		Amber:      lipgloss.AdaptiveColor{Dark: "#ebcb8b", Light: "#8a6d20"},
		Violet:     lipgloss.AdaptiveColor{Dark: "#b48ead", Light: "#6b3a70"},
		Success:    lipgloss.AdaptiveColor{Dark: "#a3be8c", Light: "#4a6b34"},
		Danger:     lipgloss.AdaptiveColor{Dark: "#bf616a", Light: "#a32a30"},
		GraphBottom: "#3b4252", GraphTop: "#88c0d0",
		IdleFill: "#353c4a",
		SelectArchive: lipgloss.Color("#2a3440"), SelectHistory: lipgloss.Color("#3a3530"),
		SelectSettings: lipgloss.Color("#353040"), SelectExit: lipgloss.Color("#2e3a35"),
		SolidAccent: "#88c0d0", SolidAmber: "#ebcb8b", SolidViolet: "#b48ead",
		SolidSuccess: "#a3be8c", SolidDanger: "#bf616a",
	},
	{
		Name: "dracula", Display: "Dracula", Tagline: "Purple night & neon pink",
		AppBg: "#282a36",
		Foreground: lipgloss.AdaptiveColor{Dark: "#f8f8f2", Light: "#282a36"},
		Muted:      lipgloss.AdaptiveColor{Dark: "#8890aa", Light: "#5a607a"},
		Border:     lipgloss.AdaptiveColor{Dark: "#44475a", Light: "#c0c4d4"},
		Accent:     lipgloss.AdaptiveColor{Dark: "#8be9fd", Light: "#0d6e80"},
		Amber:      lipgloss.AdaptiveColor{Dark: "#f1fa8c", Light: "#8a8a20"},
		Violet:     lipgloss.AdaptiveColor{Dark: "#bd93f9", Light: "#5e3ab5"},
		Success:    lipgloss.AdaptiveColor{Dark: "#50fa7b", Light: "#1a8c38"},
		Danger:     lipgloss.AdaptiveColor{Dark: "#ff5555", Light: "#c62828"},
		GraphBottom: "#343746", GraphTop: "#8be9fd",
		IdleFill: "#2e3140",
		SelectArchive: lipgloss.Color("#2a3040"), SelectHistory: lipgloss.Color("#36303a"),
		SelectSettings: lipgloss.Color("#322a40"), SelectExit: lipgloss.Color("#2a3530"),
		SolidAccent: "#8be9fd", SolidAmber: "#f1fa8c", SolidViolet: "#bd93f9",
		SolidSuccess: "#50fa7b", SolidDanger: "#ff5555",
	},
	{
		Name: "cyber", Display: "Cyber", Tagline: "Neon green & hot magenta",
		AppBg: "#0a0a0f",
		Foreground: lipgloss.AdaptiveColor{Dark: "#e0ffe0", Light: "#0a1a0a"},
		Muted:      lipgloss.AdaptiveColor{Dark: "#4a8a6a", Light: "#3a6050"},
		Border:     lipgloss.AdaptiveColor{Dark: "#1a2a1a", Light: "#a0d0a0"},
		Accent:     lipgloss.AdaptiveColor{Dark: "#00ff9f", Light: "#00805a"},
		Amber:      lipgloss.AdaptiveColor{Dark: "#ff00ff", Light: "#aa00aa"},
		Violet:     lipgloss.AdaptiveColor{Dark: "#7700ff", Light: "#5500aa"},
		Success:    lipgloss.AdaptiveColor{Dark: "#00ff00", Light: "#008000"},
		Danger:     lipgloss.AdaptiveColor{Dark: "#ff0040", Light: "#cc0030"},
		GraphBottom: "#0a3a1a", GraphTop: "#00ff9f",
		IdleFill: "#101018",
		SelectArchive: lipgloss.Color("#0a1a12"), SelectHistory: lipgloss.Color("#1a0a1a"),
		SelectSettings: lipgloss.Color("#120a1a"), SelectExit: lipgloss.Color("#0a1a0e"),
		SolidAccent: "#00ff9f", SolidAmber: "#ff00ff", SolidViolet: "#7700ff",
		SolidSuccess: "#00ff00", SolidDanger: "#ff0040",
	},
	{
		Name: "ember", Display: "Ember", Tagline: "Charcoal fire & molten gold",
		AppBg: "#1a0f0a",
		Foreground: lipgloss.AdaptiveColor{Dark: "#ffe8d8", Light: "#2a1208"},
		Muted:      lipgloss.AdaptiveColor{Dark: "#9a7050", Light: "#704830"},
		Border:     lipgloss.AdaptiveColor{Dark: "#3a1e14", Light: "#e0bca0"},
		Accent:     lipgloss.AdaptiveColor{Dark: "#ff8c42", Light: "#c8500a"},
		Amber:      lipgloss.AdaptiveColor{Dark: "#ffc15e", Light: "#b8740a"},
		Violet:     lipgloss.AdaptiveColor{Dark: "#c44e2a", Light: "#8b2a10"},
		Success:    lipgloss.AdaptiveColor{Dark: "#b5e853", Light: "#4a7010"},
		Danger:     lipgloss.AdaptiveColor{Dark: "#ef6b6b", Light: "#c62828"},
		GraphBottom: "#3a1408", GraphTop: "#ff8c42",
		IdleFill: "#211410",
		SelectArchive: lipgloss.Color("#2a1410"), SelectHistory: lipgloss.Color("#2a2014"),
		SelectSettings: lipgloss.Color("#2a1810"), SelectExit: lipgloss.Color("#1a2a14"),
		SolidAccent: "#ff8c42", SolidAmber: "#ffc15e", SolidViolet: "#c44e2a",
		SolidSuccess: "#b5e853", SolidDanger: "#ef6b6b",
	},
	{
		Name: "gruvbox", Display: "Gruvbox", Tagline: "Warm retro earth tones",
		AppBg: "#1d2021",
		Foreground: lipgloss.AdaptiveColor{Dark: "#ebdbb2", Light: "#3c3836"},
		Muted:      lipgloss.AdaptiveColor{Dark: "#928374", Light: "#6a6155"},
		Border:     lipgloss.AdaptiveColor{Dark: "#3c3836", Light: "#c8b89a"},
		Accent:     lipgloss.AdaptiveColor{Dark: "#83a598", Light: "#3a6a5a"},
		Amber:      lipgloss.AdaptiveColor{Dark: "#fabd2f", Light: "#9a7010"},
		Violet:     lipgloss.AdaptiveColor{Dark: "#d3869b", Light: "#8a3a60"},
		Success:    lipgloss.AdaptiveColor{Dark: "#b8bb26", Light: "#5a6a10"},
		Danger:     lipgloss.AdaptiveColor{Dark: "#fb4934", Light: "#c62828"},
		GraphBottom: "#2e3030", GraphTop: "#83a598",
		IdleFill: "#232627",
		SelectArchive: lipgloss.Color("#252828"), SelectHistory: lipgloss.Color("#2e2a20"),
		SelectSettings: lipgloss.Color("#282228"), SelectExit: lipgloss.Color("#252a20"),
		SolidAccent: "#83a598", SolidAmber: "#fabd2f", SolidViolet: "#d3869b",
		SolidSuccess: "#b8bb26", SolidDanger: "#fb4934",
	},
	{
		Name: "catppuccin", Display: "Catppuccin", Tagline: "Soft pastel mocha",
		AppBg: "#1e1e2e",
		Foreground: lipgloss.AdaptiveColor{Dark: "#cdd6f4", Light: "#1e1e2e"},
		Muted:      lipgloss.AdaptiveColor{Dark: "#7f849c", Light: "#565a7a"},
		Border:     lipgloss.AdaptiveColor{Dark: "#313244", Light: "#c0c5e0"},
		Accent:     lipgloss.AdaptiveColor{Dark: "#89dceb", Light: "#1a8090"},
		Amber:      lipgloss.AdaptiveColor{Dark: "#f9e2af", Light: "#8a7220"},
		Violet:     lipgloss.AdaptiveColor{Dark: "#cba6f7", Light: "#6a3ab0"},
		Success:    lipgloss.AdaptiveColor{Dark: "#a6e3a1", Light: "#3a7030"},
		Danger:     lipgloss.AdaptiveColor{Dark: "#f38ba8", Light: "#c62858"},
		GraphBottom: "#2a2a40", GraphTop: "#89dceb",
		IdleFill: "#252535",
		SelectArchive: lipgloss.Color("#26263a"), SelectHistory: lipgloss.Color("#33300a28"),
		SelectSettings: lipgloss.Color("#2a2540"), SelectExit: lipgloss.Color("#262a30"),
		SolidAccent: "#89dceb", SolidAmber: "#f9e2af", SolidViolet: "#cba6f7",
		SolidSuccess: "#a6e3a1", SolidDanger: "#f38ba8",
	},
}

func getTheme(name string) Theme {
	for _, t := range themes {
		if strings.EqualFold(t.Name, name) {
			return t
		}
	}
	return themes[0]
}

func themeNames() []string {
	names := make([]string, len(themes))
	for i, t := range themes {
		names[i] = t.Name
	}
	return names
}

func paintScreen(t Theme, w, h int, content string) string {
	return lipgloss.NewStyle().
		Width(w).
		Height(h).
		Background(t.AppBg).
		Align(lipgloss.Center, lipgloss.Center).
		Render(content)
}

func hexBg(t Theme) string { return string(t.AppBg) }
