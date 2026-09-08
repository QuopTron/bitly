package extensions

import (
	"strings"
	"time"

	"github.com/dop251/goja"
	"github.com/zarz/bitly/go_backend/internal/audio"
	"github.com/zarz/bitly/go_backend/internal/lyrics"
)

// registrarGlobalGobackend construye el objeto `gobackend` que expone a las
// extensiones una API compatible SpotiFLAC-Mobile: hora local, saludo,
// calidad de audio leída de un archivo, letras LRC e ISRC ya descargado.
func registrarGlobalGobackend(vm *goja.Runtime) {
	// gobackend global - provides SpotiFLAC-Mobile compatible API for extensions
	gobackendObj := vm.NewObject()

	// getLocalTime() returns current local time info
	// SpotiFLAC-Mobile extensions expect: hour, minute, second, timezone, offsetMinutes
	_ = gobackendObj.Set("getLocalTime", func() map[string]interface{} {
		now := time.Now()
		_, offsetSec := now.Zone()
		return map[string]interface{}{
			"hour":          now.Hour(),
			"minute":        now.Minute(),
			"second":        now.Second(),
			"timezone":      now.Location().String(),
			"offsetMinutes": offsetSec / 60,
		}
	})

	// getGreeting() returns time-based greeting
	_ = gobackendObj.Set("getGreeting", func() string {
		h := time.Now().Hour()
		switch {
		case h < 12:
			return "Buenos días"
		case h < 18:
			return "Buenas tardes"
		default:
			return "Buenas noches"
		}
	})

	// getAudioQuality(path) reads audio quality metadata from a downloaded file.
	// Extensions (Tidal, Qobuz) use it to verify the acquired quality before
	// finalizing a download.
	_ = gobackendObj.Set("getAudioQuality", func(call goja.FunctionCall) goja.Value {
		if len(call.Arguments) < 1 {
			return vm.ToValue(map[string]interface{}{"error": "file path is required"})
		}
		path := call.Argument(0).String()
		meta, err := audio.ReadFileMetadata(path)
		if err != nil {
			return vm.ToValue(map[string]interface{}{"error": err.Error()})
		}
		return vm.ToValue(map[string]interface{}{
			"bitDepth":   meta.BitDepth,
			"sampleRate": meta.SampleRate,
			"duration":   meta.DurationMs,
			"codec":      meta.Format,
		})
	})

	// getLyricsLRC(spotifyID, trackName, artistName, filePath, durationMs)
	// returns synced (or plain) lyrics for the track, embedding the instrumental
	// sentinel when there are none — the same contract the player consumes.
	_ = gobackendObj.Set("getLyricsLRC", func(call goja.FunctionCall) goja.Value {
		if len(call.Arguments) < 3 {
			return vm.ToValue(map[string]interface{}{"error": "spotifyID, trackName and artistName are required"})
		}
		trackName := strings.TrimSpace(call.Arguments[1].String())
		artistName := strings.TrimSpace(call.Arguments[2].String())
		var durationMs int
		if len(call.Arguments) > 4 && !goja.IsUndefined(call.Arguments[4]) && !goja.IsNull(call.Arguments[4]) {
			durationMs = int(call.Arguments[4].ToInteger())
		}
		lyr, err := lyrics.NewClient().GetLyrics(trackName, artistName, durationMs)
		if err != nil || lyr == nil {
			return vm.ToValue(map[string]interface{}{"lyrics": "[instrumental:true]"})
		}
		text := lyr.SyncedLyrics
		if text == "" {
			text = lyr.PlainLyrics
		}
		if text == "" {
			text = "[instrumental:true]"
		}
		return vm.ToValue(map[string]interface{}{"lyrics": text})
	})

	// checkISRCExists(outputDir, isrc) returns the path of an already-downloaded
	// file in [outputDir] whose metadata ISRC matches, so extensions can skip
	// re-downloading duplicates.
	_ = gobackendObj.Set("checkISRCExists", func(call goja.FunctionCall) goja.Value {
		if len(call.Arguments) < 2 {
			return vm.ToValue(map[string]interface{}{"error": "outputDir and isrc are required"})
		}
		outputDir := strings.TrimSpace(call.Arguments[0].String())
		isrc := strings.TrimSpace(call.Arguments[1].String())
		if outputDir == "" || isrc == "" {
			return vm.ToValue(map[string]interface{}{"error": "outputDir and isrc are required"})
		}
		filePath, exists := verificarISRCEnDir(outputDir, isrc)
		return vm.ToValue(map[string]interface{}{"exists": exists, "filePath": filePath})
	})

	vm.Set("gobackend", gobackendObj)
}
