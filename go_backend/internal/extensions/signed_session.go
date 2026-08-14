package extensions

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// SignedSessionState is the runtime state attached to a Sandbox that exposes
// the session.signedFetch/completeGrant API to JS extensions. It is a trimmed
// port of the SpotiFLAC-Mobile signed-session runtime (ZARZ-HMAC-V1 scheme).
type SignedSessionState struct {
	mu       sync.Mutex
	Record   *signedSessionRecord
	AuthURL  string
	Callback string
	Grant    string
	dataDir  string

	// bootstrapMu serializes /bootstrap attempts so concurrent streaming calls
	// don't hammer the gateway and trip HTTP 429 rate-limiting.
	bootstrapMu sync.Mutex
	// lastBootstrap caches the outcome of the last bootstrap attempt; after a
	// failure or VERIFY_REQUIRED we back off for bootstrapCooldown instead of
	// re-hitting the endpoint on every signed request.
	lastBootstrap    time.Time
	bootstrapCooldown time.Duration
	lastAuthURL      string
	lastBootstrapErr error
}

// bootstrapWithGuard performs a singleflight + cooldown-guarded bootstrap.
// Concurrent callers wait for the in-flight attempt; failed or
// verification-requiring attempts are cached so we back off instead of
// hammering /bootstrap (which the gateways rate-limit with HTTP 429).
func (s *SignedSessionState) bootstrapWithGuard(client *http.Client, cfg SignedSessionConfig, record *signedSessionRecord) (string, error) {
	s.bootstrapMu.Lock()
	defer s.bootstrapMu.Unlock()

	if !s.lastBootstrap.IsZero() {
		elapsed := time.Since(s.lastBootstrap)
		if elapsed < s.bootstrapCooldown {
			return s.lastAuthURL, s.lastBootstrapErr
		}
	}

	authURL, err := s.bootstrapSignedSession(client, cfg, record)
	s.lastBootstrap = time.Now()
	s.lastAuthURL = authURL
	switch {
	case err != nil:
		// Bootstrap failed (e.g. HTTP 429/5xx/network). Back off so repeated
		// streaming calls don't keep hammering a rate-limited gateway.
		s.lastBootstrapErr = err
		s.bootstrapCooldown = 30 * time.Second
	case authURL != "":
		// VERIFY_REQUIRED — needs a human challenge; don't re-bootstrap on
		// every request until the user completes verification.
		s.lastBootstrapErr = errSignedSession("verification required")
		s.bootstrapCooldown = 60 * time.Second
	default:
		// Successfully provisioned a silent session; the record now has a
		// SessionID so subsequent signedFetch calls won't bootstrap again.
		s.lastBootstrapErr = nil
		s.bootstrapCooldown = 0
	}
	return authURL, err
}

// persistRecord best-effort writes the current record to disk so the session
// survives restarts. It never fails the caller (read-only FS is fine).
func (s *SignedSessionState) persistRecord(cfg SignedSessionConfig) {
	if s.Record == nil {
		return
	}
	path, err := signedSessionFilePath(s.dataDir, cfg)
	if err != nil {
		return
	}
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return
	}
	data, _ := json.MarshalIndent(s.Record, "", "  ")
	_ = os.WriteFile(path, data, 0600)
}

type signedSessionRecord struct {
	InstallID     string `json:"install_id"`
	SessionID     string `json:"session_id,omitempty"`
	SessionSecret string `json:"session_secret,omitempty"`
	ExpiresAt     string `json:"expires_at,omitempty"`
	Namespace     string `json:"namespace,omitempty"`
	BaseURL       string `json:"base_url,omitempty"`
	AppVersion    string `json:"app_version,omitempty"`
	Platform      string `json:"platform,omitempty"`
}

type signedSessionExchangeResponse struct {
	SessionID     string `json:"session_id,omitempty"`
	SessionSecret string `json:"session_secret,omitempty"`
	ExpiresAt     string `json:"expires_at,omitempty"`
	ChallengeID   string `json:"challenge_id,omitempty"`
	ChallengeURL  string `json:"challenge_url,omitempty"`
	AuthURL       string `json:"auth_url,omitempty"`
	ServerNonce   string `json:"server_nonce,omitempty"`
}

