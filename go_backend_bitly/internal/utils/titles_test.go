package utils

import "testing"

func TestTitlesMatch(t *testing.T) {
	tests := []struct {
		name     string
		expected string
		found    string
		want     bool
	}{
		{"exact match", "Song Title", "Song Title", true},
		{"case insensitive", "Song Title", "song title", true},
		{"trim spaces", "  Song Title  ", "Song Title", true},
		{"substring match", "Song Title (Remastered)", "Song Title", true},
		{"clean parenthesized version", "Song Title (Remastered)", "Song Title (Deluxe)", true},
		{"clean bracketed version", "Song Title [Remix]", "Song Title", true},
		{"core title before dash", "Song Title - Live", "Song Title", true},
		{"loose match punctuation", "Hello, World!", "Hello World", true},
		{"no match", "Song Title", "Different Song", false},
		{"empty strings match via contains", "", "", true},
		{"one empty matches via contains", "Song", "", true},
		{"slash separator", "Song/Title", "Song Title", true},
		{"underscore separator", "Song_Title", "Song Title", true},
		{"ampersand no match", "Rock & Roll", "Rock and Roll", false},
		{"parenthesized non-version kept", "Song (Original)", "Song (Original)", true},
		{"multiple spaces normalized", "Song   Title", "Song Title", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := TitlesMatch(tt.expected, tt.found)
			if got != tt.want {
				t.Errorf("TitlesMatch(%q, %q) = %v, want %v", tt.expected, tt.found, got, tt.want)
			}
		})
	}
}

func TestNormalizeLooseTitle(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  string
	}{
		{"empty string", "", ""},
		{"only spaces", "   ", ""},
		{"lowercase", "Hello World", "hello world"},
		{"remove punctuation", "Hello, World!", "hello world"},
		{"accents kept", "Söng Títle", "söng títle"},
		{"slash to space", "Song/Title", "song title"},
		{"backslash to space", "Song\\Title", "song title"},
		{"underscore to space", "Song_Title", "song title"},
		{"dash to space", "Song-Title", "song title"},
		{"pipe to space", "Song|Title", "song title"},
		{"dot to space", "Song.Title", "song title"},
		{"ampersand to space", "Rock&Roll", "rock roll"},
		{"plus to space", "Rock+Roll", "rock roll"},
		{"numbers kept", "Song 2024", "song 2024"},
		{"multiple spaces collapsed", "Song   Title", "song title"},
		{"leading trailing spaces", "  Song Title  ", "song title"},
		{"mixed separators", "Song/Title_Remix", "song title remix"},
		{"no changes needed", "songtitle", "songtitle"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := NormalizeLooseTitle(tt.input)
			if got != tt.want {
				t.Errorf("NormalizeLooseTitle(%q) = %q, want %q", tt.input, got, tt.want)
			}
		})
	}
}

func TestCleanTitle(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  string
	}{
		{"no version indicators", "Song Title", "Song Title"},
		{"remove parenthesized remaster", "Song Title (Remastered)", "Song Title"},
		{"remove parenthesized deluxe", "Song Title (Deluxe Edition)", "Song Title"},
		{"remove bracketed remix", "Song Title [Remix]", "Song Title"},
		{"remove bracketed live", "Song Title [Live]", "Song Title"},
		{"remove parenthesized bonus", "Song Title (Bonus Track)", "Song Title"},
		{"keep non-version parens", "Song (Original)", "Song (Original)"},
		{"keep non-version brackets", "Song [Nice]", "Song [Nice]"},
		{"multiple version indicators", "Song (Remastered) [Deluxe]", "Song"},
		{"no version patterns", "Hello World", "Hello World"},
		{"already clean", "hello world", "hello world"},
		{"dash remaster suffix", "Song - remaster", "Song"},
		{"dash radio edit suffix", "Song - radio edit", "Song"},
		{"dash single version suffix", "Song - single version", "Song"},
		{"dash live suffix", "Song - live", "Song"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := CleanTitle(tt.input)
			if got != tt.want {
				t.Errorf("CleanTitle(%q) = %q, want %q", tt.input, got, tt.want)
			}
		})
	}
}

func TestExtractCoreTitle(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  string
	}{
		{"no separators", "song title", "song title"},
		{"cut at paren", "song title (remastered)", "song title"},
		{"cut at bracket", "song title [live]", "song title"},
		{"cut at dash", "song title - live", "song title"},
		{"paren wins over dash", "song (live) - edit", "song"},
		{"bracket wins over dash", "song [live] - edit", "song"},
		{"dash wins if only separator", "song - remix", "song"},
		{"no cut if no separator", "hello world", "hello world"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ExtractCoreTitle(tt.input)
			if got != tt.want {
				t.Errorf("ExtractCoreTitle(%q) = %q, want %q", tt.input, got, tt.want)
			}
		})
	}
}
