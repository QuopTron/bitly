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
	wantSynced := "[00:12.34]Primera linea\n[00:16.70]Segunda linea"
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
