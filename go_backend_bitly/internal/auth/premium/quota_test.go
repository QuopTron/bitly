package premium

import "testing"

func TestCanDownloadMinutes_Premium_AlwaysTrue(t *testing.T) {
	q := &QuotaStatus{
		IsPremium: true,
	}
	if !q.CanDownloadMinutes(100500) {
		t.Error("expected premium to allow any duration")
	}
}

func TestCanDownloadMinutes_Premium_ZeroDuration(t *testing.T) {
	q := &QuotaStatus{
		IsPremium: true,
	}
	if !q.CanDownloadMinutes(0) {
		t.Error("expected premium to allow zero duration")
	}
}

func TestCanDownloadMinutes_NonPremium_EnoughRemaining(t *testing.T) {
	q := &QuotaStatus{
		IsPremium:        false,
		RemainingMinutes: 620,
	}
	if !q.CanDownloadMinutes(10) {
		t.Error("expected download allowed when remaining >= minutes")
	}
}

func TestCanDownloadMinutes_NonPremium_ExactRemaining(t *testing.T) {
	q := &QuotaStatus{
		IsPremium:        false,
		RemainingMinutes: 5,
	}
	if !q.CanDownloadMinutes(5) {
		t.Error("expected download allowed when remaining == minutes")
	}
}

func TestCanDownloadMinutes_NonPremium_InsufficientRemaining(t *testing.T) {
	q := &QuotaStatus{
		IsPremium:        false,
		RemainingMinutes: 5,
	}
	if q.CanDownloadMinutes(10) {
		t.Error("expected download denied when remaining < minutes")
	}
}

func TestCanDownloadMinutes_NonPremium_ZeroRemaining(t *testing.T) {
	q := &QuotaStatus{
		IsPremium:        false,
		RemainingMinutes: 0,
	}
	if q.CanDownloadMinutes(1) {
		t.Error("expected download denied when remaining is zero")
	}
}

func TestCanDownloadMinutes_NonPremium_NegativeRemaining(t *testing.T) {
	q := &QuotaStatus{
		IsPremium:        false,
		RemainingMinutes: -5,
	}
	if q.CanDownloadMinutes(0) {
		t.Error("expected download denied when remaining is negative")
	}
}

func TestCanDownloadMinutes_FloatPrecision(t *testing.T) {
	q := &QuotaStatus{
		IsPremium:        false,
		RemainingMinutes: 0.5,
	}
	if !q.CanDownloadMinutes(0.5) {
		t.Error("expected download allowed for equal float values")
	}
	if q.CanDownloadMinutes(0.5000001) {
		t.Error("expected download denied when remaining is slightly less")
	}
}

func TestCanDownloadMinutes_Premium_NegativeRemaining(t *testing.T) {
	q := &QuotaStatus{
		IsPremium:        true,
		RemainingMinutes: -1,
	}
	if !q.CanDownloadMinutes(100) {
		t.Error("expected premium to allow download even with negative remaining")
	}
}
