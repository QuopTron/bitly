package musicbrainz

import "testing"

type testTag struct {
	Name  string `json:"name"`
	Count int    `json:"count"`
}

func TestFormatGenre(t *testing.T) {
	tests := []struct {
		name string
		tags []testTag
		want string
	}{
		{
			name: "multiple tags",
			tags: []testTag{{Name: "rock", Count: 5}, {Name: "alternative", Count: 3}},
			want: "rock, alternative",
		},
		{
			name: "empty tags",
			tags: []testTag{},
			want: "",
		},
		{
			name: "low count tag",
			tags: []testTag{{Name: "rock", Count: 0}},
			want: "",
		},
		{
			name: "duplicate tags",
			tags: []testTag{{Name: "rock", Count: 5}, {Name: "rock", Count: 3}},
			want: "rock",
		},
		{
			name: "empty name tag",
			tags: []testTag{{Name: "", Count: 5}},
			want: "",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			converted := make([]struct {
				Name  string `json:"name"`
				Count int    `json:"count"`
			}, len(tt.tags))
			for i, tag := range tt.tags {
				converted[i] = struct {
					Name  string `json:"name"`
					Count int    `json:"count"`
				}{Name: tag.Name, Count: tag.Count}
			}
			got := formatGenre(converted)
			if got != tt.want {
				t.Errorf("formatGenre = %q, want %q", got, tt.want)
			}
		})
	}
}
