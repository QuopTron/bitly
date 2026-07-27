package gobackend

import (
	"runtime"
	"testing"
)

func TestGetBuildInfo(t *testing.T) {
	t.Run("fields", func(t *testing.T) {
		info := GetBuildInfo()
		if info.GoVersion == "" {
			t.Error("expected non-empty GoVersion")
		}
		if info.BackendVer != "1.0.0" {
			t.Errorf("expected 1.0.0, got %s", info.BackendVer)
		}
		if info.GOOS != runtime.GOOS {
			t.Errorf("expected %s, got %s", runtime.GOOS, info.GOOS)
		}
		if info.GOARCH != runtime.GOARCH {
			t.Errorf("expected %s, got %s", runtime.GOARCH, info.GOARCH)
		}
	})
}

func TestPlatform(t *testing.T) {
	plat := Platform()
	expected := runtime.GOOS + "/" + runtime.GOARCH
	if plat != expected {
		t.Errorf("expected %s, got %s", expected, plat)
	}
}

func TestIsMobile(t *testing.T) {
	expected := runtime.GOOS == "android" || runtime.GOOS == "ios"
	if IsMobile() != expected {
		t.Errorf("expected %v on %s", expected, runtime.GOOS)
	}
}

func TestIsDesktop(t *testing.T) {
	expected := runtime.GOOS == "windows" || runtime.GOOS == "darwin" || runtime.GOOS == "linux"
	if IsDesktop() != expected {
		t.Errorf("expected %v on %s", expected, runtime.GOOS)
	}
}
