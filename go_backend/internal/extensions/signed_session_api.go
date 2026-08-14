package extensions

import (
	"strings"

	"github.com/dop251/goja"
)

// registerSignedSession exposes the signed session API to JS extensions.
// It is a trimmed port of the SpotiFLAC-Mobile session.signedFetch runtime.
func registerSignedSession(s *Sandbox) {
	vm := s.VM
	sessionObj := vm.NewObject()

	sessionObj.Set("signedFetch", func(call goja.FunctionCall) goja.Value {
		if len(call.Arguments) < 2 {
			return vm.ToValue(map[string]any{"ok": false, "error": "method and path are required"})
		}
		if s.SignedSession == nil {
			return vm.ToValue(map[string]any{"ok": false, "error": "signedSession is not configured"})
		}
		method := strings.ToUpper(strings.TrimSpace(call.Arguments[0].String()))
		requestPath := call.Arguments[1].String()
		body := ""
		if len(call.Arguments) > 2 && !goja.IsUndefined(call.Arguments[2]) && !goja.IsNull(call.Arguments[2]) {
			switch v := call.Arguments[2].Export().(type) {
			case string:
				body = v
			case map[string]any, []any:
				body = toJSONString(v)
			default:
				body = call.Arguments[2].String()
			}
		}
		headers := map[string]string{}
		if len(call.Arguments) > 3 {
			headers = toStringMapValue(call.Arguments[3])
		}
		cfg := signedSessionConfigWithDefaults(s.SignedSession)
		if s.Session == nil {
			s.Session = &SignedSessionState{}
		}
		client := s.signedHTTPClient()
		record, err := s.Session.loadOrInit(s.DataDir, cfg)
		if err != nil {
			return vm.ToValue(map[string]any{"ok": false, "error": err.Error()})
		}
		result := s.Session.signedFetch(client, cfg, record, method, requestPath, []byte(body), headers)
		return vm.ToValue(result)
	})

	sessionObj.Set("completeGrant", func(call goja.FunctionCall) goja.Value {
		if s.SignedSession == nil {
			return vm.ToValue(map[string]any{"success": false, "error": "signedSession is not configured"})
		}
		grant := ""
		if len(call.Arguments) > 0 {
			grant = strings.TrimSpace(call.Arguments[0].String())
		}
		if grant == "" && s.Session != nil {
			grant = s.Session.Grant
		}
		if grant == "" {
			return vm.ToValue(map[string]any{"success": false, "error": "no pending grant"})
		}
		cfg := signedSessionConfigWithDefaults(s.SignedSession)
		if s.Session == nil {
			s.Session = &SignedSessionState{}
		}
		client := s.signedHTTPClient()
		record, err := s.Session.loadOrInit(s.DataDir, cfg)
		if err != nil {
			return vm.ToValue(map[string]any{"success": false, "error": err.Error()})
		}
		if err := s.Session.exchangeSignedSessionGrant(client, cfg, record, grant); err != nil {
			return vm.ToValue(map[string]any{"success": false, "error": err.Error()})
		}
		return vm.ToValue(map[string]any{"success": true})
	})

	sessionObj.Set("status", func(call goja.FunctionCall) goja.Value {
		if s.SignedSession == nil {
			return vm.ToValue(map[string]any{"authenticated": false, "error": "signedSession is not configured"})
		}
		cfg := signedSessionConfigWithDefaults(s.SignedSession)
		if s.Session == nil {
			s.Session = &SignedSessionState{}
		}
		record, err := s.Session.loadOrInit(s.DataDir, cfg)
		if err != nil {
			return vm.ToValue(map[string]any{"authenticated": false, "error": err.Error()})
		}
		return vm.ToValue(map[string]any{
			"authenticated": signedSessionRecordIsUsable(record),
			"expires_at":    record.ExpiresAt,
			"install_id":    record.InstallID,
			"session_id":    record.SessionID,
		})
	})

	sessionObj.Set("clear", func(call goja.FunctionCall) goja.Value {
		s.SignedSessionClear()
		return vm.ToValue(map[string]any{"success": true})
	})

	vm.Set("session", sessionObj)
}

func toJSONString(v interface{}) string {
	data, err := marshalJSON(v)
	if err != nil {
		return ""
	}
	return string(data)
}

func toStringMapValue(v goja.Value) map[string]string {
	result := map[string]string{}
	if v == nil || goja.IsUndefined(v) || goja.IsNull(v) {
		return result
	}
	obj := v.ToObject(nil)
	if obj == nil {
		return result
	}
	for _, key := range obj.Keys() {
		result[key] = obj.Get(key).String()
	}
	return result
}
