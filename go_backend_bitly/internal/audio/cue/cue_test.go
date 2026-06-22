package cue

import (
	"os"
	"path/filepath"
	"testing"
)

func TestCueSheetZeroValues(t *testing.T) {
	var s CueSheet
	if s.Performer != "" || s.Title != "" || s.FileName != "" {
		t.Error("expected zero values for string fields")
	}
	if s.Tracks != nil {
		t.Error("expected nil Tracks")
	}
}

func TestCueTrackZeroValues(t *testing.T) {
	var tr CueTrack
	if tr.Number != 0 || tr.StartTime != 0 || tr.PreGap != 0 {
		t.Error("expected zero values")
	}
	if tr.Title != "" || tr.Performer != "" {
		t.Error("expected empty strings")
	}
}

func TestCueSplitInfoZeroValues(t *testing.T) {
	var si CueSplitInfo
	if si.CuePath != "" || si.AudioPath != "" {
		t.Error("expected empty paths")
	}
	if si.Tracks != nil {
		t.Error("expected nil Tracks")
	}
}

func TestCueSplitTrackZeroValues(t *testing.T) {
	var st CueSplitTrack
	if st.Number != 0 || st.StartSec != 0 || st.EndSec != 0 {
		t.Error("expected zero values")
	}
	if st.Title != "" || st.Artist != "" {
		t.Error("expected empty strings")
	}
}

func TestParseCueFile_FileNotFound(t *testing.T) {
	_, err := ParseCueFile("/nonexistent/path.cue")
	if err == nil {
		t.Fatal("expected error for nonexistent file")
	}
}

func TestParseCueFile_ValidCue(t *testing.T) {
	content := []byte(`PERFORMER "Test Artist"
TITLE "Test Album"
FILE "test.flac" FLAC
  TRACK 01 AUDIO
    TITLE "First Track"
    PERFORMER "Test Artist"
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    TITLE "Second Track"
    PERFORMER "Test Artist"
    ISRC USABC1234567
    INDEX 01 03:30:00
`)

	dir := t.TempDir()
	cuePath := filepath.Join(dir, "test.cue")
	if err := os.WriteFile(cuePath, content, 0644); err != nil {
		t.Fatal(err)
	}

	sheet, err := ParseCueFile(cuePath)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if sheet.Performer != "Test Artist" {
		t.Errorf("Performer = %q, want %q", sheet.Performer, "Test Artist")
	}
	if sheet.Title != "Test Album" {
		t.Errorf("Title = %q, want %q", sheet.Title, "Test Album")
	}
	if sheet.FileName != "test.flac" {
		t.Errorf("FileName = %q, want %q", sheet.FileName, "test.flac")
	}
	if sheet.FileType != "FLAC" {
		t.Errorf("FileType = %q, want %q", sheet.FileType, "FLAC")
	}
	if len(sheet.Tracks) != 2 {
		t.Fatalf("expected 2 tracks, got %d", len(sheet.Tracks))
	}

	if sheet.Tracks[0].Number != 1 {
		t.Errorf("Track[0].Number = %d, want 1", sheet.Tracks[0].Number)
	}
	if sheet.Tracks[0].Title != "First Track" {
		t.Errorf("Track[0].Title = %q, want %q", sheet.Tracks[0].Title, "First Track")
	}
	if sheet.Tracks[0].StartTime != 0 {
		t.Errorf("Track[0].StartTime = %f, want 0", sheet.Tracks[0].StartTime)
	}

	if sheet.Tracks[1].Number != 2 {
		t.Errorf("Track[1].Number = %d, want 2", sheet.Tracks[1].Number)
	}
	if sheet.Tracks[1].ISRC != "USABC1234567" {
		t.Errorf("Track[1].ISRC = %q, want %q", sheet.Tracks[1].ISRC, "USABC1234567")
	}
	if sheet.Tracks[1].StartTime != 210 {
		t.Errorf("Track[1].StartTime = %f, want 210", sheet.Tracks[1].StartTime)
	}
}

func TestParseCueFile_MinimalCue(t *testing.T) {
	content := []byte(`PERFORMER "Artist"
TITLE "Album"
FILE "audio.flac" FLAC
  TRACK 01 AUDIO
    TITLE "Song"
    INDEX 01 00:00:00
`)

	dir := t.TempDir()
	cuePath := filepath.Join(dir, "minimal.cue")
	if err := os.WriteFile(cuePath, content, 0644); err != nil {
		t.Fatal(err)
	}

	sheet, err := ParseCueFile(cuePath)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(sheet.Tracks) != 1 {
		t.Errorf("expected 1 track, got %d", len(sheet.Tracks))
	}
}

