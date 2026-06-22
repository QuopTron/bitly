package runtime

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/dop251/goja"
)

var (
	extensionAuthState   = make(map[string]*ExtensionAuthState)
	extensionAuthStateMu sync.RWMutex
	pendingAuthRequests  = make(map[string]*PendingAuthRequest)
	pendingAuthRequestsMu sync.RWMutex
)

type ExtensionAuthState struct {
	PendingAuthURL  string
	AuthCode        string
	AccessToken     string
	RefreshToken    string
	ExpiresAt       time.Time
	IsAuthenticated bool
	PKCEVerifier    string
	PKCEChallenge   string
}

type PendingAuthRequest struct {
	ExtensionID string
	AuthURL     string
	CallbackURL string
}

func (ler *loadedExtensionRuntime) registerAuth() {
	authObj := ler.vm.NewObject()
	authObj.Set("openAuthUrl", ler.authOpenUrl)
	authObj.Set("getAuthCode", ler.authGetCode)
	authObj.Set("setAuthCode", ler.authSetCode)
	authObj.Set("clearAuth", ler.authClear)
	authObj.Set("isAuthenticated", ler.authIsAuthenticated)
	authObj.Set("getTokens", ler.authGetTokens)
	authObj.Set("generatePKCE", ler.authGeneratePKCE)
	authObj.Set("getPKCE", ler.authGetPKCE)
	authObj.Set("startOAuthWithPKCE", ler.authStartOAuthWithPKCE)
	authObj.Set("exchangeCodeWithPKCE", ler.authExchangeCodeWithPKCE)
	ler.vm.Set("auth", authObj)
}

func validateAuthURL(urlStr string) error {
	parsed, err := url.Parse(urlStr)
	if err != nil { return fmt.Errorf("invalid auth URL: %w", err) }
	if parsed.Scheme != "https" { return fmt.Errorf("invalid auth URL: only https is allowed") }
	if parsed.Hostname() == "" { return fmt.Errorf("invalid auth URL: hostname required") }
	if parsed.User != nil { return fmt.Errorf("invalid auth URL: embedded credentials not allowed") }
	return nil
}

func (ler *loadedExtensionRuntime) authOpenUrl(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "auth URL required"}) }
	authURL := call.Arguments[0].String()
	callbackURL := ""
	if len(call.Arguments) > 1 && !goja.IsUndefined(call.Arguments[1]) { callbackURL = call.Arguments[1].String() }
	if err := validateAuthURL(authURL); err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }
	pendingAuthRequestsMu.Lock()
	pendingAuthRequests[ler.extensionID] = &PendingAuthRequest{ExtensionID: ler.extensionID, AuthURL: authURL, CallbackURL: callbackURL}
	pendingAuthRequestsMu.Unlock()
	extensionAuthStateMu.Lock()
	state, exists := extensionAuthState[ler.extensionID]
	if !exists { state = &ExtensionAuthState{}; extensionAuthState[ler.extensionID] = state }
	state.PendingAuthURL = authURL
	state.AuthCode = ""
	extensionAuthStateMu.Unlock()
	return ler.vm.ToValue(map[string]interface{}{"success": true, "message": "Auth URL will be opened by the app"})
}

func (ler *loadedExtensionRuntime) authGetCode(call goja.FunctionCall) goja.Value {
	extensionAuthStateMu.RLock()
	defer extensionAuthStateMu.RUnlock()
	if state, exists := extensionAuthState[ler.extensionID]; exists && state.AuthCode != "" { return ler.vm.ToValue(state.AuthCode) }
	return goja.Undefined()
}

func (ler *loadedExtensionRuntime) authSetCode(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 { return ler.vm.ToValue(false) }
	arg := call.Arguments[0].Export()
	extensionAuthStateMu.Lock()
	defer extensionAuthStateMu.Unlock()
	state, exists := extensionAuthState[ler.extensionID]
	if !exists { state = &ExtensionAuthState{}; extensionAuthState[ler.extensionID] = state }
	switch v := arg.(type) {
	case string: state.AuthCode = v
	case map[string]interface{}:
		if code, ok := v["code"].(string); ok { state.AuthCode = code }
		if at, ok := v["access_token"].(string); ok { state.AccessToken = at; state.IsAuthenticated = true }
		if rt, ok := v["refresh_token"].(string); ok { state.RefreshToken = rt }
		if ei, ok := v["expires_in"].(float64); ok { state.ExpiresAt = time.Now().Add(time.Duration(ei) * time.Second) }
	}
	return ler.vm.ToValue(true)
}

