package database

import (
	"database/sql"
	"embed"
	"fmt"
	"sync"

	_ "github.com/ncruces/go-sqlite3/driver"
)

//go:embed migrations/*.sql
var migrationsFS embed.FS

var (
	masterDB   *sql.DB
	masterDBMu sync.RWMutex
)

// Init opens and initializes the master database.
func Init(dbPath string) error {
	masterDBMu.Lock()
	defer masterDBMu.Unlock()

	if masterDB != nil {
		masterDB.Close()
	}

	db, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}

	if err := applyPragmas(db); err != nil {
		return fmt.Errorf("pragmas: %w", err)
	}

	if err := runMigrations(db); err != nil {
		db.Close()
		return fmt.Errorf("migrations: %w", err)
	}

	masterDB = db
	return nil
}

// Get returns the master database handle.
func Get() (*sql.DB, error) {
	masterDBMu.RLock()
	defer masterDBMu.RUnlock()
	if masterDB == nil {
		return nil, fmt.Errorf("database not initialized")
	}
	return masterDB, nil
}

// Close cleanly shuts down the database.
func Close() error {
	masterDBMu.Lock()
	defer masterDBMu.Unlock()
	if masterDB != nil {
		return masterDB.Close()
	}
	return nil
}

func applyPragmas(db *sql.DB) error {
	pragmas := []string{
		"PRAGMA journal_mode=WAL",
		"PRAGMA synchronous=NORMAL",
		"PRAGMA cache_size=-64000",
		"PRAGMA foreign_keys=ON",
		"PRAGMA busy_timeout=5000",
		"PRAGMA locking_mode=NORMAL",
	}
	for _, p := range pragmas {
		if _, err := db.Exec(p); err != nil {
			return fmt.Errorf("%s: %w", p, err)
		}
	}
	return nil
}

func runMigrations(db *sql.DB) error {
	schema, err := migrationsFS.ReadFile("migrations/001_initial.sql")
	if err != nil {
		return fmt.Errorf("read migration: %w", err)
	}
	if _, err := db.Exec(string(schema)); err != nil {
		return fmt.Errorf("execute migration: %w", err)
	}
	if err := RunMigrationV2(db); err != nil {
		Log("[DB] V2 migration warning: %v", err)
	}
	return nil
}

// WithTx executes a function within a database transaction.
func WithTx(fn func(*sql.Tx) error) error {
	db, err := Get()
	if err != nil {
		return err
	}
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if err := fn(tx); err != nil {
		return err
	}
	return tx.Commit()
}
