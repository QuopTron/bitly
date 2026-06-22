package api

import "fmt"

func InvokeAction(extensionID, action string, params map[string]interface{}) (interface{}, error) {
	return nil, fmt.Errorf("InvokeAction requires an ActionClient; use NewActionClient(runtime).InvokeAction()")
}


