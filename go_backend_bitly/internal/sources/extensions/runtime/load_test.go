package runtime

import (
	"testing"
)

func TestLoadExtension_Success(t *testing.T) {
	r := NewExtensionRuntime()
	jsPath := writeTestJS(t, `var extension = { greet: function(n) { return "Hi " + n; } };`)
	if err := r.LoadExtension("greeter", jsPath); err != nil {
		t.Fatal(err)
	}
	if !r.IsLoaded("greeter") {
		t.Error("expected loaded")
	}
}

func TestLoadExtensionWithDirs(t *testing.T) {
	r := NewExtensionRuntime()
	jsPath := writeTestJS(t, `var extension = {};`)
	if err := r.LoadExtensionWithDirs("ext", jsPath, "/src", "/data", nil); err != nil {
		t.Fatal(err)
	}
	if !r.IsLoaded("ext") {
		t.Error("expected loaded")
	}
	ids := r.ListLoaded()
	if len(ids) != 1 {
		t.Fatalf("expected 1 loaded, got %d", len(ids))
	}
}

func TestLoadExtension_MissingFile(t *testing.T) {
	r := NewExtensionRuntime()
	err := r.LoadExtension("ext", "/nonexistent/file.js")
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestLoadExtension_NoExtensionObject(t *testing.T) {
	r := NewExtensionRuntime()
	jsPath := writeTestJS(t, `var x = 42;`)
	err := r.LoadExtension("ext", jsPath)
	if err == nil {
		t.Fatal("expected error for missing extension object")
	}
}

func TestLoadExtension_JSExecError(t *testing.T) {
	r := NewExtensionRuntime()
	jsPath := writeTestJS(t, `syntax error{{{`)
	err := r.LoadExtension("ext", jsPath)
	if err == nil {
		t.Fatal("expected error for bad JS")
	}
}

func TestHasMethod(t *testing.T) {
	r := NewExtensionRuntime()
	if r.HasMethod("nonexistent", "foo") {
		t.Error("expected false for unloaded")
	}
	jsPath := writeTestJS(t, `var extension = { foo: function() {}, bar: 42 };`)
	r.LoadExtension("ext", jsPath)
	if !r.HasMethod("ext", "foo") {
		t.Error("expected true for foo")
	}
	if !r.HasMethod("ext", "bar") {
		t.Error("expected true for bar (property exists)")
	}
	if r.HasMethod("ext", "baz") {
		t.Error("expected false for missing baz")
	}
}
