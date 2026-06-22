package rpc

import (
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// --- Registry Tests ---

func TestNewRegistry(t *testing.T) {
	r := NewRegistry()
	if r == nil {
		t.Fatal("expected non-nil Registry")
	}
	if r.handlers == nil {
		t.Error("expected initialized handlers map")
	}
}

func TestRegisterAndGet(t *testing.T) {
	r := NewRegistry()
	handler := func(params map[string]interface{}) (interface{}, error) {
		return "ok", nil
	}

	r.Register("test_method", handler)

	got, err := r.Get("test_method")
	if err != nil {
		t.Fatalf("Get failed: %v", err)
	}
	if got == nil {
		t.Fatal("expected non-nil handler")
	}

	result, err := got(nil)
	if err != nil {
		t.Fatalf("handler execution failed: %v", err)
	}
	if result != "ok" {
		t.Errorf("result = %q, want %q", result, "ok")
	}
}

func TestGet_UnknownMethod(t *testing.T) {
	r := NewRegistry()
	_, err := r.Get("nonexistent")
	if err == nil {
		t.Fatal("expected error for unknown method")
	}
	if !strings.Contains(err.Error(), "unknown method") {
		t.Errorf("error = %v", err)
	}
}

func TestDispatch(t *testing.T) {
	r := NewRegistry()
	r.Register("ping", func(params map[string]interface{}) (interface{}, error) {
		return "pong", nil
	})

	result, err := r.Dispatch("ping", nil)
	if err != nil {
		t.Fatalf("Dispatch failed: %v", err)
	}
	if result != "pong" {
		t.Errorf("result = %q", result)
	}
}

func TestDispatch_Unknown(t *testing.T) {
	r := NewRegistry()
	_, err := r.Dispatch("unknown", nil)
	if err == nil {
		t.Fatal("expected error for unknown method")
	}
}

func TestRegistry_Methods(t *testing.T) {
	r := NewRegistry()
	r.Register("a", func(p map[string]interface{}) (interface{}, error) { return nil, nil })
	r.Register("b", func(p map[string]interface{}) (interface{}, error) { return nil, nil })

	methods := r.Methods()
	if len(methods) != 2 {
		t.Errorf("expected 2 methods, got %d", len(methods))
	}
	if !contains(methods, "a") || !contains(methods, "b") {
		t.Error("methods should contain 'a' and 'b'")
	}
}

func TestRegistry_EmptyMethods(t *testing.T) {
	r := NewRegistry()
	methods := r.Methods()
	if len(methods) != 0 {
		t.Errorf("expected 0 methods, got %d", len(methods))
	}
}

// --- Dispatcher Tests ---

func TestNewDispatcher(t *testing.T) {
	d := NewDispatcher()
	if d == nil {
		t.Fatal("expected non-nil Dispatcher")
	}
	if d.Registry == nil {
		t.Error("expected non-nil Registry")
	}
}

func TestDispatcher_ServeHTTP_InvalidMethod(t *testing.T) {
	d := NewDispatcher()
	req := httptest.NewRequest("GET", "/rpc", nil)
	w := httptest.NewRecorder()
	d.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}

	var resp RPCResponse
	json.Unmarshal(w.Body.Bytes(), &resp)
	if resp.Error != "method not allowed" {
		t.Errorf("error = %q", resp.Error)
	}
}

func TestDispatcher_ServeHTTP_InvalidJSON(t *testing.T) {
	d := NewDispatcher()
	req := httptest.NewRequest("POST", "/rpc", strings.NewReader("not json"))
	w := httptest.NewRecorder()
	d.ServeHTTP(w, req)

	var resp RPCResponse
	json.Unmarshal(w.Body.Bytes(), &resp)
	if resp.Error == "" {
		t.Fatal("expected error for invalid JSON")
	}
	if !strings.Contains(resp.Error, "invalid JSON") {
		t.Errorf("error = %q", resp.Error)
	}
}

func TestDispatcher_ServeHTTP_ValidRequest(t *testing.T) {
	d := NewDispatcher()
	d.Registry.Register("ping", func(params map[string]interface{}) (interface{}, error) {
		return "pong", nil
	})

	body := `{"method":"ping","params":{}}`
	req := httptest.NewRequest("POST", "/rpc", strings.NewReader(body))
	w := httptest.NewRecorder()
	d.ServeHTTP(w, req)

	var resp RPCResponse
	json.Unmarshal(w.Body.Bytes(), &resp)
	if resp.Error != "" {
		t.Errorf("unexpected error: %s", resp.Error)
	}
	if resp.Result != "pong" {
		t.Errorf("result = %v, want %v", resp.Result, "pong")
	}
}

