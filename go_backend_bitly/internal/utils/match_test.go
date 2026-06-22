package utils

import "testing"

func TestArtistsMatch(t *testing.T) {
	tests := []struct {
		name           string
		expectedArtist string
		foundArtist    string
		want           bool
	}{
		{"exact match", "Artist Name", "Artist Name", true},
		{"case insensitive", "Artist Name", "artist name", true},
		{"trim spaces", "  Artist Name  ", "Artist Name", true},
		{"accents normalized", "José", "Jose", true},
		{"diacritics removed", "Mötley Crüe", "Motley Crue", true},
		{"special ß to ss", "Straße", "Strasse", true},
		{"special æ to ae", "Encyclopædia", "Encyclopaedia", true},
		{"special œ to oe", "Cœur", "Coeur", true},
		{"special đ to dj", "Đorđe", "Djordje", true},
		{"punctuation removed", "Artist, Name", "Artist Name", true},
		{"slash separated", "Artist/Name", "Artist Name", true},
		{"dash separated", "Artist-Name", "Artist Name", true},
		{"underscore separated", "Artist_Name", "Artist Name", true},
		{"dot separated", "Artist.Name", "Artist Name", true},
		{"ampersand separated", "Rock&Roll", "Rock Roll", true},
		{"feat split matching", "Main Artist feat. Guest", "Guest", true},
		{"ft split matching", "Main Artist ft. Guest", "Guest", true},
		{"and split matching", "A and B", "A", true},
		{"comma split matching", "A, B", "A", true},
		{"different artists no match", "Artist One", "Artist Two", false},
		{"empty strings match", "", "", true},
		{"empty expected matches via contains", "", "Artist", true},
		{"empty found matches via contains", "Artist", "", true},
		{"same words unordered", "A B C", "C B A", true},
		{"substring match despite different length", "A B", "A B C", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ArtistsMatch(tt.expectedArtist, tt.foundArtist)
			if got != tt.want {
				t.Errorf("ArtistsMatch(%q, %q) = %v, want %v",
					tt.expectedArtist, tt.foundArtist, got, tt.want)
			}
		})
	}
}

func TestNormalizeLooseArtistName(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  string
	}{
		{"empty string", "", ""},
		{"only spaces", "   ", ""},
		{"lowercase", "Artist Name", "artist name"},
		{"diacritics decomposed", "José", "jose"},
		{"special đ", "Đorđe", "djordje"},
		{"special ß", "Straße", "strasse"},
		{"special æ", "Encyclopædia", "encyclopaedia"},
		{"special œ", "Cœur", "coeur"},
		{"punctuation removed", "Hello, World!", "hello world"},
		{"slash to space", "A/B", "a b"},
		{"backslash to space", "A\\B", "a b"},
		{"dash to space", "A-B", "a b"},
		{"underscore to space", "A_B", "a b"},
		{"pipe to space", "A|B", "a b"},
		{"dot to space", "A.B", "a b"},
		{"ampersand to space", "A&B", "a b"},
		{"plus to space", "A+B", "a b"},
		{"numbers kept", "Artist 2024", "artist 2024"},
		{"multiple spaces collapsed", "A   B", "a b"},
		{"mixed Unicode", "Mötley Crüe", "motley crue"},
		{"Spanish ñ", "Niño", "nino"},
		{"German umlaut", "München", "munchen"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := NormalizeLooseArtistName(tt.input)
			if got != tt.want {
				t.Errorf("NormalizeLooseArtistName(%q) = %q, want %q", tt.input, got, tt.want)
			}
		})
	}
}

func TestSameWordsUnordered(t *testing.T) {
	tests := []struct {
		name string
		a    string
		b    string
		want bool
	}{
		{"same order", "a b c", "a b c", true},
		{"reversed order", "a b c", "c b a", true},
		{"shuffled order", "a b c", "b a c", true},
		{"different lengths", "a b", "a b c", false},
		{"different words", "a b c", "d e f", false},
		{"empty strings", "", "", false},
		{"single word", "hello", "hello", true},
		{"single word mismatch", "hello", "world", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := sameWordsUnordered(tt.a, tt.b)
			if got != tt.want {
				t.Errorf("sameWordsUnordered(%q, %q) = %v, want %v", tt.a, tt.b, got, tt.want)
			}
		})
	}
}

func TestIsLatinScript(t *testing.T) {
	tests := []struct {
		name  string
		value string
		want  bool
	}{
		{"basic latin", "Artist", true},
		{"with accented latin", "José", true},
		{"latin extended", "Mötley Crüe", true},
		{"cyrillic", "Артист", false},
		{"chinese", "艺术家", false},
		{"japanese", "アーティスト", false},
		{"arabic", "فنان", false},
		{"mixed latin and non-latin", "Artist 艺术家", false},
		{"empty string", "", true},
		{"numbers only", "123", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := isLatinScript(tt.value)
			if got != tt.want {
				t.Errorf("isLatinScript(%q) = %v, want %v", tt.value, got, tt.want)
			}
		})
	}
}


