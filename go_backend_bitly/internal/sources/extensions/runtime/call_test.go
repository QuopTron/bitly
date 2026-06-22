package runtime

import (
	"testing"
	"time"

	"github.com/dop251/goja"
)

func TestCallMethod_NotLoaded(t *testing.T) {
	r := NewExtensionRuntime()
	_, err := r.CallMethod("nonexistent", "foo")
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestCallMethod_NoExtensionObject(t *testing.T) {
	r := NewExtensionRuntime()
	r.runtimes["test"] = &loadedExtensionRuntime{
		extensionID: "test",
		vm:          goja.New(),
		loadedAt:    time.Now(),
	}
	_, err := r.CallMethod("test", "foo")
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestCallMethod_MethodNotFound(t *testing.T) {
	r := NewExtensionRuntime()
	jsPath := writeTestJS(t, `var extension = {};`)
	r.LoadExtension("ext", jsPath)
	_, err := r.CallMethod("ext", "nonexistent")
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestCallMethod_NotAFunction(t *testing.T) {
	r := NewExtensionRuntime()
	jsPath := writeTestJS(t, `var extension = { foo: "bar" };`)
	r.LoadExtension("ext", jsPath)
	_, err := r.CallMethod("ext", "foo")
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestCallMethod_Success(t *testing.T) {
	r := NewExtensionRuntime()
	jsPath := writeTestJS(t, `var extension = { greet: function(name) { return "Hello, " + name + "!"; } };`)
	r.LoadExtension("ext", jsPath)
	res, err := r.CallMethod("ext", "greet", "World")
	if err != nil {
		t.Fatal(err)
	}
	if res.Value != "Hello, World!" {
		t.Errorf("unexpected value: %v", res.Value)
	}
	if res.RawJSON == "" {
		t.Error("expected non-empty RawJSON")
	}
}

func TestCallMethod_WithArgs(t *testing.T) {
	r := NewExtensionRuntime()
	jsPath := writeTestJS(t, `var extension = { add: function(a, b) { return a + b; } };`)
	r.LoadExtension("ext", jsPath)
	res, err := r.CallMethod("ext", "add", 3, 4)
	if err != nil {
		t.Fatal(err)
	}
	if res.Value != int64(7) {
		t.Errorf("expected 7, got %v (%T)", res.Value, res.Value)
	}
}

func TestCallMethod_NullReturn(t *testing.T) {
	r := NewExtensionRuntime()
	jsPath := writeTestJS(t, `var extension = { getNull: function() { return null; }, getUndefined: function() {} };`)
	r.LoadExtension("ext", jsPath)
	res, err := r.CallMethod("ext", "getNull")
	if err != nil {
		t.Fatal(err)
	}
	if res.Value != nil || res.RawJSON != "null" {
		t.Errorf("expected nil/null, got %v / %s", res.Value, res.RawJSON)
	}
	res2, err2 := r.CallMethod("ext", "getUndefined")
	if err2 != nil {
		t.Fatal(err2)
	}
	if res2.Value != nil || res2.RawJSON != "null" {
		t.Errorf("expected nil/null, got %v / %s", res2.Value, res2.RawJSON)
	}
}

func TestCallMethod_Panic(t *testing.T) {
	r := NewExtensionRuntime()
	jsPath := writeTestJS(t, `var extension = { panic: function() { throw new Error("boom"); } };`)
	r.LoadExtension("ext", jsPath)
	_, err := r.CallMethod("ext", "panic")
	if err == nil {
		t.Fatal("expected error from thrown error")
	}
}
