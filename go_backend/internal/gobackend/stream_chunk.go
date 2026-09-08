package gobackend

import (
	"encoding/base64"
	"encoding/json"
	"strconv"

	"github.com/zarz/bitly/go_backend/internal/streaming"
)

// StreamAudioChunk fetches a byte range of audio directly (mobile/AAR).
func StreamAudioChunk(payload string) string {
	if streamer == nil {
		streamer = streaming.NewStreamer()
	}
	var params struct {
		AudioURL  string `json:"audioURL"`
		OffsetStr string `json:"offset"`
		LengthStr string `json:"length"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	offset, _ := strconv.ParseInt(params.OffsetStr, 10, 64)
	length, _ := strconv.ParseInt(params.LengthStr, 10, 64)
	if length <= 0 {
		length = 256 * 1024 // default 256KB chunk
	}
	data, err := streamer.StreamChunk(params.AudioURL, offset, length)
	if err != nil {
		return jsonError(err)
	}
	encoded := base64.StdEncoding.EncodeToString(data)
	result := map[string]interface{}{
		"data":   encoded,
		"size":   len(data),
		"offset": offset,
	}
	out, _ := json.Marshal(result)
	return string(out)
}
