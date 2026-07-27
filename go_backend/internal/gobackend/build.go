package gobackend

import (
	"fmt"
	"runtime"
)

// BuildInfo holds details about the current build.
type BuildInfo struct {
	GoVersion  string `json:"goVersion"`
	GOOS       string `json:"goos"`
	GOARCH     string `json:"goarch"`
	BackendVer string `json:"backendVersion"`
}

// GetBuildInfo returns build metadata for Flutter.
func GetBuildInfo() BuildInfo {
	return BuildInfo{
		GoVersion:  runtime.Version(),
		GOOS:       runtime.GOOS,
		GOARCH:     runtime.GOARCH,
		BackendVer: "1.0.0",
	}
}

// Platform returns a human-readable platform string.
func Platform() string {
	return fmt.Sprintf("%s/%s", runtime.GOOS, runtime.GOARCH)
}

// IsMobile returns true if running on Android or iOS.
func IsMobile() bool {
	return runtime.GOOS == "android" || runtime.GOOS == "ios"
}

// IsDesktop returns true if running on Windows, macOS, or Linux.
func IsDesktop() bool {
	return runtime.GOOS == "windows" || runtime.GOOS == "darwin" || runtime.GOOS == "linux"
}