func TestDispatcher_ServeHTTP_HandlerError(t *testing.T) {
	d := NewDispatcher()
	d.Registry.Register("fail", func(params map[string]interface{}) (interface{}, error) {
		return nil, errors.New("something went wrong")
	})

	body := `{"method":"fail"}`
	req := httptest.NewRequest("POST", "/rpc", strings.NewReader(body))
	w := httptest.NewRecorder()
	d.ServeHTTP(w, req)

	var resp RPCResponse
	json.Unmarshal(w.Body.Bytes(), &resp)
	if resp.Error == "" {
		t.Error("expected error response")
	}
}

// --- Parameter Helpers Tests ---

func TestSp(t *testing.T) {
	params := map[string]interface{}{
		"name":  "  John  ",
		"empty": "",
	}
	if got := Sp(params, "name"); got != "John" {
		t.Errorf("Sp(name) = %q", got)
	}
	if got := Sp(params, "empty"); got != "" {
		t.Errorf("Sp(empty) = %q", got)
	}
	if got := Sp(params, "missing"); got != "" {
		t.Errorf("Sp(missing) = %q", got)
	}
}

func TestSn(t *testing.T) {
	params := map[string]interface{}{
		"int_val": float64(42),
		"float":   3.14,
		"str":     "not a number",
	}
	if got := Sn(params, "int_val"); got != 42 {
		t.Errorf("Sn(int_val) = %d", got)
	}
	if got := Sn(params, "float"); got != 3 {
		t.Errorf("Sn(float) = %d", got)
	}
	if got := Sn(params, "missing"); got != 0 {
		t.Errorf("Sn(missing) = %d", got)
	}
	if got := Sn(params, "str"); got != 0 {
		t.Errorf("Sn(str) = %d", got)
	}
}

func TestSb(t *testing.T) {
	params := map[string]interface{}{
		"true_str":   "true",
		"one_str":    "1",
		"false_str":  "false",
		"bool_true":  true,
		"bool_false": false,
		"num_one":    float64(1),
		"num_zero":   float64(0),
	}
	if got := Sb(params, "true_str"); got != true {
		t.Errorf("Sb(true_str) = %v", got)
	}
	if got := Sb(params, "one_str"); got != true {
		t.Errorf("Sb(one_str) = %v", got)
	}
	if got := Sb(params, "false_str"); got != false {
		t.Errorf("Sb(false_str) = %v", got)
	}
	if got := Sb(params, "bool_true"); got != true {
		t.Errorf("Sb(bool_true) = %v", got)
	}
	if got := Sb(params, "bool_false"); got != false {
		t.Errorf("Sb(bool_false) = %v", got)
	}
	if got := Sb(params, "num_one"); got != true {
		t.Errorf("Sb(num_one) = %v", got)
	}
	if got := Sb(params, "num_zero"); got != false {
		t.Errorf("Sb(num_zero) = %v", got)
	}
	if got := Sb(params, "missing"); got != false {
		t.Errorf("Sb(missing) = %v", got)
	}
}

// --- RPCRequest/RPCResponse Tests ---

func TestRPCRequest(t *testing.T) {
	req := RPCRequest{
		Method: "test",
		Params: map[string]interface{}{"key": "value"},
	}
	if req.Method != "test" {
		t.Errorf("Method = %q", req.Method)
	}
	if req.Params["key"] != "value" {
		t.Errorf("Params = %v", req.Params)
	}
}

func TestRPCResponse(t *testing.T) {
	resp := RPCResponse{
		Result: "success",
		Error:  "",
	}
	if resp.Result != "success" {
		t.Errorf("Result = %v", resp.Result)
	}
	if resp.Error != "" {
		t.Errorf("Error = %q", resp.Error)
	}
}

func TestRPCResponse_Error(t *testing.T) {
	resp := RPCResponse{
		Result: nil,
		Error:  "something failed",
	}
	if resp.Error != "something failed" {
		t.Errorf("Error = %q", resp.Error)
	}
}

func contains(slice []string, item string) bool {
	for _, s := range slice {
		if s == item {
			return true
		}
	}
	return false
}
