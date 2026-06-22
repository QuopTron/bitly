package handlers

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

func registerDownloadHistoryExtra(reg *rpc.Registry) {
	reg.Register("getDownloadEntryByID", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetDownloadEntryByID(rpc.Sp(params, "request"))
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("getDownloadEntryBySpotifyID", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetDownloadEntryBySpotifyID(rpc.Sp(params, "request"))
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("getDownloadEntryByISRC", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetDownloadEntryByISRC(rpc.Sp(params, "request"))
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("findDownloadEntryByTrackAndArtist", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.FindDownloadEntryByTrackAndArtist(
			rpc.Sp(params, "track_name"), rpc.Sp(params, "artist_name"))
		if err != nil {
			return nil, err
		}
		return result, nil
	})

	reg.Register("updateDownloadFilePath", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.UpdateDownloadFilePath(rpc.Sp(params, "id"), rpc.Sp(params, "file_path"))
	})

	reg.Register("updateDownloadVideoPath", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.UpdateDownloadVideoPath(rpc.Sp(params, "id"), rpc.Sp(params, "path"))
	})

	reg.Register("updateDownloadLyricsPath", func(params map[string]interface{}) (interface{}, error) {
		return "ok", database.UpdateDownloadLyricsPath(rpc.Sp(params, "id"), rpc.Sp(params, "path"))
	})

	reg.Register("updateDownloadAudioMetadata", func(params map[string]interface{}) (interface{}, error) {
		request := rpc.Sp(params, "request")
		return "ok", database.UpdateDownloadAudioMetadataJSON(request)
	})

	reg.Register("getDownloadHistoryFilePaths", func(params map[string]interface{}) (interface{}, error) {
		result, err := database.GetDownloadHistoryFilePaths()
		if err != nil {
			return nil, err
		}
		return result, nil
	})
}
