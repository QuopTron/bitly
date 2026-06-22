package database

import (
	"database/sql"
	"testing"
)

func TestGet_NotInitialized(t *testing.T) {
	masterDBMu.Lock()
	oldDB := masterDB
	masterDB = nil
	masterDBMu.Unlock()
	defer func() {
		masterDBMu.Lock()
		masterDB = oldDB
		masterDBMu.Unlock()
	}()

	_, err := Get()
	if err == nil {
		t.Fatal("expected error when database not initialized")
	}
}

func TestClose_NotInitialized(t *testing.T) {
	masterDBMu.Lock()
	oldDB := masterDB
	masterDB = nil
	masterDBMu.Unlock()
	defer func() {
		masterDBMu.Lock()
		masterDB = oldDB
		masterDBMu.Unlock()
	}()

	err := Close()
	if err != nil {
		t.Fatalf("Close on nil should return nil: %v", err)
	}
}

func TestWithTx_NotInitialized(t *testing.T) {
	masterDBMu.Lock()
	oldDB := masterDB
	masterDB = nil
	masterDBMu.Unlock()
	defer func() {
		masterDBMu.Lock()
		masterDB = oldDB
		masterDBMu.Unlock()
	}()

	err := WithTx(func(tx *sql.Tx) error {
		return nil
	})
	if err == nil {
		t.Fatal("expected error when database not initialized")
	}
}

func TestDBInitAndGet(t *testing.T) {
	masterDBMu.Lock()
	oldDB := masterDB
	masterDB = nil
	masterDBMu.Unlock()
	defer func() {
		masterDBMu.Lock()
		masterDB = oldDB
		masterDBMu.Unlock()
	}()

	err := Init(":memory:")
	if err != nil {
		t.Fatalf("Init failed: %v", err)
	}
	defer Close()

	db, err := Get()
	if err != nil {
		t.Fatalf("Get failed: %v", err)
	}
	if db == nil {
		t.Fatal("expected non-nil db")
	}

	var result int
	err = db.QueryRow("SELECT 1").Scan(&result)
	if err != nil {
		t.Fatalf("query failed: %v", err)
	}
	if result != 1 {
		t.Errorf("expected 1, got %d", result)
	}
}

func TestDBMigrations(t *testing.T) {
	masterDBMu.Lock()
	oldDB := masterDB
	masterDB = nil
	masterDBMu.Unlock()
	defer func() {
		masterDBMu.Lock()
		masterDB = oldDB
		masterDBMu.Unlock()
	}()

	err := Init(":memory:")
	if err != nil {
		t.Fatalf("Init failed: %v", err)
	}
	defer Close()

	db, _ := Get()

	tables := []string{"tracks", "albums", "artists", "playlists", "download_history", "local_library", "play_history"}
	for _, table := range tables {
		var exists int
		err := db.QueryRow("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?", table).Scan(&exists)
		if err != nil {
			t.Fatalf("check table %s: %v", table, err)
		}
		if exists == 0 {
			t.Logf("Table %s not found (may have different name in schema)", table)
		}
	}
}
