package extensions

import (
	"os"
	"testing"
)

func testSignedConfig() SignedSessionConfig {
	return SignedSessionConfig{
		Namespace:   "zarz-v2",
		BaseURL:     "https://api.zarz.moe/v2",
		AppVersion:  "deezer@1.1.0",
		Platform:    "extension",
		CallbackURL: "spotiflac://session-grant",
	}
}

// TestLoadOrInitStableInstallID simulates the Android scenario where the data
// dir is not writable: the on-disk record never persists, yet the install_id
// MUST stay stable between bootstrap and grant exchange. Regression for the
// "completeSignedSessionGrant always returns false" bug (the grant was bound
// to the bootstrap install_id while the exchange used a freshly generated one).
func TestLoadOrInitStableInstallID(t *testing.T) {
	cfg := testSignedConfig()
	s := &SignedSessionState{}
	dir := t.TempDir()

	r1, err := s.loadOrInit(dir, cfg)
	if err != nil {
		t.Fatalf("first loadOrInit: %v", err)
	}
	id1 := r1.InstallID
	if id1 == "" {
		t.Fatal("install_id should be generated")
	}

	// Wipe the persisted file so a disk-backed read would generate a new id
	// (equivalent to an unwritable dataDir on Android).
	if path, err := signedSessionFilePath(dir, cfg); err == nil {
		os.Remove(path)
	}

	// The second loadOrInit must reuse the in-memory record (stable install_id).
	r2, err := s.loadOrInit(dir, cfg)
	if err != nil {
		t.Fatalf("second loadOrInit: %v", err)
	}
	if r2.InstallID != id1 {
		t.Fatalf("install_id changed across loadOrInit: %s -> %s", id1, r2.InstallID)
	}
}

// TestLoadOrInitReadsPersistedRecord verifies a fresh state (new process)
// still picks up a persisted record from disk when persistence works.
func TestLoadOrInitReadsPersistedRecord(t *testing.T) {
	cfg := testSignedConfig()
	s := &SignedSessionState{}
	dir := t.TempDir()

	r1, err := s.loadOrInit(dir, cfg)
	if err != nil {
		t.Fatalf("first loadOrInit: %v", err)
	}
	// persistRecord writes to the (writable) temp dir.
	s.persistRecord(cfg)

	s2 := &SignedSessionState{}
	r2, err := s2.loadOrInit(dir, cfg)
	if err != nil {
		t.Fatalf("fresh loadOrInit: %v", err)
	}
	if r2.InstallID != r1.InstallID {
		t.Fatalf("fresh loadOrInit did not read persisted install_id: %s -> %s", r1.InstallID, r2.InstallID)
	}
}

// TestLoadOrInitScopeChangeResetsSession verifies a record from a different
// scope (different extension/app_version) has its session cleared so a stale
// session is never reused across extensions.
func TestLoadOrInitScopeChangeResetsSession(t *testing.T) {
	cfg1 := testSignedConfig()
	s := &SignedSessionState{}
	dir := t.TempDir()

	r1, err := s.loadOrInit(dir, cfg1)
	if err != nil {
		t.Fatal(err)
	}
	r1.SessionID = "sess"
	r1.SessionSecret = "secret"
	r1.ExpiresAt = "2099-01-01T00:00:00Z"

	cfg2 := cfg1
	cfg2.AppVersion = "qobuz-web@1.1.0"
	r2, err := s.loadOrInit(dir, cfg2)
	if err != nil {
		t.Fatal(err)
	}
	if r2.SessionID != "" || r2.SessionSecret != "" {
		t.Fatalf("session not reset on scope change: session_id=%q secret=%q", r2.SessionID, r2.SessionSecret)
	}
	if r2.AppVersion != cfg2.AppVersion {
		t.Fatalf("app_version not stamped: %s", r2.AppVersion)
	}
}
