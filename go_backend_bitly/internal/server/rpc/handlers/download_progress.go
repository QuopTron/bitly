package handlers

import (
	"strconv"

	"github.com/zarz/bitly/go_backend_bitly/internal/download/progress"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func registerDownloadProgress(reg *rpc.Registry) {
	reg.Register("getDownloadProgress", func(params map[string]interface{}) (interface{}, error) {
		return progress.GetProgress(), nil
	})

	reg.Register("getAllDownloadProgress", func(params map[string]interface{}) (interface{}, error) {
		return progress.GetMultiProgress(), nil
	})

	reg.Register("getDownloadProgressDelta", func(params map[string]interface{}) (interface{}, error) {
		sinceSeq := int64(rpc.Sn(params, "since_seq"))
		return progress.GetMultiProgressDelta(sinceSeq), nil
	})

	reg.Register("initItemProgress", func(params map[string]interface{}) (interface{}, error) {
		progress.StartItemProgress(rpc.Sp(params, "item_id"))
		return "ok", nil
	})

	reg.Register("finishItemProgress", func(params map[string]interface{}) (interface{}, error) {
		progress.CompleteItemProgress(rpc.Sp(params, "item_id"))
		return "ok", nil
	})

	reg.Register("clearItemProgress", func(params map[string]interface{}) (interface{}, error) {
		progress.RemoveItemProgress(rpc.Sp(params, "item_id"))
		return "ok", nil
	})

	reg.Register("setDownloadDirectory", func(params map[string]interface{}) (interface{}, error) {
		return "ok", nil
	})

	reg.Register("allowDownloadDir", func(params map[string]interface{}) (interface{}, error) {
		return "ok", nil
	})

	reg.Register("getTrackCacheSize", func(params map[string]interface{}) (interface{}, error) {
		return strconv.Itoa(0), nil
	})

	reg.Register("getTrackCacheSizeBytes", func(params map[string]interface{}) (interface{}, error) {
		return "0", nil
	})
}