type signedSessionErrorContract struct {
	Error             string `json:"error,omitempty"`
	Code              string `json:"code,omitempty"`
	Origin            string `json:"origin,omitempty"`
	Action            string `json:"action,omitempty"`
	Retryable         bool   `json:"retryable,omitempty"`
	RetryMode         string `json:"retry_mode,omitempty"`
	RetryAfterSeconds int    `json:"retry_after_seconds,omitempty"`
}

func signedSessionConfigWithDefaults(cfg *SignedSessionConfig) SignedSessionConfig {
	if cfg == nil {
		return SignedSessionConfig{}
	}
	resolved := *cfg
	if resolved.AppVersion == "" {
		resolved.AppVersion = "ext-1.0"
	}
	if resolved.Platform == "" {
		resolved.Platform = "extension"
	}
	if resolved.CallbackURL == "" {
		resolved.CallbackURL = "spotiflac://session-grant"
	}
	// Desktop overrides the manifest callback with a loopback URL (set via
	// SetSignedSessionCallbackURL before any bootstrap). Mobile keeps the
	// spotiflac:// deep link.
	signedSessionCallbackURLMu.RLock()
	cbOverride := signedSessionCallbackURL
	signedSessionCallbackURLMu.RUnlock()
	if cbOverride != "" {
		resolved.CallbackURL = cbOverride
	}
	if resolved.SchemeLabel == "" {
		resolved.SchemeLabel = "ZARZ-HMAC-V1"
	}
	if resolved.HeaderPrefix == "" {
		resolved.HeaderPrefix = "X-Zarz-"
	}
	if resolved.TimeWindowSeconds <= 0 {
		resolved.TimeWindowSeconds = 300
	}
	if resolved.Endpoints.Bootstrap == "" {
		resolved.Endpoints.Bootstrap = "/bootstrap"
	}
	if resolved.Endpoints.Challenge == "" {
		resolved.Endpoints.Challenge = "/challenge"
	}
	if resolved.Endpoints.Exchange == "" {
		resolved.Endpoints.Exchange = "/session/exchange"
	}
	if resolved.Endpoints.Refresh == "" {
		resolved.Endpoints.Refresh = "/session/refresh"
	}
	return resolved
}

// signedSessionFilePath returns the persistence path for a session record.
func signedSessionFilePath(dataDir string, cfg SignedSessionConfig) (string, error) {
	// Prefer the explicit writable base dir (set by Flutter's
	// setDownloadDirectory). Embedded sandboxes run with dataDir "." on
	// Android (cwd "/", read-only), so without this override the verified
	// Cloudflare session can never be persisted and the captcha is requested
	// again on every launch.
	base := dataDir
	signedSessionBaseDirMu.RLock()
	if override := signedSessionBaseDir; override != "" {
		base = override
	}
	signedSessionBaseDirMu.RUnlock()

	namespace := sanitizeSignedSessionNamespace(cfg.Namespace)
	if namespace == "" {
		return "", fmt.Errorf("signed session namespace is empty")
	}
	scope := strings.Join([]string{
		namespace,
		strings.ToLower(strings.TrimSpace(cfg.BaseURL)),
		strings.ToLower(strings.TrimSpace(cfg.AppVersion)),
		strings.ToLower(strings.TrimSpace(cfg.Platform)),
	}, "\n")
	sum := sha256.Sum256([]byte(scope))
	dir := filepath.Join(base, "signed_sessions")
	return filepath.Join(dir, namespace+"-"+hex.EncodeToString(sum[:])[:16]+".json"), nil
}

var (
	signedSessionBaseDirMu    sync.RWMutex
	signedSessionBaseDir      string
	signedSessionCallbackURLMu sync.RWMutex
	signedSessionCallbackURL  string
)

// SetSignedSessionCallbackURL overrides the callback URL used when building
// Cloudflare challenge URLs (instead of the manifest's callbackUrl). Desktop
// builds point it at a loopback HTTP server so the grant returns to the app
// without a custom URI scheme; keep empty on mobile to use the spotiflac://
// deep link from the manifest.
func SetSignedSessionCallbackURL(url string) {
	signedSessionCallbackURLMu.Lock()
	signedSessionCallbackURL = strings.TrimSpace(url)
	signedSessionCallbackURLMu.Unlock()
}

