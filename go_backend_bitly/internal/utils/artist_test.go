package utils

import "testing"

func TestPrimaryArtistName(t *testing.T) {
	tests := []struct {
		name string
		raw  string
		want string
	}{
		{"single artist", "Artist Name", "Artist Name"},
		{"comma separated", "Artist A, Artist B", "Artist A"},
		{"semicolon separated", "Artist A; Artist B", "Artist A"},
		{"slash separated", "Artist A / Artist B", "Artist A"},
		{"bullet separated", "Artist A • Artist B", "Artist A"},
		{"ampersand separated", "Artist A & Artist B", "Artist A"},
		{"feat separated", "Artist A feat. Guest", "Artist A"},
		{"ft separated", "Artist A ft. Guest", "Artist A"},
		{"trim spaces", "  Artist Name  ", "Artist Name"},
		{"empty string", "", ""},
		{"no separator returns full", "Just One Artist", "Just One Artist"},
		{"comma splits artist", "Artist,", "Artist"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := PrimaryArtistName(tt.raw)
			if got != tt.want {
				t.Errorf("PrimaryArtistName(%q) = %q, want %q", tt.raw, got, tt.want)
			}
		})
	}
}

func TestSplitArtistNamesJSON(t *testing.T) {
	tests := []struct {
		name       string
		rawArtists string
		want       string
	}{
		{"single artist", "Artist", `["Artist"]`},
		{"feat separated", "Main feat. Guest", `["Main","Guest"]`},
		{"ft separated", "Main ft. Guest", `["Main","Guest"]`},
		{"ampersand", "A & B", `["A","B"]`},
		{"and", "A and B", `["A","B"]`},
		{"comma", "A, B", `["A","B"]`},
		{"x separator", "A x B", `["A","B"]`},
		{"vs separator", "A vs B", `["A","B"]`},
		{"presents separator", "A presents B", `["A","B"]`},
		{"multiple separators", "A & B feat. C", `["A","B","C"]`},
		{"empty string", "", `[]`},
		{"trimmed parts", "  A  ,  B  ", `["A","B"]`},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := SplitArtistNamesJSON(tt.rawArtists)
			if got != tt.want {
				t.Errorf("SplitArtistNamesJSON(%q) = %s, want %s", tt.rawArtists, got, tt.want)
			}
		})
	}
}

func TestHasAlphaNumericRunes(t *testing.T) {
	tests := []struct {
		name  string
		value string
		want  bool
	}{
		{"letters only", "Artist", true},
		{"numbers only", "123", true},
		{"mixed alphanumeric", "Artist123", true},
		{"symbols only", "!@#$%", false},
		{"spaces only", "   ", false},
		{"empty string", "", false},
		{"letters and symbols", "Hello!", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := hasAlphaNumericRunes(tt.value)
			if got != tt.want {
				t.Errorf("hasAlphaNumericRunes(%q) = %v, want %v", tt.value, got, tt.want)
			}
		})
	}
}

func TestSplitArtists(t *testing.T) {
	tests := []struct {
		name    string
		artists string
		want    []string
	}{
		{"single artist", "artist", []string{"artist"}},
		{"feat. separator", "main feat. guest", []string{"main", "guest"}},
		{"feat separator", "main feat guest", []string{"main", "guest"}},
		{"ft. separator", "main ft. guest", []string{"main", "guest"}},
		{"ft separator", "main ft guest", []string{"main", "guest"}},
		{"ampersand", "a & b", []string{"a", "b"}},
		{"and", "a and b", []string{"a", "b"}},
		{"comma", "a, b", []string{"a", "b"}},
		{"x separator", "a x b", []string{"a", "b"}},
		{"y separator", "a y b", []string{"a", "b"}},
		{"vs separator", "a vs b", []string{"a", "b"}},
		{"presents separator", "a presents b", []string{"a", "b"}},
		{"empty string", "", []string{}},
		{"leading separator no preceding space unchanged", "feat. guest", []string{"feat. guest"}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := splitArtists(tt.artists)
			if len(got) != len(tt.want) {
				t.Errorf("splitArtists(%q) = %v (len=%d), want %v (len=%d)",
					tt.artists, got, len(got), tt.want, len(tt.want))
				return
			}
			for i := range got {
				if got[i] != tt.want[i] {
					t.Errorf("splitArtists(%q)[%d] = %q, want %q", tt.artists, i, got[i], tt.want[i])
				}
			}
		})
	}
}
