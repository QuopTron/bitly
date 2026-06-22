package api

import (
	"fmt"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/runtime"
)

type ActionClient struct {
	runtime *runtime.ExtensionRuntime
}

func NewActionClient(rt *runtime.ExtensionRuntime) *ActionClient {
	return &ActionClient{runtime: rt}
}

func (c *ActionClient) InvokeAction(extensionID, action string, params map[string]interface{}) (interface{}, error) {
	result, err := c.runtime.CallMethod(extensionID, action, params)
	if err != nil {
		return nil, fmt.Errorf("InvokeAction %s.%s: %w", extensionID, action, err)
	}
	return result.Value, nil
}
