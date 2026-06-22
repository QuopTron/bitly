package handlers

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func registerExtensionFFmpeg(reg *rpc.Registry) {
	reg.Register("getPendingFFmpegCommand", func(params map[string]interface{}) (interface{}, error) {
		cmdID := rpc.Sp(params, "command_id")
		if cmdID == "" {
			return "{}", nil
		}
		ffmpegCmdMu.RLock()
		cmd, ok := ffmpegCmds[cmdID]
		ffmpegCmdMu.RUnlock()
		if !ok {
			return "{}", nil
		}
		b, _ := json.Marshal(cmd)
		return string(b), nil
	})

	reg.Register("setFFmpegCommandResult", func(params map[string]interface{}) (interface{}, error) {
		cmdID := rpc.Sp(params, "command_id")
		if cmdID == "" {
			return "ok", nil
		}
		ffmpegCmdMu.Lock()
		cmd, ok := ffmpegCmds[cmdID]
		if ok {
			cmd.Completed = true
			cmd.Success = rpc.Sp(params, "success") == "true"
			cmd.Output = rpc.Sp(params, "output")
			cmd.Error = rpc.Sp(params, "error")
		}
		ffmpegCmdMu.Unlock()
		return "ok", nil
	})

	reg.Register("getAllPendingFFmpegCommands", func(params map[string]interface{}) (interface{}, error) {
		ffmpegCmdMu.RLock()
		var list []*ffmpegCmdEntry
		for _, cmd := range ffmpegCmds {
			if !cmd.Completed {
				list = append(list, cmd)
			}
		}
		ffmpegCmdMu.RUnlock()
		if list == nil {
			return "[]", nil
		}
		b, _ := json.Marshal(list)
		return string(b), nil
	})
}
