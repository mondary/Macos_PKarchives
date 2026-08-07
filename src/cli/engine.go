package main

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"time"
)

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
	return err == nil && strings.Contains(string(out), "Bureau")
}

func scanDesktop(cfg Config, mode string) ([]fileItem, error) {
	entries, err := os.ReadDir(cfg.DesktopPath)
	if err != nil {
		return nil, err
	}
	var files, dirs []fileItem
	for _, e := range entries {
		name := e.Name()
		if strings.HasPrefix(name, ".") || name == cfg.LinkName {
			continue
		}
		path := filepath.Join(cfg.DesktopPath, name)
		if hasBureauTag(path) {
			continue
		}
		info, err := e.Info()
		if err != nil {
			continue
		}
		if e.IsDir() {
			if mode != "files" {
				dirs = append(dirs, fileItem{path, name, true, info.Size()})
			}
		} else {
			files = append(files, fileItem{path, name, false, info.Size()})
		}
	}
	sort.Slice(files, func(i, j int) bool { return files[i].Size < files[j].Size })
	return append(files, dirs...), nil
}

func rcloneUpload(ctx context.Context, cfg Config, path, destination string) error {
	return exec.CommandContext(ctx, rcloneBinary(), "copy", path, destination+"/",
		"--drive-root-folder-id", cfg.DriveFolderID,
		"--drive-chunk-size", "32M",
		"--buffer-size", "32M",
		"--drive-upload-cutoff", "32M",
		"--drive-pacer-min-sleep", "10ms",
		"--drive-pacer-burst", "200",
		"--quiet",
	).Run()
}

func itemBytes(path string) int64 {
	var total int64
	_ = filepath.Walk(path, func(_ string, info os.FileInfo, err error) error {
		if err == nil && info != nil && !info.IsDir() {
			total += info.Size()
		}
		return nil
	})
	return total
}

func walkDir(root string) ([]string, []string) {
	var paths, names []string
	_ = filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil || info == nil || info.IsDir() || strings.HasPrefix(info.Name(), ".") || hasBureauTag(path) {
			return nil
		}
		paths = append(paths, path)
		names = append(names, strings.TrimPrefix(path, root+string(os.PathSeparator)))
		return nil
	})
	return paths, names
}

func isMountActive(path string) bool {
	out, err := exec.Command("mount").Output()
	return err == nil && strings.Contains(string(out), " on "+path+" ")
}

func mountDrive(cfg Config) (string, error) {
	mount := filepath.Join(cfg.DesktopPath, cfg.LinkName)
	if isMountActive(mount) {
		return mount, nil
	}

	if info, err := os.Lstat(mount); err == nil {
		if info.Mode()&os.ModeSymlink != 0 {
			if err := os.Remove(mount); err != nil {
				return mount, err
			}
		} else if entries, err := os.ReadDir(mount); err != nil || len(entries) > 0 {
			return mount, &mountErr{cfg.LinkName + " already exists and is not empty"}
		}
	}
	if err := os.MkdirAll(mount, 0755); err != nil {
		return mount, err
	}

	logPath := filepath.Join(os.TempDir(), "pkarchives-mount.log")
	err := exec.Command(rcloneBinary(), "mount", archiveRemote(cfg), mount,
		"--drive-root-folder-id", cfg.DriveFolderID,
		"--daemon", "--daemon-wait", "10s",
		"--vfs-cache-mode", "minimal", "--volname", "PKarchives",
		"--log-file", logPath, "--log-level", "INFO",
	).Run()
	if err == nil {
		for i := 0; i < 10 && !isMountActive(mount); i++ {
			time.Sleep(500 * time.Millisecond)
		}
	}
	if isMountActive(mount) {
		return mount, nil
	}
	os.Remove(mount)
	log, _ := os.ReadFile(logPath)
	if strings.Contains(string(log), "installed via Homebrew") {
		return mount, &mountErr{"rclone Homebrew cannot mount on macOS; install official rclone from rclone.org/downloads"}
	}
	if err == nil {
		err = &mountErr{"rclone mount did not become active"}
	}
	return mount, err
}

type mountErr struct{ msg string }

func (e *mountErr) Error() string { return e.msg }

func modeName(items []fileItem) string {
	for _, item := range items {
		if item.IsDir {
			return "files + folders"
		}
	}
	return "files"
}
