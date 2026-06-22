package runtime

import (
	"testing"
)

func storageTestVM(t *testing.T, jsCode string) {
	t.Helper()
	r := NewExtensionRuntime()
	jsPath := writeTestJS(t, `var extension = { test: function() {`+jsCode+`} };`)
	if err := r.LoadExtensionWithDirs("store", jsPath, t.TempDir(), t.TempDir(), nil); err != nil {
		t.Fatal(err)
	}
	if _, err := r.CallMethod("store", "test"); err != nil {
		t.Fatal(err)
	}
}

func TestStorage_SetGet(t *testing.T) {
	storageTestVM(t, `
		storage.set("key1", "value1");
		var v = storage.get("key1");
		if (v !== "value1") throw new Error("get: " + v);
	`)
}

func TestStorage_GetDefault(t *testing.T) {
	storageTestVM(t, `
		var v = storage.get("nonexistent", "default");
		if (v !== "default") throw new Error("default: " + v);
	`)
}

func TestStorage_GetUndefined(t *testing.T) {
	storageTestVM(t, `
		var v = storage.get("nonexistent");
		if (v !== undefined) throw new Error("should be undefined");
	`)
}

func TestStorage_Remove(t *testing.T) {
	storageTestVM(t, `
		storage.set("temp", "value");
		if (storage.get("temp") !== "value") throw new Error("should exist");
		var removed = storage.remove("temp");
		if (removed !== true) throw new Error("remove should return true");
		var v = storage.get("temp");
		if (v !== undefined) throw new Error("should be gone after remove");
	`)
}

func TestStorage_Overwrite(t *testing.T) {
	storageTestVM(t, `
		storage.set("x", 1);
		storage.set("x", 2);
		var v = storage.get("x");
		if (v !== 2) throw new Error("overwrite: " + v);
	`)
}

func TestStorage_Numbers(t *testing.T) {
	storageTestVM(t, `
		storage.set("int", 42);
		storage.set("float", 3.14);
		if (storage.get("int") !== 42) throw new Error("int");
		if (storage.get("float") !== 3.14) throw new Error("float");
	`)
}

func TestStorage_Bool(t *testing.T) {
	storageTestVM(t, `
		storage.set("t", true);
		storage.set("f", false);
		if (storage.get("t") !== true) throw new Error("true");
		if (storage.get("f") !== false) throw new Error("false");
	`)
}

func TestStorage_Objects(t *testing.T) {
	storageTestVM(t, `
		storage.set("obj", {a:1, b:[2,3]});
		var obj = storage.get("obj");
		if (obj.a !== 1) throw new Error("obj.a");
		if (obj.b[0] !== 2) throw new Error("obj.b[0]");
		if (obj.b[1] !== 3) throw new Error("obj.b[1]");
	`)
}

func TestCredentials_StoreGet(t *testing.T) {
	storageTestVM(t, `
		var result = credentials.store("token", "secret123");
		if (result.success !== true) throw new Error("store failed: " + JSON.stringify(result));
		var v = credentials.get("token");
		if (v !== "secret123") throw new Error("get: " + v);
	`)
}

func TestCredentials_Has(t *testing.T) {
	storageTestVM(t, `
		if (credentials.has("missing")) throw new Error("should not have");
		credentials.store("exists", "yes");
		if (!credentials.has("exists")) throw new Error("should have after store");
	`)
}

func TestCredentials_Remove(t *testing.T) {
	storageTestVM(t, `
		credentials.store("tmp", "val");
		if (!credentials.has("tmp")) throw new Error("should have");
		credentials.remove("tmp");
		if (credentials.has("tmp")) throw new Error("should be removed");
	`)
}

func TestCredentials_DefaultValue(t *testing.T) {
	storageTestVM(t, `
		var v = credentials.get("missing", "fallback");
		if (v !== "fallback") throw new Error("default: " + v);
	`)
}

func TestCredentials_Isolation(t *testing.T) {
	storageTestVM(t, `
		credentials.store("key", "from-store");
		storage.set("key", "from-storage");
		if (credentials.get("key") !== "from-store") throw new Error("creds should have own value");
		if (storage.get("key") !== "from-storage") throw new Error("storage should have own value");
	`)
}
