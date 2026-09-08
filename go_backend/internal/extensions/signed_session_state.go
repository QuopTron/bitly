package extensions

import (
	"sync"
	"time"
)

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
	lastBootstrap     time.Time
	bootstrapCooldown time.Duration
	lastAuthURL       string
	lastBootstrapErr  error

	// keepAliveMu serializes + paces the silent session keepalive (refresh
	// antes expiry / silent bootstrap). Guards lastKeepAlive y
	// keepAliveBackoffUntil so a periodic keepalive pass never hammers the
	// gateway or races with itself across threads (desktop RPC is concurrent).
	keepAliveMu sync.Mutex
	// lastKeepAlive is when the last keepalive attempt ran (pacing window).
	lastKeepAlive time.Time
	// keepAliveBackoffUntil suppresses keepalive attempts after a failure so a
	// dead endpoint isn't re-hit on every tick.
	keepAliveBackoffUntil time.Time
}

// bootstrapWithGuard performs a singleflight + cooldown-guarded bootstrap.
// Concurrent callers wait for the in-flight attempt; failed or
// verification-requiring attempts are cached so we back off instead of
// hammering /bootstrap (which the gateways rate-limit with HTTP 429).