func TestParseCueFile_EmptyCue(t *testing.T) {
	dir := t.TempDir()
	cuePath := filepath.Join(dir, "empty.cue")
	if err := os.WriteFile(cuePath, []byte(""), 0644); err != nil {
		t.Fatal(err)
	}

	_, err := ParseCueFile(cuePath)
	if err == nil {
		t.Error("expected error for empty cue file with no tracks")
	}
}

func TestParseCueFile_WithRemAndComments(t *testing.T) {
	content := []byte(`REM GENRE "Rock"
REM DATE "2024"
PERFORMER "The Band"
TITLE "Great Album"
FILE "music.flac" FLAC
  TRACK 01 AUDIO
    TITLE "Great Song"
    PERFORMER "The Band"
    INDEX 01 00:00:00
`)

	dir := t.TempDir()
	cuePath := filepath.Join(dir, "with_rem.cue")
	if err := os.WriteFile(cuePath, content, 0644); err != nil {
		t.Fatal(err)
	}

	sheet, err := ParseCueFile(cuePath)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(sheet.Tracks) != 1 {
		t.Errorf("expected 1 track, got %d", len(sheet.Tracks))
	}
}

func TestParseCueFile_DifferentFileTypes(t *testing.T) {
	tests := []struct {
		fileType string
	}{
		{"WAVE"},
		{"FLAC"},
		{"MP3"},
		{"AIFF"},
	}
	for _, tt := range tests {
		content := []byte("FILE \"test." + tt.fileType + "\" " + tt.fileType + "\n  TRACK 01 AUDIO\n    TITLE \"Test\"\n    INDEX 01 00:00:00\n")
		dir := t.TempDir()
		cuePath := filepath.Join(dir, "type.cue")
		if err := os.WriteFile(cuePath, content, 0644); err != nil {
			t.Fatal(err)
		}
		sheet, err := ParseCueFile(cuePath)
		if err != nil {
			t.Errorf("ParseCueFile with %s: %v", tt.fileType, err)
			continue
		}
		if len(sheet.Tracks) != 1 {
			t.Errorf("expected 1 track for %s, got %d", tt.fileType, len(sheet.Tracks))
		}
	}
}
func TestParseCueTimestamp_EdgeCases(t *testing.T) {
	t.Run("max values", func(t *testing.T) {
		got := parseCueTimestamp("99:59:74")
		if got != 99*60+59+74.0/75.0 {
			t.Errorf("got %f", got)
		}
	})
	t.Run("frame precision", func(t *testing.T) {
		got := parseCueTimestamp("00:00:01")
		want := 1.0 / 75.0
		if got != want {
			t.Errorf("got %f, want %f", got, want)
		}
	})
}

