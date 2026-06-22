package availability

func buildAvailability(spotifyTrackID string, links map[string]platformLink) *TrackAvailability {
	a := &TrackAvailability{SpotifyID: spotifyTrackID}

	if a.SpotifyID == "" {
		if spotifyLink, ok := links["spotify"]; ok && spotifyLink.URL != "" {
			a.SpotifyID = extractSpotifyID(spotifyLink.URL)
		}
	}
	if tidalLink, ok := links["tidal"]; ok && tidalLink.URL != "" {
		a.Tidal = true
		a.TidalURL = tidalLink.URL
		a.TidalID = extractTidalID(tidalLink.URL)
	}
	if amazonLink, ok := links["amazonMusic"]; ok && amazonLink.URL != "" {
		a.Amazon = true
		a.AmazonURL = amazonLink.URL
	}
	if qobuzLink, ok := links["qobuz"]; ok && qobuzLink.URL != "" {
		a.Qobuz = true
		a.QobuzURL = qobuzLink.URL
		a.QobuzID = extractQobuzID(qobuzLink.URL)
	}
	if deezerLink, ok := links["deezer"]; ok && deezerLink.URL != "" {
		a.Deezer = true
		a.DeezerURL = deezerLink.URL
		a.DeezerID = extractDeezerIDFromURL(deezerLink.URL)
	}
	if ytMusicLink, ok := links["youtubeMusic"]; ok && ytMusicLink.URL != "" {
		a.YouTube = true
		a.YouTubeURL = ytMusicLink.URL
		a.YouTubeID = extractYouTubeID(ytMusicLink.URL)
	}
	if !a.YouTube {
		if youtubeLink, ok := links["youtube"]; ok && youtubeLink.URL != "" {
			a.YouTube = true
			a.YouTubeURL = youtubeLink.URL
			a.YouTubeID = extractYouTubeID(youtubeLink.URL)
		}
	}
	return a
}
