package main

import "testing"

func TestArchivePathForFilePreservesFolderHierarchy(t *testing.T) {
	base := "gdrive:2026_09_septembre"

	tests := []struct {
		name     string
		root     string
		relative string
		want     string
	}{
		{"file at folder root", "Administratif", "fiche.pdf", "gdrive:2026_09_septembre/Administratif"},
		{"nested file", "Administratif", "Paie/2026/fiche.pdf", "gdrive:2026_09_septembre/Administratif/Paie/2026"},
		{"folder with spaces", "Mes documents", "Sous dossier/notes.txt", "gdrive:2026_09_septembre/Mes documents/Sous dossier"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := archivePathForFile(base, tt.root, tt.relative); got != tt.want {
				t.Fatalf("archivePathForFile() = %q, want %q", got, tt.want)
			}
		})
	}
}