func TestUnquoteCue(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{`"Test Artist"`, "Test Artist"},
		{`  "Test Album"  `, "Test Album"},
		{`Unquoted Value`, "Unquoted Value"},
		{`""`, ""},
		{``, ""},
		{`"no closing quote`, `"no closing quote`}, // no closing quote - returned as-is
		{`quoted`, `quoted`}, // no quotes at all - returned as-is
	}
	for _, tt := range tests {
		got := unquoteCue(tt.input)
		if got != tt.want {
			t.Errorf("unquoteCue(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}

func TestParseCueFileLine(t *testing.T) {
	tests := []struct {
		input       string
		wantName    string
		wantType    string
	}{
		{`"test.flac" FLAC`, "test.flac", "FLAC"},
		{`"audio.wav" WAVE`, "audio.wav", "WAVE"},
		{`"file with spaces.mp3" MP3`, "file with spaces.mp3", "MP3"},
		{`noquotes.flac FLAC`, "noquotes.flac", "FLAC"},
		{`"/path/to/file.flac" FLAC`, "/path/to/file.flac", "FLAC"},
		{`"test.flac"`, "test.flac", ""},
	}
	for _, tt := range tests {
		name, ftype := parseCueFileLine(tt.input)
		if name != tt.wantName || ftype != tt.wantType {
			t.Errorf("parseCueFileLine(%q) = (%q, %q), want (%q, %q)", tt.input, name, ftype, tt.wantName, tt.wantType)
		}
	}
}

// --- Parse handler tests ---

func TestParseCueRemCommand(t *testing.T) {
	t.Run("GENRE at sheet level", func(t *testing.T) {
		sheet := &CueSheet{}
		parseCueRemCommand(`REM GENRE "Rock"`, sheet, nil)
		if sheet.Genre != "Rock" {
			t.Errorf("expected Genre=Rock, got %q", sheet.Genre)
		}
	})

	t.Run("DATE at sheet level", func(t *testing.T) {
		sheet := &CueSheet{}
		parseCueRemCommand(`REM DATE "2024"`, sheet, nil)
		if sheet.Date != "2024" {
			t.Errorf("expected Date=2024, got %q", sheet.Date)
		}
	})

	t.Run("COMMENT at sheet level", func(t *testing.T) {
		sheet := &CueSheet{}
		parseCueRemCommand(`REM COMMENT "Test comment"`, sheet, nil)
		if sheet.Comment != "Test comment" {
			t.Errorf("expected Comment, got %q", sheet.Comment)
		}
	})

	t.Run("COMPOSER at track level", func(t *testing.T) {
		sheet := &CueSheet{}
		track := &CueTrack{Number: 1}
		parseCueRemCommand(`REM COMPOSER "Track Composer"`, sheet, track)
		if track.Composer != "Track Composer" {
			t.Errorf("expected track.Composer, got %q", track.Composer)
		}
	})

	t.Run("COMPOSER at sheet level", func(t *testing.T) {
		sheet := &CueSheet{}
		parseCueRemCommand(`REM COMPOSER "Album Composer"`, sheet, nil)
		if sheet.Composer != "Album Composer" {
			t.Errorf("expected sheet.Composer, got %q", sheet.Composer)
		}
	})

	t.Run("unknown REM key", func(t *testing.T) {
		sheet := &CueSheet{}
		parseCueRemCommand(`REM UNKNOWN "value"`, sheet, nil)
		// Should not set anything, no panic
		if sheet.Genre != "" || sheet.Date != "" {
			t.Error("expected no changes for unknown REM key")
		}
	})

	t.Run("malformed REM line", func(t *testing.T) {
		sheet := &CueSheet{}
		parseCueRemCommand(`REM`, sheet, nil)
		// Should not panic
		if sheet.Genre != "" {
			t.Error("expected no changes for malformed REM")
		}
	})
}

func TestParseCuePerformer(t *testing.T) {
	t.Run("at sheet level", func(t *testing.T) {
		sheet := &CueSheet{}
		parseCuePerformer(`PERFORMER "Album Artist"`, sheet, nil)
		if sheet.Performer != "Album Artist" {
			t.Errorf("expected Album Artist, got %q", sheet.Performer)
		}
	})

	t.Run("at track level", func(t *testing.T) {
		sheet := &CueSheet{}
		sheet.Performer = "Album Artist"
		track := &CueTrack{Number: 1}
		parseCuePerformer(`PERFORMER "Track Artist"`, sheet, track)
		if track.Performer != "Track Artist" {
			t.Errorf("expected Track Artist, got %q", track.Performer)
		}
		if sheet.Performer != "Album Artist" {
			t.Errorf("sheet level should not change, got %q", sheet.Performer)
		}
	})
}

func TestParseCueTitle(t *testing.T) {
	t.Run("at sheet level", func(t *testing.T) {
		sheet := &CueSheet{}
		parseCueTitle(`TITLE "Album Title"`, sheet, nil)
		if sheet.Title != "Album Title" {
			t.Errorf("expected Album Title, got %q", sheet.Title)
		}
	})

	t.Run("at track level", func(t *testing.T) {
		sheet := &CueSheet{}
		track := &CueTrack{Number: 1}
		parseCueTitle(`TITLE "Track Title"`, sheet, track)
		if track.Title != "Track Title" {
			t.Errorf("expected Track Title, got %q", track.Title)
		}
		if sheet.Title != "" {
			t.Errorf("sheet level should not change, got %q", sheet.Title)
		}
	})
}

func TestParseCueFileEntry(t *testing.T) {
	sheet := &CueSheet{}
	parseCueFileEntry(`FILE "test.flac" FLAC`, sheet)
	if sheet.FileName != "test.flac" {
		t.Errorf("expected test.flac, got %q", sheet.FileName)
	}
	if sheet.FileType != "FLAC" {
		t.Errorf("expected FLAC, got %q", sheet.FileType)
	}
}

func TestParseCueTrack(t *testing.T) {
	t.Run("first track", func(t *testing.T) {
		sheet := &CueSheet{}
		track := parseCueTrack(`TRACK 01 AUDIO`, sheet, nil)
		if track == nil {
			t.Fatal("expected non-nil track")
		}
		if track.Number != 1 {
			t.Errorf("expected Number=1, got %d", track.Number)
		}
		if track.PreGap != -1 {
			t.Errorf("expected PreGap=-1, got %f", track.PreGap)
		}
		if len(sheet.Tracks) != 0 {
			t.Errorf("expected no tracks appended yet, got %d", len(sheet.Tracks))
		}
	})

	t.Run("second track appends first", func(t *testing.T) {
		sheet := &CueSheet{}
		first := parseCueTrack(`TRACK 01 AUDIO`, sheet, nil)
		second := parseCueTrack(`TRACK 02 AUDIO`, sheet, first)
		if second == nil {
			t.Fatal("expected non-nil second track")
		}
		if len(sheet.Tracks) != 1 {
			t.Errorf("expected 1 appended track, got %d", len(sheet.Tracks))
		}
		if sheet.Tracks[0].Number != 1 {
			t.Errorf("expected appended track number 1, got %d", sheet.Tracks[0].Number)
		}
	})

	t.Run("track number parsing with extra fields", func(t *testing.T) {
		sheet := &CueSheet{}
		track := parseCueTrack(`TRACK 01 AUDIO`, sheet, nil)
		if track.Number != 1 {
			t.Errorf("expected Number=1, got %d", track.Number)
		}
	})

	t.Run("track number missing defaults to 0", func(t *testing.T) {
		sheet := &CueSheet{}
		track := parseCueTrack(`TRACK`, sheet, nil)
		if track.Number != 0 {
			t.Errorf("expected Number=0, got %d", track.Number)
		}
	})
}

func TestParseCueIndex(t *testing.T) {
	t.Run("INDEX 01 sets start time", func(t *testing.T) {
		track := &CueTrack{Number: 1, PreGap: -1}
		parseCueIndex(`INDEX 01 00:30:00`, track)
		if track.StartTime != 30 {
			t.Errorf("expected StartTime=30, got %f", track.StartTime)
		}
	})

	t.Run("INDEX 00 sets pre-gap", func(t *testing.T) {
		track := &CueTrack{Number: 1, PreGap: -1}
		parseCueIndex(`INDEX 00 00:02:00`, track)
		if track.PreGap != 2 {
			t.Errorf("expected PreGap=2, got %f", track.PreGap)
		}
	})

	t.Run("malformed index line", func(t *testing.T) {
		track := &CueTrack{Number: 1, PreGap: -1}
		parseCueIndex(`INDEX`, track)
		if track.PreGap != -1 || track.StartTime != 0 {
			t.Error("expected no changes for malformed INDEX")
		}
	})

	t.Run("INDEX with different index number", func(t *testing.T) {
		track := &CueTrack{Number: 1, PreGap: -1}
		parseCueIndex(`INDEX 02 00:05:00`, track)
		if track.PreGap != -1 || track.StartTime != 0 {
			t.Error("expected no changes for INDEX 02")
		}
	})
}

func TestParseCueISRC(t *testing.T) {
	track := &CueTrack{Number: 1}
	parseCueISRC(`ISRC USABC1234567`, track)
	if track.ISRC != "USABC1234567" {
		t.Errorf("expected USABC1234567, got %q", track.ISRC)
	}
}

func TestParseCueSongwriter(t *testing.T) {
	t.Run("at track level", func(t *testing.T) {
		sheet := &CueSheet{}
		track := &CueTrack{Number: 1}
		parseCueSongwriter(`SONGWRITER "Track Writer"`, sheet, track)
		if track.Composer != "Track Writer" {
			t.Errorf("expected track.Composer, got %q", track.Composer)
		}
	})

	t.Run("at sheet level", func(t *testing.T) {
		sheet := &CueSheet{}
		parseCueSongwriter(`SONGWRITER "Album Writer"`, sheet, nil)
		if sheet.Composer != "Album Writer" {
			t.Errorf("expected sheet.Composer, got %q", sheet.Composer)
		}
	})
}

