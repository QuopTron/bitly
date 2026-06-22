package handlers

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/update"
)

// RegisterUpdateHandlers registers update-checking RPC methods.
func RegisterUpdateHandlers(reg *rpc.Registry) {
	reg.Register("checkGitHubUpdate", func(params map[string]interface{}) (interface{}, error) {
		channel := rpc.Sp(params, "channel")
		currentVersion := rpc.Sp(params, "current_version")
		repo := rpc.Sp(params, "repo")

		if channel == "" {
			channel = "stable"
		}
		if currentVersion == "" {
			currentVersion = "0.0.0"
		}

		result, err := update.CheckGitHubUpdate(channel, currentVersion, repo)
		if err != nil {
			result = &update.UpdateCheckResult{
				CurrentVersion: currentVersion,
				HasUpdate:      false,
				Error:          err.Error(),
			}
		}

		out, _ := json.Marshal(result)
		return string(out), nil
	})
}
