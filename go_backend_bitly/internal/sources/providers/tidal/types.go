package tidal

import "time"

type server struct {
	URL     string `json:"url"`
	Version string `json:"version"`
}

type uptimeResponse struct {
	LastUpdated string   `json:"lastUpdated"`
	API         []server `json:"api"`
	Down        []struct {
		URL   string `json:"url"`
		Error string `json:"error"`
	} `json:"down"`
}

type cacheEntry struct {
	data      interface{}
	expiresAt time.Time
}

type trackItem struct {
	ID           int    `json:"id"`
	Title        string `json:"title"`
	Duration     int    `json:"duration"`
	ISRC         string `json:"isrc"`
	AudioQuality string `json:"audioQuality"`
	URL          string `json:"url"`
	Artist       struct {
		ID   int    `json:"id"`
		Name string `json:"name"`
	} `json:"artist"`
	Album struct {
		ID    int    `json:"id"`
		Title string `json:"title"`
		Cover string `json:"cover"`
	} `json:"album"`
	TrackNumber int `json:"trackNumber"`
}

type searchData struct {
	Limit              int         `json:"limit"`
	Offset             int         `json:"offset"`
	TotalNumberOfItems int         `json:"totalNumberOfItems"`
	Items              []trackItem `json:"items"`
}

type searchResponse struct {
	Version string     `json:"version"`
	Data    searchData `json:"data"`
}

type trackInfoData struct {
	ID           int    `json:"id"`
	Title        string `json:"title"`
	Duration     int    `json:"duration"`
	ISRC         string `json:"isrc"`
	TrackNumber  int    `json:"trackNumber"`
	Copyright    string `json:"copyright"`
	URL          string `json:"url"`
	AudioQuality string `json:"audioQuality"`
	Artist       struct {
		ID   int    `json:"id"`
		Name string `json:"name"`
	} `json:"artist"`
	Album struct {
		ID    int    `json:"id"`
		Title string `json:"title"`
		Cover string `json:"cover"`
	} `json:"album"`
}

type infoResponse struct {
	Version string        `json:"version"`
	Data    trackInfoData `json:"data"`
}

type albumData struct {
	ID             int    `json:"id"`
	Title          string `json:"title"`
	Cover          string `json:"cover"`
	ReleaseDate    string `json:"releaseDate"`
	NumberOfTracks int    `json:"numberOfTracks"`
	Duration       int    `json:"duration"`
	Artist         struct {
		ID   int    `json:"id"`
		Name string `json:"name"`
	} `json:"artist"`
	Items []struct {
		Item struct {
			ID          int    `json:"id"`
			Title       string `json:"title"`
			Duration    int    `json:"duration"`
			ISRC        string `json:"isrc"`
			TrackNumber int    `json:"trackNumber"`
		} `json:"item"`
	} `json:"items"`
}

type albumResponse struct {
	Version string    `json:"version"`
	Data    albumData `json:"data"`
}

type streamData struct {
	URL          string `json:"url"`
	Codec        string `json:"codec"`
	AudioQuality string `json:"audioQuality"`
}

type streamResponse struct {
	Version string     `json:"version"`
	Data    streamData `json:"data"`
}
