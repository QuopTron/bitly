package quota

import (
	"database/sql"
	"math"
	"testing"

	_ "github.com/ncruces/go-sqlite3/driver"
)

func setupTestDB(t *testing.T) *sql.DB {
	t.Helper()
	db, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Skipf("sqlite3 driver not available: %v", err)
	}
	_, err = db.Exec(`
		CREATE TABLE quota_usage (
			user_id TEXT,
			track_id TEXT,
			duration_minutes REAL,
			status TEXT,
			downloaded_at TEXT DEFAULT (datetime('now'))
		);
		CREATE TABLE premium_users (
			user_id TEXT PRIMARY KEY,
			expires_at TEXT
		);
	`)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = db.Close() })
	return db
}

func TestStorage_GetStatus_NonPremium_NoUsage(t *testing.T) {
	db := setupTestDB(t)
	s := NewQuotaStorage(db)

	status, err := s.GetStatus("user_free_empty")
	if err != nil {
		t.Fatal(err)
	}

	if status.IsPremium {
		t.Error("IsPremium: want false")
	}
	if status.TotalMinutes != 720 {
		t.Errorf("TotalMinutes: want 720, got %d", status.TotalMinutes)
	}
	if status.UsedMinutes != 0 {
		t.Errorf("UsedMinutes: want 0, got %f", status.UsedMinutes)
	}
	if status.RemainingMinutes != 720 {
		t.Errorf("RemainingMinutes: want 720, got %f", status.RemainingMinutes)
	}
	if !status.CanDownload {
		t.Error("CanDownload: want true (720 remaining)")
	}
}

func TestStorage_GetStatus_NonPremium_PartialUsage(t *testing.T) {
	db := setupTestDB(t)
	s := NewQuotaStorage(db)

	_, err := db.Exec(`INSERT INTO quota_usage (user_id, track_id, duration_minutes, status) VALUES (?,?,?,?)`,
		"user_free_partial", "t1", 200, "completed")
	if err != nil {
		t.Fatal(err)
	}

	status, err := s.GetStatus("user_free_partial")
	if err != nil {
		t.Fatal(err)
	}

	if status.IsPremium {
		t.Error("IsPremium: want false")
	}
	if status.UsedMinutes != 200 {
		t.Errorf("UsedMinutes: want 200, got %f", status.UsedMinutes)
	}
	if status.RemainingMinutes != 520 {
		t.Errorf("RemainingMinutes: want 520, got %f", status.RemainingMinutes)
	}
	if !status.CanDownload {
		t.Error("CanDownload: want true (520 remaining)")
	}
}

func TestStorage_GetStatus_NonPremium_ExactlyAtLimit(t *testing.T) {
	db := setupTestDB(t)
	s := NewQuotaStorage(db)

	_, err := db.Exec(`INSERT INTO quota_usage (user_id, track_id, duration_minutes, status) VALUES (?,?,?,?)`,
		"user_free_limit", "t1", 720, "completed")
	if err != nil {
		t.Fatal(err)
	}

	status, err := s.GetStatus("user_free_limit")
	if err != nil {
		t.Fatal(err)
	}

	if status.UsedMinutes != 720 {
		t.Errorf("UsedMinutes: want 720, got %f", status.UsedMinutes)
	}
	if status.RemainingMinutes != 0 {
		t.Errorf("RemainingMinutes: want 0, got %f", status.RemainingMinutes)
	}
	if status.CanDownload {
		t.Error("CanDownload: want false (0 remaining)")
	}
}

func TestStorage_GetStatus_NonPremium_ExceededLimit(t *testing.T) {
	db := setupTestDB(t)
	s := NewQuotaStorage(db)

	_, err := db.Exec(`INSERT INTO quota_usage (user_id, track_id, duration_minutes, status) VALUES (?,?,?,?)`,
		"user_free_over", "t1", 800, "completed")
	if err != nil {
		t.Fatal(err)
	}

	status, err := s.GetStatus("user_free_over")
	if err != nil {
		t.Fatal(err)
	}

	if status.UsedMinutes != 800 {
		t.Errorf("UsedMinutes: want 800, got %f", status.UsedMinutes)
	}
	if status.RemainingMinutes != 0 {
		t.Errorf("RemainingMinutes: want 0 (clamped), got %f", status.RemainingMinutes)
	}
	if status.CanDownload {
		t.Error("CanDownload: want false (exceeded)")
	}
}

