package handlers

import "github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"

// RegisterSystemHandlers registers system-level RPC methods.
func RegisterSystemHandlers(reg *rpc.Registry) {
	reg.Register("ping", func(params map[string]interface{}) (interface{}, error) {
		return "pong", nil
	})

	reg.Register("exitApp", func(params map[string]interface{}) (interface{}, error) {
		return "ok", nil
	})

	reg.Register("InitMasterDatabaseJSON", func(params map[string]interface{}) (interface{}, error) {
		// Database initialization is handled in main.go via database.Init().
		// This RPC method is kept for legacy compatibility.
		return "ok", nil
	})
}