func (ler *loadedExtensionRuntime) authClear(call goja.FunctionCall) goja.Value {
	extensionAuthStateMu.Lock()
	delete(extensionAuthState, ler.extensionID)
	extensionAuthStateMu.Unlock()
	pendingAuthRequestsMu.Lock()
	delete(pendingAuthRequests, ler.extensionID)
	pendingAuthRequestsMu.Unlock()
	return ler.vm.ToValue(true)
}

func (ler *loadedExtensionRuntime) authIsAuthenticated(call goja.FunctionCall) goja.Value {
	extensionAuthStateMu.RLock()
	defer extensionAuthStateMu.RUnlock()
	if state, exists := extensionAuthState[ler.extensionID]; exists {
		if state.IsAuthenticated && !state.ExpiresAt.IsZero() && time.Now().After(state.ExpiresAt) { return ler.vm.ToValue(false) }
		return ler.vm.ToValue(state.IsAuthenticated)
	}
	return ler.vm.ToValue(false)
}

func (ler *loadedExtensionRuntime) authGetTokens(call goja.FunctionCall) goja.Value {
	extensionAuthStateMu.RLock()
	defer extensionAuthStateMu.RUnlock()
	result := map[string]interface{}{}
	if state, exists := extensionAuthState[ler.extensionID]; exists {
		result["access_token"] = state.AccessToken
		result["refresh_token"] = state.RefreshToken
		result["is_authenticated"] = state.IsAuthenticated
		if !state.ExpiresAt.IsZero() { result["expires_at"] = state.ExpiresAt.Unix(); result["is_expired"] = time.Now().After(state.ExpiresAt) }
	}
	return ler.vm.ToValue(result)
}

func generatePKCEVerifier(length int) (string, error) {
	if length < 43 { length = 43 }
	if length > 128 { length = 128 }
	bytes := make([]byte, length)
	if _, err := rand.Read(bytes); err != nil { return "", err }
	verifier := base64.RawURLEncoding.EncodeToString(bytes)
	if len(verifier) > length { verifier = verifier[:length] }
	return verifier, nil
}

func generatePKCEChallenge(verifier string) string {
	hash := sha256.Sum256([]byte(verifier))
	return base64.RawURLEncoding.EncodeToString(hash[:])
}

func (ler *loadedExtensionRuntime) authGeneratePKCE(call goja.FunctionCall) goja.Value {
	length := 64
	if len(call.Arguments) > 0 && !goja.IsUndefined(call.Arguments[0]) {
		if l, ok := call.Arguments[0].Export().(float64); ok && l >= 43 && l <= 128 { length = int(l) }
	}
	verifier, err := generatePKCEVerifier(length)
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"error": err.Error()}) }
	challenge := generatePKCEChallenge(verifier)
	extensionAuthStateMu.Lock()
	state, exists := extensionAuthState[ler.extensionID]
	if !exists { state = &ExtensionAuthState{}; extensionAuthState[ler.extensionID] = state }
	state.PKCEVerifier = verifier
	state.PKCEChallenge = challenge
	extensionAuthStateMu.Unlock()
	return ler.vm.ToValue(map[string]interface{}{"verifier": verifier, "challenge": challenge, "method": "S256"})
}

func (ler *loadedExtensionRuntime) authGetPKCE(call goja.FunctionCall) goja.Value {
	extensionAuthStateMu.RLock()
	defer extensionAuthStateMu.RUnlock()
	if state, exists := extensionAuthState[ler.extensionID]; exists && state.PKCEVerifier != "" {
		return ler.vm.ToValue(map[string]interface{}{"verifier": state.PKCEVerifier, "challenge": state.PKCEChallenge, "method": "S256"})
	}
	return ler.vm.ToValue(map[string]interface{}{})
}

