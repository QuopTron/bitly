package runtime

import (
	"fmt"
	"testing"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/manifest"
)

var authTestCounter int

func authTestVM(t *testing.T, jsCode string) {
	t.Helper()
	authTestCounter++
	id := fmt.Sprintf("auth%d", authTestCounter)
	r := NewExtensionRuntime()
	jsPath := writeTestJS(t, `var extension = { test: function() {`+jsCode+`} };`)
	mf := &manifest.ExtensionManifest{}
	if err := r.LoadExtensionWithDirs(id, jsPath, t.TempDir(), t.TempDir(), mf); err != nil {
		t.Fatal(err)
	}
	if _, err := r.CallMethod(id, "test"); err != nil {
		t.Fatal(err)
	}
	r.UnloadExtension(id)
	extensionAuthStateMu.Lock()
	delete(extensionAuthState, id)
	extensionAuthStateMu.Unlock()
	pendingAuthRequestsMu.Lock()
	delete(pendingAuthRequests, id)
	pendingAuthRequestsMu.Unlock()
}

func TestAuth_NotAuthenticated(t *testing.T) {
	authTestVM(t, `
		var authed = auth.isAuthenticated();
		if (authed !== false) throw new Error("should not be authenticated");
	`)
}

func TestAuth_GetTokensEmpty(t *testing.T) {
	authTestVM(t, `
		var tokens = auth.getTokens();
		if (typeof tokens !== "object") throw new Error("should return object");
		if (tokens.is_authenticated === true) throw new Error("should not be authenticated");
	`)
}

func TestAuth_SetCodeString(t *testing.T) {
	authTestVM(t, `
		var ok = auth.setAuthCode("my-auth-code");
		if (ok !== true) throw new Error("setAuthCode failed");
		var code = auth.getAuthCode();
		if (code !== "my-auth-code") throw new Error("getAuthCode: " + code);
	`)
}

func TestAuth_SetCodeObject(t *testing.T) {
	authTestVM(t, `
		var ok = auth.setAuthCode({code: "c1", access_token: "at1", refresh_token: "rt1", expires_in: 3600});
		if (ok !== true) throw new Error("setAuthCode failed");
		if (auth.getAuthCode() !== "c1") throw new Error("code");
		var tokens = auth.getTokens();
		if (tokens.access_token !== "at1") throw new Error("access_token");
		if (tokens.refresh_token !== "rt1") throw new Error("refresh_token");
		if (tokens.is_authenticated !== true) throw new Error("not authenticated");
	`)
}

func TestAuth_GetCodeBeforeSet(t *testing.T) {
	authTestVM(t, `
		var code = auth.getAuthCode();
		if (code != null && code !== undefined) throw new Error("should be nil/undefined before set, got: " + code);
	`)
}

func TestAuth_Clear(t *testing.T) {
	authTestVM(t, `
		auth.setAuthCode("code123");
		if (auth.getAuthCode() !== "code123") throw new Error("should have code");
		auth.clearAuth();
		if (auth.getAuthCode() !== undefined) throw new Error("should be cleared");
		if (auth.isAuthenticated() !== false) throw new Error("should not be authed after clear");
	`)
}

func TestAuth_PKCE_Generate(t *testing.T) {
	authTestVM(t, `
		var pkce = auth.generatePKCE();
		if (!pkce.verifier) throw new Error("no verifier");
		if (!pkce.challenge) throw new Error("no challenge");
		if (pkce.method !== "S256") throw new Error("method: " + pkce.method);
		if (pkce.verifier.length < 40) throw new Error("verifier too short: " + pkce.verifier.length);
	`)
}

func TestAuth_PKCE_CustomLength(t *testing.T) {
	authTestVM(t, `
		var pkce = auth.generatePKCE(100);
		if (pkce.verifier.length > 100) throw new Error("too long: " + pkce.verifier.length);
	`)
}

func TestAuth_PKCE_Get(t *testing.T) {
	authTestVM(t, `
		var pkce = auth.generatePKCE();
		var pkce2 = auth.getPKCE();
		if (pkce2.verifier !== pkce.verifier) throw new Error("verifier mismatch");
		if (pkce2.challenge !== pkce.challenge) throw new Error("challenge mismatch");
	`)
}

func TestAuth_IsAuthenticatedAfterSet(t *testing.T) {
	authTestVM(t, `
		auth.setAuthCode({code: "c", access_token: "at", refresh_token: "rt", expires_in: 3600});
		if (!auth.isAuthenticated()) throw new Error("should be authenticated");
	`)
}

func TestAuth_OpenUrl(t *testing.T) {
	authTestVM(t, `
		var result = auth.openAuthUrl("https://example.com/auth");
		if (result.success !== true) throw new Error("openUrl failed: " + JSON.stringify(result));
	`)
}

func TestAuth_OpenUrl_RejectsHttp(t *testing.T) {
	authTestVM(t, `
		var result = auth.openAuthUrl("http://example.com/auth");
		if (result.success === true) throw new Error("http should be rejected");
	`)
}

func TestAuth_StartOAuthWithPKCE(t *testing.T) {
	authTestVM(t, `
		var result = auth.startOAuthWithPKCE({
			authUrl: "https://accounts.example.com/authorize",
			clientId: "myclient",
			redirectUri: "https://myapp/callback",
			scope: "read write"
		});
		if (result.success !== true) throw new Error("startOAuth failed: " + JSON.stringify(result));
		if (!result.authUrl) throw new Error("no authUrl returned");
		if (result.authUrl.indexOf("client_id=myclient") < 0) throw new Error("missing client_id");
		if (result.authUrl.indexOf("code_challenge_method=S256") < 0) throw new Error("missing code_challenge_method");
	`)
}
