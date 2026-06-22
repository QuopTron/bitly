package runtime

import (
	"testing"
)

func urlTestVM(t *testing.T, jsCode string) {
	t.Helper()
	r := NewExtensionRuntime()
	jsPath := writeTestJS(t, `var extension = { test: function() {`+jsCode+`} };`)
	if err := r.LoadExtensionWithDirs("url", jsPath, t.TempDir(), t.TempDir(), nil); err != nil {
		t.Fatal(err)
	}
	if _, err := r.CallMethod("url", "test"); err != nil {
		t.Fatal(err)
	}
}

func TestURL_Basic(t *testing.T) {
	urlTestVM(t, `
		var u = new URL("https://example.com/path?q=hello#frag");
		if (u.protocol !== "https:") throw new Error("protocol: " + u.protocol);
		if (u.hostname !== "example.com") throw new Error("hostname: " + u.hostname);
		if (u.pathname !== "/path") throw new Error("pathname: " + u.pathname);
		if (u.search !== "?q=hello") throw new Error("search: " + u.search);
		if (u.hash !== "#frag") throw new Error("hash: " + u.hash);
		if (u.href !== "https://example.com/path?q=hello#frag") throw new Error("href: " + u.href);
	`)
}

func TestURL_Relative(t *testing.T) {
	urlTestVM(t, `
		var base = new URL("https://example.com/a/b/");
		var u = new URL("c/d", base);
		if (u.href !== "https://example.com/a/b/c/d") throw new Error("relative: " + u.href);
		var u2 = new URL("/absolute", "https://example.com/foo/");
		if (u2.href !== "https://example.com/absolute") throw new Error("absolute: " + u2.href);
	`)
}

func TestURL_Port(t *testing.T) {
	urlTestVM(t, `
		var u = new URL("https://example.com:8080/path");
		if (u.port !== "8080") throw new Error("port: " + u.port);
		if (u.host !== "example.com:8080") throw new Error("host: " + u.host);
	`)
}

func TestURL_Origin(t *testing.T) {
	urlTestVM(t, `
		var u = new URL("https://example.com:8443/path?a=1");
		if (u.origin !== "https://example.com:8443") throw new Error("origin: " + u.origin);
	`)
}

func TestURLSearchParams_FromString(t *testing.T) {
	urlTestVM(t, `
		var p = new URLSearchParams("?a=1&b=2&a=3");
		if (p.get("a") !== "1") throw new Error("get a: " + p.get("a"));
		if (p.get("b") !== "2") throw new Error("get b: " + p.get("b"));
		if (p.get("c") !== null) throw new Error("get c should be null");
		var allA = p.getAll("a");
		if (allA.length !== 2 || allA[0] !== "1" || allA[1] !== "3") throw new Error("getAll a");
		if (p.has("b") !== true) throw new Error("has b");
		if (p.has("c") !== false) throw new Error("has c");
	`)
}

func TestURLSearchParams_AppendDelete(t *testing.T) {
	urlTestVM(t, `
		var p = new URLSearchParams();
		p.append("x", "1");
		p.append("x", "2");
		if (p.get("x") !== "1") throw new Error("after append: " + p.get("x"));
		if (p.getAll("x").length !== 2) throw new Error("should have 2");
		p.delete("x");
		if (p.get("x") !== null) throw new Error("after delete: " + p.get("x"));
	`)
}

func TestURLSearchParams_Set(t *testing.T) {
	urlTestVM(t, `
		var p = new URLSearchParams("?a=1&a=2");
		p.set("a", "3");
		var all = p.getAll("a");
		if (all.length !== 1 || all[0] !== "3") throw new Error("set: " + JSON.stringify(all));
	`)
}

func TestURLSearchParams_ToString(t *testing.T) {
	urlTestVM(t, `
		var p = new URLSearchParams({x: "1", y: "2"});
		var s = p.toString();
		if (s !== "x=1&y=2" && s !== "y=2&x=1") throw new Error("toString: " + s);
	`)
}

func TestTextEncoder(t *testing.T) {
	urlTestVM(t, `
		var enc = new TextEncoder();
		var arr = enc.encode("hello");
		if (arr.length !== 5) throw new Error("length: " + arr.length);
		if (arr[0] !== 104) throw new Error("first byte: " + arr[0]);
		var u = enc.encode("✓");
		if (u.length !== 3) throw new Error("unicode bytes: " + u.length);
	`)
}

func TestTextEncoder_Empty(t *testing.T) {
	urlTestVM(t, `
		var enc = new TextEncoder();
		var arr = enc.encode("");
		if (arr.length !== 0) throw new Error("empty should be 0");
	`)
}

func TestTextDecoder(t *testing.T) {
	urlTestVM(t, `
		var dec = new TextDecoder();
		var str = dec.decode([104, 101, 108, 108, 111]);
		if (str !== "hello") throw new Error("decode: " + str);
		if (dec.decode() !== "") throw new Error("empty decode should be empty");
	`)
}

func TestTextDecoder_UTF8(t *testing.T) {
	urlTestVM(t, `
		var dec = new TextDecoder("utf-8");
		var str = dec.decode([0xE2, 0x9C, 0x93]);
		if (str !== "✓") throw new Error("utf8 decode: " + str);
	`)
}
