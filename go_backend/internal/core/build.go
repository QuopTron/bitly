package core

import (
	"fmt"
	"runtime"
)

// Version y BuildDate se inyectan en el build con:
//
//	ldflags "-X github.com/zarz/bitly/go_backend/internal/core.Version=…"
//
// Antes los scripts pasaban `-X main.version=…`, pero package main no tenía
// esas variables: Go las ignoraba en silencio y el binario siempre reportaba
// "1.0.0". (OJO: si se cambia el path, cambia también build.sh/build_all.sh.)
var (
	Version   = "1.0.0"
	BuildDate = ""
)

// BuildInfo holds details about the current build.
type BuildInfo struct {
	GoVersion  string `json:"goVersion"`
	GOOS       string `json:"goos"`
	GOARCH     string `json:"goarch"`
	BackendVer string `json:"backendVersion"`
	BuildDate  string `json:"buildDate,omitempty"`
}

// GetBuildInfo returns build metadata for Flutter.
func GetBuildInfo() BuildInfo {
	return BuildInfo{
		GoVersion:  runtime.Version(),
		GOOS:       runtime.GOOS,
		GOARCH:     runtime.GOARCH,
		BackendVer: Version,
		BuildDate:  BuildDate,
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
