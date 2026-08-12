package provider

import "testing"

func TestOriginalStrength_RejectsNonOriginal(t *testing.T) {
	cases := []struct {
		name        string
		queryTitle  string
		queryArtist string
		cand        TrackResult
		want        bool
	}{
		{
			name:        "exact original",
			queryTitle:  "Si Antes Te Hubiera Conocido",
			queryArtist: "KAROL G",
			cand:        TrackResult{Title: "Si Antes Te Hubiera Conocido", Artist: "KAROL G"},
			want:        true,
		},
		{
			name:        "remix rejected",
			queryTitle:  "Si Antes Te Hubiera Conocido",
			queryArtist: "KAROL G",
			cand:        TrackResult{Title: "Si Antes Te Hubiera Conocido (Remix)", Artist: "KAROL G"},
			want:        false,
		},
		{
			name:        "cover by another artist rejected",
			queryTitle:  "Si Antes Te Hubiera Conocido",
			queryArtist: "KAROL G",
			cand:        TrackResult{Title: "Si Antes Te Hubiera Conocido", Artist: "Some Cover Band"},
			want:        false,
		},
		{
			name:        "live rejected",
			queryTitle:  "La Bachata",
			queryArtist: "Manuel Turizo",
			cand:        TrackResult{Title: "La Bachata (Live)", Artist: "Manuel Turizo"},
			want:        false,
		},
		{
			name:        "acoustic rejected",
			queryTitle:  "Skyfall",
			queryArtist: "Adele",
			cand:        TrackResult{Title: "Skyfall (Acoustic)", Artist: "Adele"},
			want:        false,
		},
		{
			name:        "unrelated title rejected",
			queryTitle:  "Skyfall",
			queryArtist: "Adele",
			cand:        TrackResult{Title: "Rolling in the Deep", Artist: "Adele"},
			want:        false,
		},
		{
			name:        "wrong artist + same title rejected",
			queryTitle:  "Skyfall",
			queryArtist: "Adele",
			cand:        TrackResult{Title: "Skyfall", Artist: "Random Uploader"},
			want:        false,
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			_, ok := OriginalStrength(c.queryTitle, c.queryArtist, c.cand)
			if ok != c.want {
				t.Fatalf("OriginalStrength(%q,%q,%q/%q) = %v, want %v",
					c.queryTitle, c.queryArtist, c.cand.Title, c.cand.Artist, ok, c.want)
			}
		})
	}
}

func TestBestOriginal_AcceptsFeat(t *testing.T) {
	results := []TrackResult{
		{ID: "1", Title: "DÁKITI", Artist: "Bad Bunny & Jhay Cortez"},
		{ID: "2", Title: "DÁKITI (Remix)", Artist: "Bad Bunny"},
		{ID: "3", Title: "DÁKITI", Artist: "Other"},
	}
	best := BestOriginal("DÁKITI", "Bad Bunny", results)
	if best == nil || best.ID != "1" {
		t.Fatalf("BestOriginal picked %+v, want ID=1", best)
	}
}

// The log on the device showed real tracks being rejected even though the
// candidate was the original song. These cases lock the fixes:
// 1. Official titles that contain "remix" ("MORNING DEW (DONK) REMIX") were
//    rejected because IsNonOriginalTitle flagged any "remix".
// 2. SoundCloud re-uploads carry the real artist in the TITLE and the uploader
//    in Artist ("Shakira - DAI DAI" / "minecraftdiablo") -> a=0, rejected.
// 3. Apple candidates reorder bonus/feat tokens ("suave. [bonus track]
//    (feat. Tokischa)" vs "suave. (feat. Tokischa) [bonus track]") -> t=1.
func TestOriginalStrength_AcceptsRealDeviceCases(t *testing.T) {
	cases := []struct {
		name        string
		queryTitle  string
		queryArtist string
		cand        TrackResult
		want        bool
	}{
		{
			name:        "official remix title accepted when query also has remix",
			queryTitle:  "MORNING DEW (DONK) REMIX FEAT JAŸ-Z",
			queryArtist: "Beyoncé, JAŸ-Z",
			cand:        TrackResult{Title: "MORNING DEW (DONK) REMIX [feat. JAŸ-Z]", Artist: "Beyoncé"},
			want:        true,
		},
		{
			name:        "soundcloud re-upload with artist in title",
			queryTitle:  "Dai Dai",
			queryArtist: "Shakira",
			cand:        TrackResult{Title: "Shakira - DAI DAI", Artist: "minecraftdiablo"},
			want:        true,
		},
		{
			name:        "reordered bonus track tokens",
			queryTitle:  "suave. (feat. Tokischa) [bonus track]",
			queryArtist: "Brent Faiyaz, Tokischa",
			cand:        TrackResult{Title: "suave. [bonus track] (feat. Tokischa)", Artist: "Brent Faiyaz & Tokischa"},
			want:        true,
		},
		{
			name:        "accent variant NFD title",
			queryTitle:  "Puñaladas",
			queryArtist: "Lauta",
			cand:        TrackResult{Title: "Pun\u0303aladas", Artist: "Lauta, Amigo de Artistas, Tote"},
			want:        true,
		},
		{
			name:        "still rejects non-original remix when query has none",
			queryTitle:  "La Bachata",
			queryArtist: "Manuel Turizo",
			cand:        TrackResult{Title: "Manuel Turizo - La Bachata (5HOURS Remix)", Artist: "Manuel Turizo"},
			want:        false,
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			_, ok := OriginalStrength(c.queryTitle, c.queryArtist, c.cand)
			if ok != c.want {
				t.Fatalf("OriginalStrength(%q,%q,%q/%q) = %v, want %v",
					c.queryTitle, c.queryArtist, c.cand.Title, c.cand.Artist, ok, c.want)
			}
		})
	}
}
