package handlers

import (
	"encoding/json"
	"fmt"

	"github.com/zarz/bitly/go_backend_bitly/internal/audio/metadata"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func registerMetadataUtils(reg *rpc.Registry) {
	reg.Register("buildFilename", func(params map[string]interface{}) (interface{}, error) {
		template := rpc.Sp(params, "template")
		metadataJSON := rpc.Sp(params, "metadata")
		if template == "" {
			return "", fmt.Errorf("template is required")
		}
		var meta map[string]interface{}
		if metadataJSON != "" {
			if err := json.Unmarshal([]byte(metadataJSON), &meta); err != nil {
				return "", err
			}
		}
		return buildFilenameFromTemplate(template, meta), nil
	})

	reg.Register("sanitizeFilename", func(params map[string]interface{}) (interface{}, error) {
		return sanitizeFilename(rpc.Sp(params, "filename")), nil
	})

	reg.Register("sanitizeFolderName", func(params map[string]interface{}) (interface{}, error) {
		return metadata.SanitizeFolderName(rpc.Sp(params, "name")), nil
	})

	reg.Register("normalizeOptionalString", func(params map[string]interface{}) (interface{}, error) {
		return metadata.NormalizeOptionalString(rpc.Sp(params, "value")), nil
	})

	reg.Register("normalizeCoverReference", func(params map[string]interface{}) (interface{}, error) {
		return metadata.NormalizeCoverReference(rpc.Sp(params, "value")), nil
	})

	reg.Register("normalizeRemoteHttpUrl", func(params map[string]interface{}) (interface{}, error) {
		return metadata.NormalizeRemoteHTTPUrl(rpc.Sp(params, "value")), nil
	})

	reg.Register("formatSampleRateKHz", func(params map[string]interface{}) (interface{}, error) {
		return metadata.FormatSampleRateKHz(rpc.Sn(params, "sample_rate")), nil
	})

	reg.Register("buildDisplayAudioQuality", func(params map[string]interface{}) (interface{}, error) {
		return metadata.BuildDisplayAudioQuality(
			rpc.Sn(params, "bit_depth"), rpc.Sn(params, "sample_rate"),
			rpc.Sn(params, "bitrate_kbps"), rpc.Sp(params, "format"),
			rpc.Sp(params, "stored_quality")), nil
	})

	reg.Register("isPlaceholderQualityLabel", func(params map[string]interface{}) (interface{}, error) {
		return metadata.IsPlaceholderQualityLabel(rpc.Sp(params, "quality")), nil
	})

	reg.Register("audioMimeTypeForPath", func(params map[string]interface{}) (interface{}, error) {
		return metadata.AudioMimeTypeForPath(rpc.Sp(params, "file_path")), nil
	})

	registerMetadataUtilsExtra(reg)
}
