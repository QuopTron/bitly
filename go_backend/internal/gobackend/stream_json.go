package gobackend

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend/internal/streaming"
)

// streamVerifyErrorJSON builds the RPC error payload for a fast verification
// verdict: the track exists on [verr.Service] but that provider's signed
// session must be completed before it can stream. The client reads
// errorType=verification_required + service to open the right modal.
func streamVerifyErrorJSON(verr *streaming.VerifyRequiredError) string {
	mp := map[string]interface{}{
		"error":     verr.Error(),
		"errorType": "verification_required",
		"service":   verr.Service,
	}
	data, _ := json.Marshal(mp)
	return string(data)
}

// streamFallbackErrorJSON builds the RPC error response for a failed fallback
// download, carrying the structured errorType/service so the client can react
// (e.g. open a Cloudflare verification modal for the provider that needs it).
func streamFallbackErrorJSON(err error, out *streamFallbackOutcome) string {
	mp := map[string]interface{}{"error": err.Error()}
	if out != nil {
		if out.errorType != "" {
			mp["errorType"] = out.errorType
		}
		if out.service != "" {
			mp["service"] = out.service
		}
	}
	data, _ := json.Marshal(mp)
	return string(data)
}

// streamEncryptedInfo carries an encrypted/DRM file that needs client-side
// decryption (e.g. amazon FLAC with a decryption key, when no CLI ffmpeg is
// available on the platform). The file is kept on disk.
type streamEncryptedInfo struct {
	FilePath    string
	Key         string
	OutputExt   string
	InputFormat string
}

// streamEncryptedJSON builds the RPC response telling the client an encrypted
// file is ready and must be decrypted (e.g. via ffmpeg-kit) before playback.
func streamEncryptedJSON(info *streamEncryptedInfo, provider string) string {
	mp := map[string]interface{}{
		"needsDecryption": true,
		"filePath":        info.FilePath,
		"decryptionKey":   info.Key,
		"outputExtension": info.OutputExt,
		"inputFormat":     info.InputFormat,
		"provider":        provider,
	}
	data, _ := json.Marshal(mp)
	return string(data)
}

// streamFallbackOutcome is the result of a fallback download: either a playable
