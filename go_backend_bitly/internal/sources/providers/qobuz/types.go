package qobuz

type performer struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
}

type albumRef struct {
	ID      string `json:"id"`
	Title   string `json:"title"`
	QobuzID int    `json:"qobuz_id,omitempty"`
}

type trackItem struct {
	ID              int        `json:"id"`
	Title           string     `json:"title"`
	Duration        int        `json:"duration"`
	TrackNumber     int        `json:"track_number"`
	ISRC            string     `json:"isrc"`
	Performer       performer  `json:"performer"`
	Album           albumRef   `json:"album"`
	MaximumBitDepth int        `json:"maximum_bit_depth"`
	MaximumSampling float64    `json:"maximum_sampling_rate"`
}

type trackList struct {
	Items []trackItem `json:"items"`
	Total int         `json:"total"`
}

type albumData struct {
	ID                  string          `json:"id"`
	Title               string          `json:"title"`
	Artist              artistRef       `json:"artist"`
	Image               images          `json:"image"`
	Tracks              albumTrackList  `json:"tracks"`
	TracksCount         int             `json:"tracks_count"`
	Duration            int             `json:"duration"`
	ReleaseDateOriginal string          `json:"release_date_original"`
	Label               labelRef        `json:"label"`
	Copyright           string          `json:"copyright"`
	Genre               genreRef        `json:"genre"`
	Popularity          int             `json:"popularity"`
	URL                 string          `json:"url"`
	QobuzID             int             `json:"qobuz_id"`
}

type artistRef struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
}

type images struct {
	Small     string `json:"small"`
	Large     string `json:"large"`
	Thumbnail string `json:"thumbnail"`
}

type albumTrackItem struct {
	ID              int        `json:"id"`
	Title           string     `json:"title"`
	TrackNumber     int        `json:"track_number"`
	Duration        int        `json:"duration"`
	ISRC            string     `json:"isrc"`
	Performer       performer  `json:"performer"`
	MaximumBitDepth int        `json:"maximum_bit_depth"`
	MaximumSampling float64    `json:"maximum_sampling_rate"`
}

type albumTrackList struct {
	Items []albumTrackItem `json:"items"`
	Total int              `json:"total"`
}

type labelRef struct {
	Name string `json:"name"`
}

type genreRef struct {
	Name string `json:"name"`
}

type artistData struct {
	ID          int    `json:"id"`
	Name        string `json:"name"`
	AlbumsCount int    `json:"albums_count"`
	Image       string `json:"image"`
	Picture     string `json:"picture"`
}

type artistResponse struct {
	Artist artistData `json:"artist"`
}

type downloadData struct {
	URL string `json:"url"`
}