// SetSignedSessionDataDir re-points signed-session persistence to a writable
// directory. Without it, embedded sandboxes (dataDir "." on Android) cannot
// persist the Cloudflare-verified session, so every launch regenerates a new
// install_id and re-requests human verification. Call it with the app's real
// writable dir (e.g. from Flutter's setDownloadDirectory) before any streaming.
func SetSignedSessionDataDir(dir string) {
	trimmed := strings.TrimSpace(dir)
	signedSessionBaseDirMu.Lock()
	signedSessionBaseDir = trimmed
	signedSessionBaseDirMu.Unlock()
}

func sanitizeSignedSessionNamespace(namespace string) string {
	namespace = strings.ToLower(strings.TrimSpace(namespace))
	var b strings.Builder
	for _, ch := range namespace {
		if (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') || ch == '-' || ch == '_' || ch == '.' {
			b.WriteRune(ch)
		}
	}
	return strings.Trim(b.String(), ".-_")
}

func randomHex(bytesLen int) string {
	buf := make([]byte, bytesLen)
	if _, err := rand.Read(buf); err != nil {
		return fmt.Sprintf("%d", time.Now().UnixNano())
	}
	return hex.EncodeToString(buf)
}

func parseSignedSessionTime(value string) (time.Time, bool) {
	value = strings.TrimSpace(value)
	if value == "" {
		return time.Time{}, false
	}
	layouts := []string{time.RFC3339Nano, time.RFC3339, "2006-01-02T15:04:05.000Z"}
	for _, layout := range layouts {
		if parsed, err := time.Parse(layout, value); err == nil {
			return parsed, true
		}
	}
	return time.Time{}, false
}

func signedSessionRecordIsUsable(record *signedSessionRecord) bool {
	if record == nil || strings.TrimSpace(record.SessionID) == "" ||
		strings.TrimSpace(record.SessionSecret) == "" {
		return false
	}
	if expiresAt, ok := parseSignedSessionTime(record.ExpiresAt); ok {
		return time.Now().Before(expiresAt)
	}
	return true
}

func (s *SignedSessionState) loadOrInit(dataDir string, cfg SignedSessionConfig) (*signedSessionRecord, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.dataDir = dataDir
	path, err := signedSessionFilePath(dataDir, cfg)
	if err != nil {
		return nil, err
	}
	record := &signedSessionRecord{}
	// Reuse the in-memory record when available so the install_id (and any
	// exchanged session) stays stable between bootstrap and grant exchange.
	// This matters when the data dir is not writable (embedded sandboxes are
	// created with dataDir "." on Android before Flutter provides the real
	// path) — otherwise every loadOrInit would generate a NEW install_id and
	// the exchange would be rejected because the grant belongs to the
	// bootstrap's install_id.
	if s.Record != nil {
		record = s.Record
	} else if data, err := os.ReadFile(path); err == nil {
		_ = json.Unmarshal(data, record)
	}
	if strings.TrimSpace(record.InstallID) == "" {
		record.InstallID = randomHex(16)
	}
	// If the record belongs to a different scope (namespace/baseURL/
	// appVersion/platform), the stored session does not apply — reset it.
	scopeChanged := record.Namespace != sanitizeSignedSessionNamespace(cfg.Namespace) ||
		record.BaseURL != strings.TrimSpace(cfg.BaseURL) ||
		record.AppVersion != strings.TrimSpace(cfg.AppVersion) ||
		record.Platform != strings.TrimSpace(cfg.Platform)
	if scopeChanged {
		record.SessionID = ""
		record.SessionSecret = ""
		record.ExpiresAt = ""
	}
	record.Namespace = sanitizeSignedSessionNamespace(cfg.Namespace)
	record.BaseURL = strings.TrimSpace(cfg.BaseURL)
	record.AppVersion = strings.TrimSpace(cfg.AppVersion)
	record.Platform = strings.TrimSpace(cfg.Platform)
	s.Record = record
	// Persist when possible; never fail the call on a read-only filesystem
	// (e.g. Android bundled extensions with dataDir ".").
	s.persistRecord(cfg)
	return record, nil
}
