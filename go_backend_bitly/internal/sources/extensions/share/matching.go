package share

import "strings"

func bestAlbumTrack(tracks []extTrack, albumName, artists string) *extTrack {
	targetAlbum := normalizeLooseTitle(albumName)
	targetArtists := normalizeLooseArtistName(artists)
	bestScore := 0
	bestIndex := -1

	for i := range tracks {
		t := tracks[i]
		album := normalizeLooseTitle(collectionItemName(&t, false))
		trackArtists := normalizeLooseArtistName(t.Artists + " " + t.AlbumArtist)
		score := 0

		if isItemType(&t, "album") {
			score += 25
		}
		if album == targetAlbum {
			score += 100
		} else if album != "" && targetAlbum != "" &&
			(strings.Contains(album, targetAlbum) || strings.Contains(targetAlbum, album)) {
			score += 50
		}
		if targetArtists != "" &&
			(strings.Contains(trackArtists, targetArtists) || strings.Contains(targetArtists, trackArtists)) {
			score += 30
		}
		if score > bestScore {
			bestScore = score
			bestIndex = i
		}
	}
	if bestIndex < 0 || bestScore < 50 {
		return nil
	}
	return &tracks[bestIndex]
}

func bestArtistTrack(tracks []extTrack, artistName string) *extTrack {
	targetArtist := normalizeLooseArtistName(artistName)
	bestScore := 0
	bestIndex := -1

	for i := range tracks {
		t := tracks[i]
		artist := normalizeLooseArtistName(collectionItemName(&t, true))
		score := 0

		if isItemType(&t, "artist") {
			score += 25
		}
		if artist == targetArtist {
			score += 100
		} else if artist != "" && targetArtist != "" &&
			(strings.Contains(artist, targetArtist) || strings.Contains(targetArtist, artist)) {
			score += 60
		}
		if score > bestScore {
			bestScore = score
			bestIndex = i
		}
	}
	if bestIndex < 0 || bestScore < 60 {
		return nil
	}
	return &tracks[bestIndex]
}
