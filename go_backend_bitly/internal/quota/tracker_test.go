package quota

import (
	"testing"
)

func TestTracker_ReserveDownload_Success(t *testing.T) {
	db := setupTestDB(t)
	tracker := NewQuotaTracker(NewQuotaStorage(db))

	err := tracker.ReserveDownload("user1", "track1", 10)
	if err != nil {
		t.Fatalf("ReserveDownload: want nil, got %v", err)
	}

	var count int
	err = db.QueryRow(`SELECT COUNT(*) FROM quota_usage WHERE user_id=? AND track_id=? AND status='reserved'`,
		"user1", "track1").Scan(&count)
	if err != nil {
		t.Fatal(err)
	}
	if count != 1 {
		t.Errorf("expected 1 reserved row, got %d", count)
	}
}

func TestTracker_ReserveDownload_QuotaExceeded_FreeUser(t *testing.T) {
	db := setupTestDB(t)
	tracker := NewQuotaTracker(NewQuotaStorage(db))

	_, err := db.Exec(`INSERT INTO quota_usage (user_id, track_id, duration_minutes, status) VALUES (?,?,?,?)`,
		"user2", "old", 720, "completed")
	if err != nil {
		t.Fatal(err)
	}

	err = tracker.ReserveDownload("user2", "track2", 1)
	if err != ErrQuotaExceeded {
		t.Fatalf("ReserveDownload: want ErrQuotaExceeded, got %v", err)
	}

	var count int
	_ = db.QueryRow(`SELECT COUNT(*) FROM quota_usage WHERE user_id=? AND track_id=?`,
		"user2", "track2").Scan(&count)
	if count != 0 {
		t.Error("no reservation should exist after quota-exceeded attempt")
	}
}

func TestTracker_ReserveDownload_Premium_AlwaysAllowed(t *testing.T) {
	db := setupTestDB(t)
	tracker := NewQuotaTracker(NewQuotaStorage(db))

	_, err := db.Exec(`INSERT INTO premium_users (user_id, expires_at) VALUES (?,?)`,
		"prem1", "2099-12-31 23:59:59")
	if err != nil {
		t.Fatal(err)
	}
	_, err = db.Exec(`INSERT INTO quota_usage (user_id, track_id, duration_minutes, status) VALUES (?,?,?,?)`,
		"prem1", "old", 5000, "completed")
	if err != nil {
		t.Fatal(err)
	}

	err = tracker.ReserveDownload("prem1", "big_track", 200)
	if err != nil {
		t.Fatalf("premium ReserveDownload: want nil, got %v", err)
	}
}

func TestTracker_ReserveDownload_ExactBoundary_FreeUser(t *testing.T) {
	db := setupTestDB(t)
	tracker := NewQuotaTracker(NewQuotaStorage(db))

	_, err := db.Exec(`INSERT INTO quota_usage (user_id, track_id, duration_minutes, status) VALUES (?,?,?,?)`,
		"user3", "old", 710, "completed")
	if err != nil {
		t.Fatal(err)
	}

	// 710 used + 10 reserve = 720, exactly at limit → allowed
	err = tracker.ReserveDownload("user3", "track3", 10)
	if err != nil {
		t.Fatalf("ReserveDownload(10) with 710 used: want nil, got %v", err)
	}
}

func TestTracker_ReserveDownload_ExactBoundaryExceeded_FreeUser(t *testing.T) {
	db := setupTestDB(t)
	tracker := NewQuotaTracker(NewQuotaStorage(db))

	_, err := db.Exec(`INSERT INTO quota_usage (user_id, track_id, duration_minutes, status) VALUES (?,?,?,?)`,
		"user4", "old", 710, "completed")
	if err != nil {
		t.Fatal(err)
	}

	// 710 used + 11 reserve = 721, over limit → rejected
	err = tracker.ReserveDownload("user4", "track4", 11)
	if err != ErrQuotaExceeded {
		t.Fatalf("ReserveDownload(11) with 710 used: want ErrQuotaExceeded, got %v", err)
	}
}

func TestTracker_ConfirmDownload_ReleasesReservation(t *testing.T) {
	db := setupTestDB(t)
	tracker := NewQuotaTracker(NewQuotaStorage(db))

	err := tracker.ReserveDownload("user5", "track5", 10)
	if err != nil {
		t.Fatal(err)
	}

	err = tracker.ConfirmDownload("user5", "track5", 8.5)
	if err != nil {
		t.Fatalf("ConfirmDownload: want nil, got %v", err)
	}

	var count int
	_ = db.QueryRow(`SELECT COUNT(*) FROM quota_usage WHERE user_id=? AND track_id=?`,
		"user5", "track5").Scan(&count)
	if count != 0 {
		t.Errorf("expected 0 rows after confirm (reservation deleted + no 'completed' match), got %d", count)
	}
}

func TestTracker_ReleaseDownload_CancelsReservation(t *testing.T) {
	db := setupTestDB(t)
	tracker := NewQuotaTracker(NewQuotaStorage(db))

	err := tracker.ReserveDownload("user6", "track6", 10)
	if err != nil {
		t.Fatal(err)
	}

	err = tracker.ReleaseDownload("user6", "track6")
	if err != nil {
		t.Fatalf("ReleaseDownload: want nil, got %v", err)
	}

	var count int
	_ = db.QueryRow(`SELECT COUNT(*) FROM quota_usage WHERE user_id=? AND track_id=?`,
		"user6", "track6").Scan(&count)
	if count != 0 {
		t.Errorf("expected 0 rows after release, got %d", count)
	}
}

func TestTracker_ReleaseDownload_Nonexistent(t *testing.T) {
	db := setupTestDB(t)
	tracker := NewQuotaTracker(NewQuotaStorage(db))

	err := tracker.ReleaseDownload("user7", "no_such_track")
	if err != nil {
		t.Fatalf("releasing non-existent reservation: want nil, got %v", err)
	}
}

func TestTracker_ConfirmDownload_NonexistentReservation(t *testing.T) {
	db := setupTestDB(t)
	tracker := NewQuotaTracker(NewQuotaStorage(db))

	err := tracker.ConfirmDownload("user8", "no_reservation", 5)
	if err != nil {
		t.Fatalf("confirming non-existent reservation: want nil, got %v", err)
	}
}

func TestTracker_GetStatus_DelegatesToStorage(t *testing.T) {
	db := setupTestDB(t)
	tracker := NewQuotaTracker(NewQuotaStorage(db))

	_, err := db.Exec(`INSERT INTO premium_users (user_id, expires_at) VALUES (?,?)`,
		"prem_status", "2099-12-31 23:59:59")
	if err != nil {
		t.Fatal(err)
	}

	status, err := tracker.GetStatus("prem_status")
	if err != nil {
		t.Fatal(err)
	}
	if !status.IsPremium {
		t.Error("GetStatus: expected premium user")
	}
	if !status.CanDownload {
		t.Error("GetStatus: expected CanDownload=true for premium")
	}
}
