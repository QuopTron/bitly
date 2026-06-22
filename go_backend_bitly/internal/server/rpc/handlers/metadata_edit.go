package handlers

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"github.com/zarz/bitly/go_backend_bitly/internal/audio/metadata"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func registerMetadataEdit(reg *rpc.Registry) {
	reg.Register("editFileMetadata", func(params map[string]interface{}) (interface{}, error) {
		filePath := rpc.Sp(params, "file_path")
		metadataJSON := rpc.Sp(params, "metadata_json")
		if filePath == "" || metadataJSON == "" {
			return "", fmt.Errorf("file_path and metadata_json are required")
		}

		var fields map[string]string
		if err := json.Unmarshal([]byte(metadataJSON), &fields); err != nil {
			return "", fmt.Errorf("invalid metadata JSON: %w", err)
		}

		lower := strings.ToLower(filePath)
		isFlac := strings.HasSuffix(lower, ".flac")
		isApeFile := strings.HasSuffix(lower, ".ape") || strings.HasSuffix(lower, ".wv") || strings.HasSuffix(lower, ".mpc")
		isM4AFile := strings.HasSuffix(lower, ".m4a") || strings.HasSuffix(lower, ".mp4") || strings.HasSuffix(lower, ".m4b")

		if isFlac {
			if err := metadata.EditFlacFields(filePath, fields); err != nil {
				return "", fmt.Errorf("failed to write FLAC metadata: %w", err)
			}
			return map[string]interface{}{"success": true, "method": "native"}, nil
		}

		if isApeFile {
			return editAPEMetadata(filePath, fields), nil
		}

		if isM4AFile && hasOnlyM4AReplayGainFields(fields) {
			if err := metadata.EditM4AReplayGain(filePath, fields); err != nil {
				return "", fmt.Errorf("failed to write M4A metadata: %w", err)
			}
			return map[string]interface{}{"success": true, "method": "native_m4a_replaygain"}, nil
		}

		return map[string]interface{}{
			"success": true,
			"method":  "ffmpeg",
			"fields":  fields,
		}, nil
	})
}

func editAPEMetadata(filePath string, fields map[string]string) interface{} {
	trackNum, totalTracks, discNum, totalDiscs := 0, 0, 0, 0
	if v, ok := fields["track_number"]; ok && v != "" {
		fmt.Sscanf(v, "%d", &trackNum)
	}
	if v, ok := fields["track_total"]; ok && v != "" {
		fmt.Sscanf(v, "%d", &totalTracks)
	}
	if v, ok := fields["disc_number"]; ok && v != "" {
		fmt.Sscanf(v, "%d", &discNum)
	}
	if v, ok := fields["disc_total"]; ok && v != "" {
		fmt.Sscanf(v, "%d", &totalDiscs)
	}

	meta := &metadata.AudioMetadata{
		Title:               fields["title"],
		Artist:              fields["artist"],
		Album:               fields["album"],
		AlbumArtist:         fields["album_artist"],
		Date:                fields["date"],
		TrackNumber:         trackNum,
		TotalTracks:         totalTracks,
		DiscNumber:          discNum,
		TotalDiscs:          totalDiscs,
		ISRC:                fields["isrc"],
		Lyrics:              fields["lyrics"],
		Genre:               fields["genre"],
		Label:               fields["label"],
		Copyright:           fields["copyright"],
		Composer:            fields["composer"],
		Comment:             fields["comment"],
		ReplayGainTrackGain: fields["replaygain_track_gain"],
		ReplayGainTrackPeak: fields["replaygain_track_peak"],
		ReplayGainAlbumGain: fields["replaygain_album_gain"],
		ReplayGainAlbumPeak: fields["replaygain_album_peak"],
	}

	newItems := metadata.AudioMetadataToAPEItems(meta)
	coverPath := strings.TrimSpace(fields["cover_path"])
	if coverPath != "" {
		coverData, coverErr := os.ReadFile(coverPath)
		if coverErr == nil && len(coverData) > 0 {
			desc := "cover.jpg\x00"
			binaryValue := desc + string(coverData)
			newItems = append(newItems, metadata.APETagItem{
				Key:   "Cover Art (Front)",
				Value: binaryValue,
				Flags: 2,
			})
		}
	}

	overrideKeys := metadata.APEKeysFromFields(fields)
	if coverPath != "" {
		overrideKeys["COVER ART (FRONT)"] = struct{}{}
	}

	existingTag, _ := metadata.ReadAPETags(filePath)
	var finalItems []metadata.APETagItem
	if existingTag != nil && len(existingTag.Items) > 0 {
		finalItems = metadata.MergeAPEItems(existingTag.Items, newItems, overrideKeys)
	} else {
		finalItems = newItems
	}

	tag := &metadata.APETag{Version: 2000, Items: finalItems}
	if err := metadata.WriteAPETags(filePath, tag); err != nil {
		return map[string]interface{}{"success": false, "error": err.Error()}
	}
	return map[string]interface{}{"success": true, "method": "native_ape"}
}
