package deezer

import "fmt"

// GetPlaylistTracks returns the tracks in a playlist (paginated).
func (c *Client) GetPlaylistTracks(playlistID int64, index, limit int) ([]Track, error) {
	if limit < 1 || limit > 100 {
		limit = 25
	}
	type tracksResp struct {
		Data  []Track `json:"data"`
		Total int     `json:"total"`
	}
	var resp tracksResp
	if err := c.doGet(fmt.Sprintf("/playlist/%d/tracks", playlistID),
		map[string]string{"index": fmt.Sprintf("%d", index), "limit": fmt.Sprintf("%d", limit)},
		&resp); err != nil {
		return nil, err
	}
	return resp.Data, nil
}
