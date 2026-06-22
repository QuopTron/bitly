package library

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

func collectLibraryAudioFiles(folderPath string, cancelCh <-chan struct{}) ([]libraryAudioFileInfo, error) {
	var files []libraryAudioFileInfo
	err := filepath.WalkDir(folderPath, func(path string, entry os.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		select {
		case <-cancelCh:
			return fmt.Errorf("scan cancelled")
		default:
		}
		if entry.IsDir() {
			return nil
		}
		ext := strings.ToLower(filepath.Ext(path))
		if !supportedAudioFormats[ext] {
			return nil
		}
		info, err := entry.Info()
		if err != nil {
			return nil
		}
		files = append(files, libraryAudioFileInfo{
			path:    path,
			modTime: info.ModTime().UnixMilli(),
		})
		return nil
	})
	return files, err
}
