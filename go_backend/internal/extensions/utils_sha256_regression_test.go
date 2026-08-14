package extensions

import (
	"testing"
)

func TestZZUtilsSha256Available(t *testing.T) {
	rt := NewRuntime()
	cfg := DefaultConfig()
	cfg.TimeoutMs = 30000
	_, err := rt.RunJS(`
function test(){ return utils.sha256("deezer:track:123"); }
`, "sha-test", "sha-test", cfg, ".")
	if err != nil {
		t.Fatalf("utils.sha256 missing or error: %v", err)
	}
	t.Log("utils.sha256 ok")
}