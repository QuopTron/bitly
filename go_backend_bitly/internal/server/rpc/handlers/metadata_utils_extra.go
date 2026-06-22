package handlers

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend_bitly/internal/audio/metadata"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func registerMetadataUtilsExtra(reg *rpc.Registry) {
	reg.Register("normalizeIsrc", func(params map[string]interface{}) (interface{}, error) {
		return metadata.NormalizeISRC(rpc.Sp(params, "value")), nil
	})

	reg.Register("normalizeSpotifyId", func(params map[string]interface{}) (interface{}, error) {
		return metadata.NormalizeSpotifyID(rpc.Sp(params, "value")), nil
	})

	reg.Register("matchKeyFor", func(params map[string]interface{}) (interface{}, error) {
		return metadata.MatchKeyFor(rpc.Sp(params, "track"), rpc.Sp(params, "artist")), nil
	})

	reg.Register("albumKeyFor", func(params map[string]interface{}) (interface{}, error) {
		return metadata.AlbumKeyFor(rpc.Sp(params, "album"), rpc.Sp(params, "artist")), nil
	})

	reg.Register("hasEmbeddedLyricsMetadata", func(params map[string]interface{}) (interface{}, error) {
		metadataStr := rpc.Sp(params, "metadata")
		if metadataStr == "" {
			return false, nil
		}
		var meta metadata.AudioMetadata
		if err := json.Unmarshal([]byte(metadataStr), &meta); err != nil {
			return false, nil
		}
		return metadata.HasEmbeddedLyricsMetadata(&meta), nil
	})

	reg.Register("buildPathMatchKeys", func(params map[string]interface{}) (interface{}, error) {
		return metadata.BuildPathMatchKeys(rpc.Sp(params, "file_path")), nil
	})

	reg.Register("deleteFileAndCleanupFolder", func(params map[string]interface{}) (interface{}, error) {
		return "ok", metadata.DeleteFileAndCleanupFolder(rpc.Sp(params, "file_path"))
	})

	reg.Register("deleteSidecarFiles", func(params map[string]interface{}) (interface{}, error) {
		return "ok", metadata.DeleteSidecarFiles(rpc.Sp(params, "audio_path"))
	})

	reg.Register("rewriteSplitArtistTags", func(params map[string]interface{}) (interface{}, error) {
		filePath := rpc.Sp(params, "file_path")
		artist := rpc.Sp(params, "artist")
		albumArtist := rpc.Sp(params, "album_artist")
		if err := metadata.RewriteSplitArtistTags(filePath, artist, albumArtist); err != nil {
			return "", err
		}
		return map[string]interface{}{"success": true, "message": "Split artist tags written successfully"}, nil
	})
}
