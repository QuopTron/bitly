package provider

import (
	"strings"
	"testing"
)

// rawExtLyricsResult mimics what goja exports for a SpotiFLAC ExtLyricsResult
// (numbers come back as float64, nested slices as []interface{}).
func rawExtLyricsResult() map[string]interface{} {
	return map[string]interface{}{
		"syncType":     "LINE_SYNCED",
		"instrumental": false,
		"provider":     "Apple Music",
		"plainLyrics":  "Primera linea\nSegunda linea",
		"lines": []interface{}{
			map[string]interface{}{
				"startTimeMs": float64(12_340),
				"words":       "<00:12>Primera <00:13>linea\n[bg:<00:12>coro]",
				"endTimeMs":   float64(15_000),
			},
			map[string]interface{}{
				"startTimeMs": float64(16_700),
				"words":       "<00:16>Segunda <00:17>linea",
				"endTimeMs":   float64(19_000),
			},
			// Translation block appended with the far-future sentinel — dropped.
			map[string]interface{}{
				"startTimeMs": float64(999_999_999),
				"words":       "Traduccion",
				"endTimeMs":   float64(999_999_999),
			},
		},
	}
}

func TestExtLyricsResultToLyrics(t *testing.T) {
	lyr, err := extLyricsResultToLyrics(rawExtLyricsResult())
	if err != nil {
		t.Fatalf("extLyricsResultToLyrics: %v", err)
	}
	// Las marcas de palabra/sílaba SE CONSERVAN (enhanced LRC): el karaoke de la
	// app resalta cada una en su tiempo. El bloque de coros `[bg:...]` sigue
	// afuera, y el texto plano sigue sin marcas.
	wantSynced := "[00:12.34]<00:12>Primera <00:13>linea\n[00:16.70]<00:16>Segunda <00:17>linea"
	if lyr.SyncedLyrics != wantSynced {
		t.Errorf("synced lyrics:\n got %q\nwant %q", lyr.SyncedLyrics, wantSynced)
	}
	if lyr.PlainLyrics != "Primera linea\nSegunda linea" {
		t.Errorf("plain lyrics = %q", lyr.PlainLyrics)
	}
	if !strings.Contains(lyr.Source, "Apple Music") {
		t.Errorf("source = %q", lyr.Source)
	}
}

// Una línea SIN marcas de palabra debe salir idéntica a antes: conservar marcas
// es una mejora aditiva, no un cambio de formato para todas las fuentes.
func TestExtLyricsResultToLyrics_SinMarcasNoCambia(t *testing.T) {
	lyr, err := extLyricsResultToLyrics(map[string]interface{}{
		"provider": "Apple Music",
		"lines": []interface{}{
			map[string]interface{}{
				"startTimeMs": float64(5_000),
				"words":       "Sin marcas de tiempo",
			},
		},
	})
	if err != nil {
		t.Fatalf("extLyricsResultToLyrics: %v", err)
	}
	if want := "[00:05.00]Sin marcas de tiempo"; lyr.SyncedLyrics != want {
		t.Errorf("synced = %q, want %q", lyr.SyncedLyrics, want)
	}
}

// El bloque de coros no puede colarse al karaoke: sus marcas son de voces de
// fondo y el resaltado de la voz principal quedaría saltando entre ambos.
func TestMarcarPalabras_DescartaBloqueDeCoros(t *testing.T) {
	got, ok := marcarPalabras("<00:12>Hola <00:13>mundo\n[bg:<00:12>ooo]")
	if !ok {
		t.Fatal("debió detectar marcas de palabra")
	}
	if got != "<00:12>Hola <00:13>mundo" {
		t.Errorf("marcarPalabras = %q", got)
	}
	if _, ok := marcarPalabras("texto sin marcas"); ok {
		t.Fatal("no debía reportar marcas")
	}
}

func TestExtLyricsResultToLyrics_NoLines(t *testing.T) {
	if _, err := extLyricsResultToLyrics(map[string]interface{}{"lines": []interface{}{}}); err == nil {
		t.Fatal("expected error for empty lines")
	}
	if _, err := extLyricsResultToLyrics(nil); err == nil {
		t.Fatal("expected error for nil result")
	}
}

func TestExtLyricsResultToLyrics_StripsWordMarkers(t *testing.T) {
	clean := cleanLyricWords("<00:12>Palabra <00:13>dos\n[bg:<00:12>vocal]")
	if clean != "Palabra dos" {
		t.Errorf("cleanLyricWords = %q", clean)
	}
}