func TestStorage_GetStatus_Premium_NoUsage(t *testing.T) {
	db := setupTestDB(t)
	s := NewQuotaStorage(db)

	_, err := db.Exec(`INSERT INTO premium_users (user_id, expires_at) VALUES (?,?)`,
		"prem_empty", "2099-12-31 23:59:59")
	if err != nil {
		t.Fatal(err)
	}

	status, err := s.GetStatus("prem_empty")
	if err != nil {
		t.Fatal(err)
	}

	if !status.IsPremium {
		t.Error("IsPremium: want true")
	}
	if status.UsedMinutes != 0 {
		t.Errorf("UsedMinutes: want 0, got %f", status.UsedMinutes)
	}
	if status.RemainingMinutes != 0 {
		t.Errorf("RemainingMinutes: want 0 (unlimited), got %f", status.RemainingMinutes)
	}
	if !status.CanDownload {
		t.Error("CanDownload: want true (premium)")
	}
}

func TestStorage_GetStatus_Premium_WithUsage(t *testing.T) {
	db := setupTestDB(t)
	s := NewQuotaStorage(db)

	_, err := db.Exec(`INSERT INTO premium_users (user_id, expires_at) VALUES (?,?)`,
		"prem_used", "2099-12-31 23:59:59")
	if err != nil {
		t.Fatal(err)
	}
	_, err = db.Exec(`INSERT INTO quota_usage (user_id, track_id, duration_minutes, status) VALUES (?,?,?,?)`,
		"prem_used", "t1", 5000, "completed")
	if err != nil {
		t.Fatal(err)
	}

	status, err := s.GetStatus("prem_used")
	if err != nil {
		t.Fatal(err)
	}

	if !status.IsPremium {
		t.Error("IsPremium: want true")
	}
	if status.UsedMinutes != 5000 {
		t.Errorf("UsedMinutes: want 5000, got %f", status.UsedMinutes)
	}
	if status.RemainingMinutes != 0 {
		t.Errorf("RemainingMinutes: want 0 (unlimited), got %f", status.RemainingMinutes)
	}
	if !status.CanDownload {
		t.Error("CanDownload: want true (premium unlimited)")
	}
}

func TestStorage_GetStatus_ExpiredPremium(t *testing.T) {
	db := setupTestDB(t)
	s := NewQuotaStorage(db)

	_, err := db.Exec(`INSERT INTO premium_users (user_id, expires_at) VALUES (?,?)`,
		"expired", "2020-01-01 00:00:00")
	if err != nil {
		t.Fatal(err)
	}

	status, err := s.GetStatus("expired")
	if err != nil {
		t.Fatal(err)
	}

	if status.IsPremium {
		t.Error("IsPremium: want false (expired)")
	}
	if status.RemainingMinutes != 720 {
		t.Errorf("RemainingMinutes: want 720 (free tier), got %f", status.RemainingMinutes)
	}
	if !status.CanDownload {
		t.Error("CanDownload: want true (free tier full quota)")
	}
}

func TestStorage_GetStatus_NonExistentUser(t *testing.T) {
	db := setupTestDB(t)
	s := NewQuotaStorage(db)

	status, err := s.GetStatus("nobody")
	if err != nil {
		t.Fatal(err)
	}

	if status.IsPremium {
		t.Error("IsPremium: want false for non-existent user")
	}
	if status.UsedMinutes != 0 {
		t.Errorf("UsedMinutes: want 0, got %f", status.UsedMinutes)
	}
	if status.RemainingMinutes != 720 {
		t.Errorf("RemainingMinutes: want 720, got %f", status.RemainingMinutes)
	}
	if !status.CanDownload {
		t.Error("CanDownload: want true")
	}
}

func TestStorage_GetStatus_ReservedRecordsCountInSum(t *testing.T) {
	db := setupTestDB(t)
	s := NewQuotaStorage(db)

	_, err := db.Exec(`INSERT INTO quota_usage (user_id, track_id, duration_minutes, status) VALUES (?,?,?,?)`,
		"user_reserved", "t1", 50, "completed")
	if err != nil {
		t.Fatal(err)
	}
	_, err = db.Exec(`INSERT INTO quota_usage (user_id, track_id, duration_minutes, status) VALUES (?,?,?,?)`,
		"user_reserved", "t2", 30, "reserved")
	if err != nil {
		t.Fatal(err)
	}

	status, err := s.GetStatus("user_reserved")
	if err != nil {
		t.Fatal(err)
	}

	want := 80.0
	if math.Abs(status.UsedMinutes-want) > 0.001 {
		t.Errorf("UsedMinutes: want %f (completed+reserved both counted), got %f", want, status.UsedMinutes)
	}
}
