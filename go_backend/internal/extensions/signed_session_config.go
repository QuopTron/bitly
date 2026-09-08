package extensions

import ()

func configSesionFirmadaConDefaults(cfg *SignedSessionConfig) SignedSessionConfig {
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
