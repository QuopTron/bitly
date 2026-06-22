package deezer

import (
	"context"
	"fmt"
	"net/url"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
)

func (c *Client) searchAlbums(ctx context.Context, query string, limit int) ([]core.SearchAlbumResult, error) {
	u := fmt.Sprintf("%s/album?q=%s&limit=%d", searchURL, url.QueryEscape(query), limit)
	var resp struct {
		Data []struct {
			ID          int64        `json:"id"`
			Title       string       `json:"title"`
			Cover       string       `json:"cover"`
			CoverMedium string       `json:"cover_medium"`
			CoverBig    string       `json:"cover_big"`
			CoverXL     string       `json:"cover_xl"`
			NbTracks    int          `json:"nb_tracks"`
			ReleaseDate string       `json:"release_date"`
			RecordType  string       `json:"record_type"`
			Artist      deezerArtist `json:"artist"`
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
		return nil, fmt.Errorf("no albums found")
	}
	results := make([]core.SearchAlbumResult, 0, len(resp.Data))
	for _, a := range resp.Data {
		cover := a.CoverXL
		if cover == "" {
			cover = a.CoverBig
		}
		if cover == "" {
			cover = a.CoverMedium
		}
		if cover == "" {
			cover = a.Cover
		}
		albumType := a.RecordType
		if albumType == "compile" {
			albumType = "compilation"
		}
		results = append(results, core.SearchAlbumResult{
			ID:          fmt.Sprintf("deezer:%d", a.ID),
			Name:        a.Title,
			Artists:     a.Artist.Name,
			Images:      cover,
			ReleaseDate: a.ReleaseDate,
			TotalTracks: a.NbTracks,
			AlbumType:   albumType,
		})
	}
	return results, nil
}
