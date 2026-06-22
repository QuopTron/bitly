package runtime

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/manifest"
)

func fileTestVM(t *testing.T, jsCode string) {
	t.Helper()
	sourceDir := t.TempDir()
	dataDir := t.TempDir()
	r := NewExtensionRuntime()
	js := `var extension = { test: function() {` + jsCode + `} };`
	jsPath := writeTestJS(t, js)
	mf := &manifest.ExtensionManifest{
		Permissions: manifest.ExtensionPermissions{
			File:    true,
			Network: []string{"*"},
		},
	}
	if err := r.LoadExtensionWithDirs("file", jsPath, sourceDir, dataDir, mf); err != nil {
		t.Fatal(err)
	}
	if _, err := r.CallMethod("file", "test"); err != nil {
		t.Fatal(err)
	}
}

func TestFile_WriteRead(t *testing.T) {
	fileTestVM(t, `
		var w = file.write("test.txt", "hello world");
		if (w.success !== true) throw new Error("write failed: " + JSON.stringify(w));
		var r = file.read("test.txt");
		if (r.success !== true || r.data !== "hello world") throw new Error("read: " + JSON.stringify(r));
	`)
}

func TestFile_Exists(t *testing.T) {
	fileTestVM(t, `
		if (file.exists("absent.txt") !== false) throw new Error("should not exist");
		file.write("present.txt", "data");
		if (file.exists("present.txt") !== true) throw new Error("should exist after write");
	`)
}

func TestFile_Delete(t *testing.T) {
	fileTestVM(t, `
		file.write("del.txt", "data");
		if (file.exists("del.txt") !== true) throw new Error("should exist");
		var d = file.delete("del.txt");
		if (d.success !== true) throw new Error("delete failed: " + JSON.stringify(d));
		if (file.exists("del.txt") !== false) throw new Error("should be gone");
	`)
}

func TestFile_Copy(t *testing.T) {
	fileTestVM(t, `
		file.write("src.txt", "copy me");
		var c = file.copy("src.txt", "dst.txt");
		if (c.success !== true) throw new Error("copy failed: " + JSON.stringify(c));
		var r = file.read("dst.txt");
		if (r.data !== "copy me") throw new Error("copy content: " + r.data);
	`)
}

func TestFile_Move(t *testing.T) {
	fileTestVM(t, `
		file.write("a.txt", "move me");
		var m = file.move("a.txt", "b.txt");
		if (m.success !== true) throw new Error("move failed: " + JSON.stringify(m));
		if (file.exists("a.txt") !== false) throw new Error("source should not exist after move");
		if (file.exists("b.txt") !== true) throw new Error("dest should exist after move");
		var r = file.read("b.txt");
		if (r.data !== "move me") throw new Error("move content: " + r.data);
	`)
}

func TestFile_GetSize(t *testing.T) {
	fileTestVM(t, `
		file.write("size.txt", "12345");
		var s = file.getSize("size.txt");
		if (s.success !== true || s.size !== 5) throw new Error("size: " + JSON.stringify(s));
	`)
}

func TestFile_PathTraversal_Blocked(t *testing.T) {
	fileTestVM(t, `
		var r = file.read("../etc/passwd");
		if (r.success === true) throw new Error("traversal should fail");
	`)
}

func TestFile_NoFilePermission(t *testing.T) {
	sourceDir := t.TempDir()
	dataDir := t.TempDir()
	r := NewExtensionRuntime()
	jsPath := writeTestJS(t, `var extension = { test: function() {
		var w = file.write("test.txt", "data");
		if (w.success === true) throw new Error("should fail without file permission");
	} };`)
	mf := &manifest.ExtensionManifest{
		Permissions: manifest.ExtensionPermissions{
			File:    false,
			Network: []string{"*"},
		},
	}
	if err := r.LoadExtensionWithDirs("file", jsPath, sourceDir, dataDir, mf); err != nil {
		t.Fatal(err)
	}
	if _, err := r.CallMethod("file", "test"); err != nil {
		t.Fatal(err)
	}
}

func TestFile_Download(t *testing.T) {
	dataDir := t.TempDir()
	r := NewExtensionRuntime()
	js := `var extension = { test: function() { return file.exists("downloaded.txt"); } };`
	jsPath := writeTestJS(t, js)
	mf := &manifest.ExtensionManifest{
		Permissions: manifest.ExtensionPermissions{
			File:    true,
			Network: []string{"*"},
		},
	}
	if err := r.LoadExtensionWithDirs("file", jsPath, t.TempDir(), dataDir, mf); err != nil {
		t.Fatal(err)
	}
	os.WriteFile(filepath.Join(dataDir, "downloaded.txt"), []byte("downloaded"), 0644)
	res, err := r.CallMethod("file", "test")
	if err != nil { t.Fatal(err) }
	if res.Value != true { t.Error("expected downloaded file to exist") }
}
