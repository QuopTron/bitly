package library

import (
	"path/filepath"
	"strings"
)

func scanCueFiles(files []libraryAudioFileInfo) error {
	var cueCount int
	for _, f := range files {
		if strings.EqualFold(filepath.Ext(f.path), ".cue") {
			cueCount++
		}
	}
	if cueCount > 0 {
		Log("[LibraryScan] Note: %d .cue files found. CUE sheet scanning not yet available in this build.\n", cueCount)
	}
	return nil
}
