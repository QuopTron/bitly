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
