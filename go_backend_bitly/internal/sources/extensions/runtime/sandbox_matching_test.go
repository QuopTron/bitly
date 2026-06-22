package runtime

import (
	"testing"
)

func matchingTestVM(t *testing.T, jsCode string) {
	t.Helper()
	r := NewExtensionRuntime()
	jsPath := writeTestJS(t, `var extension = { test: function() {`+jsCode+`} };`)
	if err := r.LoadExtensionWithDirs("matching", jsPath, t.TempDir(), t.TempDir(), nil); err != nil {
		t.Fatal(err)
	}
	if _, err := r.CallMethod("matching", "test"); err != nil {
		t.Fatal(err)
	}
}

func TestMatching_CompareStrings_Exact(t *testing.T) {
	matchingTestVM(t, `
		var score = matching.compareStrings("hello", "hello");
		if (score !== 1) throw new Error("exact match should be 1: " + score);
	`)
}

func TestMatching_CompareStrings_Similar(t *testing.T) {
	matchingTestVM(t, `
		var score = matching.compareStrings("hello", "hallo");
		if (score < 0.5) throw new Error("similar should be > 0.5: " + score);
	`)
}

func TestMatching_CompareStrings_Different(t *testing.T) {
	matchingTestVM(t, `
		var score = matching.compareStrings("hello", "xyz");
		if (score > 0.3) throw new Error("different should be < 0.3: " + score);
	`)
}

func TestMatching_CompareStrings_Empty(t *testing.T) {
	matchingTestVM(t, `
		var score = matching.compareStrings("", "");
		if (score !== 1) throw new Error("empty strings should match: " + score);
		var s2 = matching.compareStrings("hello", "");
		if (s2 !== 0) throw new Error("non-empty vs empty: " + s2);
	`)
}

func TestMatching_CompareStrings_Shorter(t *testing.T) {
	matchingTestVM(t, `
		var s1 = matching.compareStrings("abc", "abcdef");
		var s2 = matching.compareStrings("abcdef", "abc");
		if (s1 !== s2) throw new Error("should be symmetric: " + s1 + " vs " + s2);
	`)
}

func TestMatching_CompareDuration_Exact(t *testing.T) {
	matchingTestVM(t, `
		var match = matching.compareDuration("210000", "210000");
		if (match !== true) throw new Error("exact duration should be true: " + match);
	`)
}

func TestMatching_CompareDuration_WithinTolerance(t *testing.T) {
	matchingTestVM(t, `
		var match = matching.compareDuration("210000", "212000");
		if (match !== true) throw new Error("within tolerance: " + match);
	`)
}

func TestMatching_CompareDuration_Different(t *testing.T) {
	matchingTestVM(t, `
		var match = matching.compareDuration("210000", "300000");
		if (match !== false) throw new Error("different duration should be false: " + match);
	`)
}

func TestMatching_CompareDuration_CustomTolerance(t *testing.T) {
	matchingTestVM(t, `
		var match = matching.compareDuration("210000", "213000", 5000);
		if (match !== true) throw new Error("custom tolerance: " + match);
		var noMatch = matching.compareDuration("210000", "220000", 1000);
		if (noMatch !== false) throw new Error("outside tolerance: " + noMatch);
	`)
}

func TestMatching_NormalizeString(t *testing.T) {
	matchingTestVM(t, `
		var n = matching.normalizeString("Hello, World!!!");
		if (n.indexOf("hello") < 0) throw new Error("should contain hello");
		if (n.indexOf("world") < 0) throw new Error("should contain world");
	`)
}

func TestMatching_NormalizeString_Lowercase(t *testing.T) {
	matchingTestVM(t, `
		var n = matching.normalizeString("HELLO WORLD");
		if (n !== "hello world") throw new Error("should lowercase: " + n);
	`)
}

func TestMatching_NormalizeString_RemovesPunctuation(t *testing.T) {
	matchingTestVM(t, `
		var n = matching.normalizeString("Hello!!! (World) - [test]");
		if (n.indexOf("!") >= 0) throw new Error("should remove !");
		if (n.indexOf("(") >= 0) throw new Error("should remove (");
	`)
}

func TestMatching_NormalizeString_RemovesFeat(t *testing.T) {
	matchingTestVM(t, `
		var n = matching.normalizeString("Song ft. Artist");
		if (n.indexOf("ft") >= 0) throw new Error("should remove ft: " + n);
	`)
}

func TestMatching_NormalizeString_RemovesRemastered(t *testing.T) {
	matchingTestVM(t, `
		var n = matching.normalizeString("Song (remastered)");
		if (n.indexOf("remastered") >= 0) throw new Error("should remove remastered: " + n);
	`)
}
