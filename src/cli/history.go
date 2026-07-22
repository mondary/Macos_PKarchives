package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"time"
)

// historyEntry is intentionally plain JSON so it can be inspected or backed up without a database.
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
