package extensions

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"net/url"
	"strings"

	"github.com/dop251/goja"
)

// registerAuth adds OAuth/PKCE helpers to the JS sandbox.
func registerAuth(s *Sandbox) {
	vm := s.VM
	authObj := vm.NewObject()

	authObj.Set("pkceChallenge", func(call goja.FunctionCall) goja.Value {
		verifier := call.Argument(0).String()
		h := sha256.Sum256([]byte(verifier))
		challenge := base64.RawURLEncoding.EncodeToString(h[:])
		return vm.ToValue(challenge)
	})

	authObj.Set("generateVerifier", func(call goja.FunctionCall) goja.Value {
		b := make([]byte, 32)
		rand.Read(b)
		return vm.ToValue(base64.RawURLEncoding.EncodeToString(b))
	})

	authObj.Set("buildAuthURL", func(call goja.FunctionCall) goja.Value {
		baseURL := call.Argument(0).String()
		clientID := call.Argument(1).String()
		redirectURI := call.Argument(2).String()
		state := call.Argument(3).String()
		challenge := call.Argument(4).String()

		params := url.Values{}
		params.Set("response_type", "code")
		params.Set("client_id", clientID)
		params.Set("redirect_uri", redirectURI)
		params.Set("state", state)
		params.Set("code_challenge", challenge)
		params.Set("code_challenge_method", "S256")

		if strings.Contains(baseURL, "?") {
			return vm.ToValue(baseURL + "&" + params.Encode())
		}
		return vm.ToValue(baseURL + "?" + params.Encode())
	})

	authObj.Set("basicAuth", func(call goja.FunctionCall) goja.Value {
		user := call.Argument(0).String()
		pass := call.Argument(1).String()
		auth := base64.StdEncoding.EncodeToString([]byte(user + ":" + pass))
		return vm.ToValue("Basic " + auth)
	})

	authObj.Set("bearerAuth", func(call goja.FunctionCall) goja.Value {
		token := call.Argument(0).String()
		return vm.ToValue("Bearer " + token)
	})

	vm.Set("auth", authObj)
}

// GenerateState creates a random state string for OAuth.
func GenerateState() string {
	b := make([]byte, 16)
	rand.Read(b)
	return fmt.Sprintf("%x", b)
}
