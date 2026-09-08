package gobackend

import "github.com/zarz/bitly/go_backend/internal/provider"

// trackToFeedItem converts a provider.TrackResult to a FeedItemGo.
func trackToFeedItem(t provider.TrackResult, source string) FeedItemGo {
	return FeedItemGo{
		ID:         t.ID,
		Type:       "track",
		Name:       t.Title,
		Artists:    t.Artist,
		CoverURL:   t.CoverURL,
		Source:     source,
		AlbumID:    t.AlbumID,
		AlbumName:  t.Album,
		DurationMs: t.Duration,
		ISRC:       t.ISRC,
		SpotifyID:  t.SpotifyID,
		DeezerID:   t.DeezerID,
		TidalID:    t.TidalID,
		QobuzID:    t.QobuzID,
	}
}

// albumToFeedItem converts a provider.AlbumResult to a FeedItemGo.
func albumAFeedItem(a provider.AlbumResult, source string) FeedItemGo {
	return FeedItemGo{
		ID:          a.ID,
		Type:        "album",
		Name:        a.Title,
		Artists:     a.Artist,
		CoverURL:    a.CoverURL,
		Source:      source,
		ReleaseDate: a.ReleaseDate,
		TotalTracks: a.TrackCount,
	}
}

// artistToFeedItem converts a provider.ArtistResult to a FeedItemGo.
func artistaAFeedItem(a provider.ArtistResult, source string) FeedItemGo {
	return FeedItemGo{
		ID:       a.ID,
		Type:     "artist",
		Name:     a.Name,
		CoverURL: a.PictureURL,
		Source:   source,
	}
}

// playlistToFeedItem converts a provider.PlaylistResult to a FeedItemGo.
func playlistAFeedItem(p provider.PlaylistResult, source string) FeedItemGo {
	return FeedItemGo{
		ID:          p.ID,
		Type:        "playlist",
		Name:        p.Title,
		CoverURL:    p.CoverURL,
		Source:      source,
		TotalTracks: p.TrackCount,
		Owner:       p.Creator,
	}
}

// combinedToFeedItem converts a provider.CombinedResult (from an unfiltered
// extension search) to a FeedItemGo, keeping the item's own type so the UI can
// group tracks/albums/artists/playlists separately (SpotiFLAC principle).
func combinadoAFeedItem(c provider.CombinedResult, source string) FeedItemGo {
	return FeedItemGo{
		ID:          c.ID,
		Type:        c.Type,
		Name:        c.Name,
		Artists:     c.Artists,
		CoverURL:    c.CoverURL,
		Source:      source,
		AlbumID:     c.AlbumID,
		AlbumName:   c.AlbumName,
		DurationMs:  c.Duration,
		ReleaseDate: c.ReleaseDate,
		TotalTracks: c.TotalTracks,
		Owner:       c.Owner,
		ISRC:        c.ISRC,
		SpotifyID:   c.SpotifyID,
		DeezerID:    c.DeezerID,
		TidalID:     c.TidalID,
		QobuzID:     c.QobuzID,
	}
}
