package musicbrainz

type recordingResponse struct {
	Recordings []struct {
		ID   string `json:"id"`
		Tags []struct {
			Name  string `json:"name"`
			Count int    `json:"count"`
		} `json:"tags"`
	} `json:"recordings"`
}

type albumArtistResponse struct {
	Recordings []struct {
		ID       string `json:"id"`
		Releases []struct {
			ID           string `json:"id"`
			Title        string `json:"title"`
			ArtistCredit []struct {
				Name  string `json:"name"`
				Join  string `json:"joinphrase"`
			} `json:"artist-credit"`
		} `json:"releases"`
	} `json:"recordings"`
}
