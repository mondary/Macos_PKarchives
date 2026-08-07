package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

type Config struct {
	DriveFolderID string
	DesktopPath   string
	LinkName      string
	RcloneRemote  string
}

func defaultConfig() Config {
	home, _ := os.UserHomeDir()
	return Config{
		DesktopPath:  filepath.Join(home, "Desktop"),
		LinkName:     "DesktopArchive",
		RcloneRemote: "gdrive",
	}
}

func loadConfig() Config {
	home, _ := os.UserHomeDir()
	cfg := defaultConfig()
	for k, dst := range map[string]*string{
		"PKARCHIVES_DRIVE_FOLDER_ID":   &cfg.DriveFolderID,
		"PKARCHIVES_DESKTOP_PATH":      &cfg.DesktopPath,
		"PKARCHIVES_DESKTOP_LINK_NAME": &cfg.LinkName,
		"PKARCHIVES_RCLONE_REMOTE":     &cfg.RcloneRemote,
	} {
		if v := os.Getenv(k); v != "" {
			*dst = v
		}
	}
	for _, path := range []string{
		filepath.Join(home, ".pkarchives.conf"),
		filepath.Join(home, ".config", "pkarchives", "pkarchives.conf"),
	} {
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
	cfg.RcloneRemote = strings.TrimSuffix(cfg.RcloneRemote, ":")
	return cfg
}

func saveConfig(cfg Config) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	data := fmt.Sprintf(
		"PKARCHIVES_DRIVE_FOLDER_ID=\"%s\"\nPKARCHIVES_DESKTOP_PATH=\"%s\"\nPKARCHIVES_DESKTOP_LINK_NAME=\"%s\"\nPKARCHIVES_RCLONE_REMOTE=\"%s\"\n",
		cfg.DriveFolderID, cfg.DesktopPath, cfg.LinkName, cfg.RcloneRemote,
	)
	return os.WriteFile(filepath.Join(home, ".pkarchives.conf"), []byte(data), 0600)
}

func driveURL(cfg Config) string {
	if cfg.DriveFolderID == "" {
		return "https://drive.google.com"
	}
	return "https://drive.google.com/drive/folders/" + cfg.DriveFolderID
}

func archiveRemote(cfg Config) string { return strings.TrimSuffix(cfg.RcloneRemote, ":") + ":" }

func archiveMonth() string {
	months := []string{
		"janvier", "février", "mars", "avril", "mai", "juin",
		"juillet", "août", "septembre", "octobre", "novembre", "décembre",
	}
	now := time.Now()
	return fmt.Sprintf("%d_%02d_%s", now.Year(), int(now.Month()), months[int(now.Month())-1])
}

func archiveDestination(cfg Config) string {
	return archiveRemote(cfg) + archiveMonth()
}

func rcloneBinary() string {
	if configured := os.Getenv("PKARCHIVES_RCLONE_BINARY"); configured != "" {
		return configured
	}
	home, err := os.UserHomeDir()
	if err == nil {
		local := filepath.Join(home, ".local", "share", "pkarchives", "bin", "rclone")
		if info, err := os.Stat(local); err == nil && !info.IsDir() && info.Mode().Perm()&0111 != 0 {
			return local
		}
	}
	return "rclone"
}

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
