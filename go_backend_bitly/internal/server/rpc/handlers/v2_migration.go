package handlers

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

func registerV2Migration(reg *rpc.Registry) {
	reg.Register("runMigrationV2JSON", func(params map[string]interface{}) (interface{}, error) {
		return database.RunMigrationV2JSON()
	})
}
