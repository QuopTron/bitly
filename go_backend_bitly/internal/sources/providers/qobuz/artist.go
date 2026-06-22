package qobuz

import (
	"encoding/json"
	"fmt"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
)

func (c *Client) GetArtist(artistID string) (*core.ExtArtistMetadata, error) {
	cacheKey := "artist:" + artistID
	if cached := c.getFromCache(cacheKey); cached != nil {
		return cached.(*core.ExtArtistMetadata), nil
	}

	data, err := c.getJSON("/get-artist", map[string]string{"artist_id": artistID})
	if err != nil {
		return nil, fmt.Errorf("qobuz_kennyy get artist: %w", err)
	}

	var resp artistResponse
	if err := json.Unmarshal(data, &resp); err != nil {
		return nil, fmt.Errorf("qobuz_kennyy parse artist: %w", err)
	}

	imageURL := resp.Artist.Image
	if imageURL == "" {
		imageURL = resp.Artist.Picture
	}

	metadata := &core.ExtArtistMetadata{
		ID:       fmt.Sprintf("%d", resp.Artist.ID),
		Name:     resp.Artist.Name,
		ImageURL: imageURL,
	}

	c.setCache(cacheKey, metadata, artistCacheTTL)
	return metadata, nil
}
