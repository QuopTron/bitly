package filesystem

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// EnsureDir creates a directory if it doesn't exist.
func EnsureDir(path string) error {
	return os.MkdirAll(path, 0755)
}

// FileExists checks if a file exists and is not a directory.
func FileExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}

// DirExists checks if a directory exists.
func DirExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

// DeleteFile removes a file if it exists.
func DeleteFile(path string) error {
	if !FileExists(path) {
		return nil
	}
	return os.Remove(path)
}

// GetFileSize returns the size of a file in bytes.
func GetFileSize(path string) (int64, error) {
	info, err := os.Stat(path)
	if err != nil {
		return 0, err
	}
	return info.Size(), nil
}

// ListFiles returns all files in a directory with the given extension.
func ListFiles(dir string, extension string) ([]string, error) {
	var files []string
	err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() && strings.HasSuffix(strings.ToLower(info.Name()), strings.ToLower(extension)) {
			files = append(files, path)
		}
		return nil
	})
	return files, err
}

// SanitizePath ensures a path is safe (no directory traversal).
func SanitizePath(base, path string) (string, error) {
	clean := filepath.Clean(filepath.Join(base, path))
	if !strings.HasPrefix(clean, filepath.Clean(base)) {
		return "", fmt.Errorf("path traversal detected: %s", path)
	}
	return clean, nil
}

// FreeSpace returns the available disk space in bytes for the given path.
func FreeSpace(path string) (uint64, error) {
	return 0, fmt.Errorf("not implemented on this platform")
}
