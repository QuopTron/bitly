package deezer

import (
	"context"
	"fmt"
	"net/url"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
)

func (c *Client) searchPlaylists(ctx context.Context, query string, limit int) ([]core.SearchPlaylistResult, error) {
	u := fmt.Sprintf("%s/playlist?q=%s&limit=%d", searchURL, url.QueryEscape(query), limit)
	var resp struct {
		Data []struct {
			ID            int64  `json:"id"`
			Title         string `json:"title"`
			Picture       string `json:"picture"`
			PictureMedium string `json:"picture_medium"`
			PictureBig    string `json:"picture_big"`
			PictureXL     string `json:"picture_xl"`
			NbTracks      int    `json:"nb_tracks"`
			User          struct {
				Name string `json:"name"`
			} `json:"user"`
		} `json:"data"`
		Error *struct {
			Type    string `json:"type"`
			Message string `json:"message"`
			Code    int    `json:"code"`
		} `json:"error"`
	}
	if err := c.getJSON(ctx, u, &resp); err != nil {
		return nil, err
	}
	if resp.Error != nil || len(resp.Data) == 0 {
		return nil, fmt.Errorf("no playlists found")
	}
	results := make([]core.SearchPlaylistResult, 0, len(resp.Data))
	for _, p := range resp.Data {
		pic := p.PictureXL
		if pic == "" {
			pic = p.PictureBig
		}
		if pic == "" {
			pic = p.PictureMedium
		}
		if pic == "" {
			pic = p.Picture
		}
		results = append(results, core.SearchPlaylistResult{
			ID:          fmt.Sprintf("deezer:%d", p.ID),
			Name:        p.Title,
			Owner:       p.User.Name,
			Images:      pic,
			TotalTracks: p.NbTracks,
		})
	}
	return results, nil
}
