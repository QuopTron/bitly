package provider

import (
	"encoding/json"
	"fmt"
	"regexp"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend/internal/lyrics"
)

// ─── Extension lyrics provider (SpotiFLAC lyrics_provider contract) ─────────
//
// Extensions may export `fetchLyrics(trackName, artistName, albumName,
// durationSec)` returning a SpotiFLAC ExtLyricsResult:
//
//	{
//	  lines: [{ startTimeMs, words, endTimeMs }],   // words carry inline
//	                                                 // <MM:SS.cc> word markers
//	  syncType: "LINE_SYNCED" | "WORD_SYNCED",
//	  instrumental: false,
//	  plainLyrics: "...",
//	  provider: "Apple Music"
//	}
//
// The Go lyrics client only knows line-level LRC + plain text, so we convert
// here: each timed line becomes `[MM:SS.cc]` + the line text. Las marcas inline
// `<MM:SS.cc>` de cada palabra/sílaba SE CONSERVAN (enhanced LRC): el modal
// karaoke de la app las resalta una por una. Antes se borraban, así que una
// fuente que SÍ traía el tiempo de cada palabra caía al barrido uniforme por
// caracteres — se perdía el karaoke real sin ganar nada. Translation /
// romanization blocks (emitted with a sentinel 999999999 start) are dropped —
// the player's synced-LRC renderer has no place for them.

// HasLyricsProvider reports whether the extension exports fetchLyrics.
func (p *ExtensionProvider) HasLyricsProvider() bool {
	if p == nil || p.runtime == nil {
		return false
	}
	return p.runtime.HasMethod(p.extID, "fetchLyrics")
}

// FetchLyrics calls the extension's fetchLyrics under its own "lyrics" cooldown
// bucket, so a lyrics failure (missing auth, 429, no match) never disables the
// extension's search/download/playback. A nil result or method-level miss is
// reported as "no lyrics" so the client keeps walking the fallback chain.
func (p *ExtensionProvider) FetchLyrics(trackName, artistName string, durationMs int) (*lyrics.Lyrics, error) {
	if trackName == "" || artistName == "" {
		return nil, fmt.Errorf("ext %s: no lyrics (missing track/artist)", p.extID)
	}
	res, err := p.callOp("lyrics", "fetchLyrics", trackName, artistName, "", durationMs/1000)
	if err != nil {
		return nil, fmt.Errorf("ext %s: no lyrics: %w", p.extID, err)
	}
	if res == nil {
		return nil, fmt.Errorf("ext %s: no lyrics", p.extID)
	}
	lyr, err := extLyricsResultToLyrics(res)
	if err != nil {
		return nil, fmt.Errorf("ext %s: %w", p.extID, err)
	}
	return lyr, nil
}

type extLyricsLine struct {
	StartTimeMs int64  `json:"startTimeMs"`
	Words       string `json:"words"`
	EndTimeMs   int64  `json:"endTimeMs"`
}

type extLyricsResult struct {
	Lines        []extLyricsLine `json:"lines"`
	SyncType     string          `json:"syncType"`
	Instrumental bool            `json:"instrumental"`
	PlainLyrics  string          `json:"plainLyrics"`
	Provider     string          `json:"provider"`
}

var (
	inlineWordMarker = regexp.MustCompile(`<\d{1,2}:\d{2}(?:\.\d+)?>`)
	// Translation/romanization sections are appended by extensions with a
	// sentinel far-future start time.
	lyricsSentinelStart = int64(999_000_000)
)

// extLyricsResultToLyrics converts a SpotiFLAC ExtLyricsResult (as exported by
// the JS sandbox) into the app's line-level LRC + plain lyrics.
func extLyricsResultToLyrics(res interface{}) (*lyrics.Lyrics, error) {
	raw, err := json.Marshal(res)
	if err != nil {
		return nil, fmt.Errorf("lyrics: marshal extension result: %w", err)
	}
	var ext extLyricsResult
	if err := json.Unmarshal(raw, &ext); err != nil {
		return nil, fmt.Errorf("lyrics: unmarshal extension result: %w", err)
	}
	if len(ext.Lines) == 0 {
		return nil, fmt.Errorf("no lyrics")
	}

	var synced []string
	plainParts := []string{}
	for _, line := range ext.Lines {
		if line.StartTimeMs < 0 || line.StartTimeMs >= lyricsSentinelStart {
			continue
		}
		text := cleanLyricWords(line.Words)
		if text == "" {
			continue
		}
		// Con tiempos por palabra la línea viaja CON sus marcas; el texto plano
		// sigue sin ellas (es lo que se muestra cuando no hay nada sincronizado).
		linea := text
		if conMarcas, ok := marcarPalabras(line.Words); ok {
			linea = conMarcas
		}
		t := time.Duration(line.StartTimeMs) * time.Millisecond
		mm := t / time.Minute
		ss := (t % time.Minute) / time.Second
		cc := (t % time.Second) / (10 * time.Millisecond)
		synced = append(synced, fmt.Sprintf("[%02d:%02d.%02d]%s", mm, ss, cc, linea))
		plainParts = append(plainParts, text)
	}
	if len(synced) == 0 {
		return nil, fmt.Errorf("no lyrics")
	}

	out := &lyrics.Lyrics{
		SyncedLyrics: strings.Join(synced, "\n"),
		PlainLyrics:  strings.TrimSpace(ext.PlainLyrics),
		Source:       "ext-" + strings.TrimSpace(ext.Provider),
	}
	if out.PlainLyrics == "" {
		out.PlainLyrics = strings.Join(plainParts, "\n")
	}
	return out, nil
}

// marcarPalabras devuelve el texto de la línea CONSERVANDO las marcas inline de
// palabra/sílaba (`<MM:SS.cc>`) y el segundo valor indica si las tiene. Sirve
// para el LRC enriquecido del karaoke: el renderizador de la app resalta cada
// palabra en su tiempo (y cae al barrido uniforme cuando no hay marcas, así que
// conservarlas nunca empeora una línea sin ellas).
//
// El bloque de coros `[bg:...]` —que la extensión agrega DESPUÉS de un salto de
// línea— se descarta igual que en el texto limpio: sus marcas son de voces de
// fondo y no deben pisar el resaltado de la voz principal.
func marcarPalabras(words string) (string, bool) {
	main := words
	if idx := strings.IndexByte(main, '\n'); idx >= 0 {
		main = main[:idx]
	}
	if !inlineWordMarker.MatchString(main) {
		return "", false
	}
	main = strings.ReplaceAll(main, "[bg:", " ")
	main = strings.ReplaceAll(main, "]", " ")
	return strings.TrimSpace(main), true
}

// cleanLyricWords drops enhanced-LRC word markers (`<MM:SS.cc>`) and the
// background-vocal `[bg:...]` block the Apple Music extension appends after a
// newline, leaving clean display text for the karaoke line.
func cleanLyricWords(words string) string {
	main := words
	if idx := strings.IndexByte(main, '\n'); idx >= 0 {
		main = main[:idx]
	}
	main = inlineWordMarker.ReplaceAllString(main, "")
	main = strings.ReplaceAll(main, "[bg:", " ")
	main = strings.ReplaceAll(main, "]", " ")
	return strings.TrimSpace(main)
}
