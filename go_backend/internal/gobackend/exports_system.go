package gobackend

import (
	"encoding/json"
	"os"
	"path/filepath"

	core "github.com/zarz/bitly/go_backend/internal/core"
)

// =========================================================================
// SYSTEM
// =========================================================================

func Ping() string                 { return "pong" }
func GetBuildInfo() string         { d, _ := json.Marshal(core.GetBuildInfo()); return string(d) }
func GetPlatform() string          { return core.Platform() }
func IsMobile() bool               { return core.IsMobile() }
func InitBackend() error           { return core.InitBackend() }
func CloseBackend()                { core.CloseBackend() }
func SetFlutterCallback(id string) { flutterCallbackID = id }
func GetCallbackID() string        { return flutterCallbackID }

// SetAppDataDir points the backend at the host app's writable data dir
// (Android: Context.getFilesDir()). On Android os.UserConfigDir() is not
// usable, so without this yt-dlp/ffmpeg can never be installed and the native
// youtube provider silently fails to stream. Must be called before
// InitGlobalState.
func SetAppDataDir(appDataDir string) {
	if appDataDir == "" {
		return
	}
	os.Setenv("BITLY_BIN_DIR", filepath.Join(appDataDir, "bin"))
	os.Setenv("BITLY_EXT_DIR", filepath.Join(appDataDir, "extensions"))
	os.Setenv("BITLY_DATA_DIR", filepath.Join(appDataDir, "ext_data"))
}
