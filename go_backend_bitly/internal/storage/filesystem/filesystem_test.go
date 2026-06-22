package filesystem

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestEnsureDir(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "nested", "dir")
	err := EnsureDir(dir)
	if err != nil {
		t.Fatalf("EnsureDir failed: %v", err)
	}
	if info, err := os.Stat(dir); err != nil || !info.IsDir() {
		t.Error("expected directory to exist")
	}
}

func TestEnsureDir_Existing(t *testing.T) {
	dir := t.TempDir()
	err := EnsureDir(dir)
	if err != nil {
		t.Fatalf("EnsureDir on existing dir failed: %v", err)
	}
}

func TestFileExists(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "test.txt")
	os.WriteFile(path, []byte("hello"), 0644)

	if !FileExists(path) {
		t.Error("expected FileExists to be true")
	}
	if FileExists(filepath.Join(dir, "nonexistent.txt")) {
		t.Error("expected FileExists to be false for nonexistent file")
	}
	if FileExists(dir) {
		t.Error("expected FileExists to be false for a directory")
	}
}

func TestDirExists(t *testing.T) {
	dir := t.TempDir()

	if !DirExists(dir) {
		t.Error("expected DirExists to be true")
	}
	if DirExists(filepath.Join(dir, "nonexistent")) {
		t.Error("expected DirExists to be false for nonexistent dir")
	}
	filePath := filepath.Join(dir, "file.txt")
	os.WriteFile(filePath, []byte("hello"), 0644)
	if DirExists(filePath) {
		t.Error("expected DirExists to be false for a file")
	}
}

func TestDeleteFile(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "test.txt")
	os.WriteFile(path, []byte("hello"), 0644)

	err := DeleteFile(path)
	if err != nil {
		t.Fatalf("DeleteFile failed: %v", err)
	}
	if FileExists(path) {
		t.Error("expected file to be deleted")
	}
}

func TestDeleteFile_NotExists(t *testing.T) {
	err := DeleteFile("/nonexistent/file.txt")
	if err != nil {
		t.Fatalf("DeleteFile on nonexistent should return nil: %v", err)
	}
}

func TestGetFileSize(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "test.txt")
	content := []byte("hello world")
	os.WriteFile(path, content, 0644)

	size, err := GetFileSize(path)
	if err != nil {
		t.Fatalf("GetFileSize failed: %v", err)
	}
	if size != int64(len(content)) {
		t.Errorf("size = %d, want %d", size, len(content))
	}
}

func TestGetFileSize_NotExists(t *testing.T) {
	_, err := GetFileSize("/nonexistent/file.txt")
	if err == nil {
		t.Fatal("expected error for nonexistent file")
	}
}

func TestListFiles(t *testing.T) {
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, "a.mp3"), []byte("a"), 0644)
	os.WriteFile(filepath.Join(dir, "b.flac"), []byte("b"), 0644)
	os.WriteFile(filepath.Join(dir, "c.mp3"), []byte("c"), 0644)
	os.MkdirAll(filepath.Join(dir, "sub"), 0755)
	os.WriteFile(filepath.Join(dir, "sub", "d.mp3"), []byte("d"), 0644)

	// ListFiles walks recursively, so it finds all mp3 files including sub/d.mp3
	files, err := ListFiles(dir, ".mp3")
	if err != nil {
		t.Fatalf("ListFiles failed: %v", err)
	}
	// 3 mp3 files: a.mp3, c.mp3, and sub/d.mp3 (recursive)
	if len(files) != 3 {
		t.Errorf("expected 3 mp3 files (recursive), got %d: %v", len(files), files)
	}

	files, err = ListFiles(dir, ".flac")
	if err != nil {
		t.Fatalf("ListFiles failed: %v", err)
	}
	if len(files) != 1 {
		t.Errorf("expected 1 flac file, got %d", len(files))
	}
}

func TestSanitizePath(t *testing.T) {
	t.Run("normal path", func(t *testing.T) {
		base := filepath.Join("/", "music")
		result, err := SanitizePath(base, "song.flac")
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		cleanBase := filepath.Clean(base)
		if !strings.HasPrefix(result, cleanBase) {
			t.Errorf("result = %q, should start with %q", result, cleanBase)
		}
	})

	t.Run("subdirectory", func(t *testing.T) {
		base := filepath.Join("/", "music")
		result, err := SanitizePath(base, "sub/song.flac")
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		cleanBase := filepath.Clean(base)
		if !strings.HasPrefix(result, cleanBase) {
			t.Errorf("result = %q, should start with %q", result, cleanBase)
		}
	})

	t.Run("path traversal blocked", func(t *testing.T) {
		_, err := SanitizePath(filepath.Join("/", "music"), "../etc/passwd")
		if err == nil {
			t.Error("expected error for path traversal")
		}
	})

	t.Run("deep path traversal blocked", func(t *testing.T) {
		_, err := SanitizePath(filepath.Join("/", "music"), "sub/../../etc/passwd")
		if err == nil {
			t.Error("expected error for path traversal")
		}
	})
}

func TestFreeSpace(t *testing.T) {
	_, err := FreeSpace("/")
	if err == nil {
		t.Log("FreeSpace returned no error (platform specific)")
	}
}