func (ler *loadedExtensionRuntime) authStartOAuthWithPKCE(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "config required"}) }
	config, ok := call.Arguments[0].Export().(map[string]interface{})
	if !ok { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "config must be an object"}) }
	authURL, _ := config["authUrl"].(string)
	clientID, _ := config["clientId"].(string)
	redirectURI, _ := config["redirectUri"].(string)
	if authURL == "" || clientID == "" || redirectURI == "" {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "authUrl, clientId, redirectUri required"})
	}
	if err := validateAuthURL(authURL); err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }
	scope, _ := config["scope"].(string)
	extraParams, _ := config["extraParams"].(map[string]interface{})
	verifier, err := generatePKCEVerifier(64)
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("PKCE failed: %v", err)}) }
	challenge := generatePKCEChallenge(verifier)
	extensionAuthStateMu.Lock()
	state, exists := extensionAuthState[ler.extensionID]
	if !exists { state = &ExtensionAuthState{}; extensionAuthState[ler.extensionID] = state }
	state.PKCEVerifier = verifier
	state.PKCEChallenge = challenge
	state.AuthCode = ""
	extensionAuthStateMu.Unlock()
	parsedURL, _ := url.Parse(authURL)
	q := parsedURL.Query()
	q.Set("client_id", clientID)
	q.Set("redirect_uri", redirectURI)
	q.Set("response_type", "code")
	q.Set("code_challenge", challenge)
	q.Set("code_challenge_method", "S256")
	if scope != "" { q.Set("scope", scope) }
	for k, v := range extraParams { q.Set(k, fmt.Sprintf("%v", v)) }
	parsedURL.RawQuery = q.Encode()
	pendingAuthRequestsMu.Lock()
	pendingAuthRequests[ler.extensionID] = &PendingAuthRequest{ExtensionID: ler.extensionID, AuthURL: parsedURL.String(), CallbackURL: redirectURI}
	pendingAuthRequestsMu.Unlock()
	return ler.vm.ToValue(map[string]interface{}{"success": true, "authUrl": parsedURL.String(), "pkce": map[string]interface{}{"verifier": verifier, "challenge": challenge, "method": "S256"}})
}

func (ler *loadedExtensionRuntime) authExchangeCodeWithPKCE(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "config required"}) }
	config, ok := call.Arguments[0].Export().(map[string]interface{})
	if !ok { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "config must be an object"}) }
	tokenURL, _ := config["tokenUrl"].(string)
	clientID, _ := config["clientId"].(string)
	redirectURI, _ := config["redirectUri"].(string)
	code, _ := config["code"].(string)
	if tokenURL == "" || clientID == "" || code == "" {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "tokenUrl, clientId, code required"})
	}
	extensionAuthStateMu.RLock()
	verifier := ""
	if state, exists := extensionAuthState[ler.extensionID]; exists { verifier = state.PKCEVerifier }
	extensionAuthStateMu.RUnlock()
	if verifier == "" { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "no PKCE verifier - call generatePKCE first"}) }
	if err := validateDomain(tokenURL, ler.manifest); err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }
	form := url.Values{}
	form.Set("grant_type", "authorization_code")
	form.Set("client_id", clientID)
	form.Set("code", code)
	form.Set("code_verifier", verifier)
	if redirectURI != "" { form.Set("redirect_uri", redirectURI) }
	if extraParams, ok := config["extraParams"].(map[string]interface{}); ok {
		for k, v := range extraParams { form.Set(k, fmt.Sprintf("%v", v)) }
	}
	req, err := http.NewRequest("POST", tokenURL, strings.NewReader(form.Encode()))
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("User-Agent", "Bitly-Extension/1.0")
	resp, err := ler.httpClient.Do(req)
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }
	var tokenResp map[string]interface{}
	if err := json.Unmarshal(body, &tokenResp); err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "failed to parse token response"}) }
	if errMsg, ok := tokenResp["error"].(string); ok {
		errDesc, _ := tokenResp["error_description"].(string)
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": errMsg, "error_description": errDesc})
	}
	accessToken, _ := tokenResp["access_token"].(string)
	if accessToken == "" { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "no access_token in response"}) }
	refreshToken, _ := tokenResp["refresh_token"].(string)
	expiresIn, _ := tokenResp["expires_in"].(float64)
	extensionAuthStateMu.Lock()
	state, exists := extensionAuthState[ler.extensionID]
	if !exists { state = &ExtensionAuthState{}; extensionAuthState[ler.extensionID] = state }
	state.AccessToken = accessToken
	state.RefreshToken = refreshToken
	state.IsAuthenticated = true
	if expiresIn > 0 { state.ExpiresAt = time.Now().Add(time.Duration(expiresIn) * time.Second) }
	state.PKCEVerifier = ""
	state.PKCEChallenge = ""
	extensionAuthStateMu.Unlock()
	result := map[string]interface{}{"success": true, "access_token": accessToken, "refresh_token": refreshToken}
	if expiresIn > 0 { result["expires_in"] = expiresIn }
	if s, ok := tokenResp["scope"].(string); ok { result["scope"] = s }
	if tt, ok := tokenResp["token_type"].(string); ok { result["token_type"] = tt }
	return ler.vm.ToValue(result)
}
