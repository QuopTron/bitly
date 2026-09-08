package download

import "strings"

// classifyVerificationError reports whether an error message indicates the
// provider needs a signed-session / Cloudflare challenge to be completed. These
// are surfaced as verification_required so the client can open the modal instead
// of failing silently (the reference middleware pauses fallback on these).
func clasificarErrorVerificacion(errMsg string) string {
	if errMsg == "" {
		return ""
	}
	e := strings.ToLower(errMsg)
	for _, marker := range []string{
		"verification_required", "verify_required", "verification required",
		"needs verification", "needs_verification", "challenge", "cloudflare",
		"captcha", "signed session", "session not verified", "session expired",
		"session is not authenticated", "precondition required",
		"http 428", "http status 428",
		"status 428", "not verified",
	} {
		if strings.Contains(e, marker) {
			return "verification_required"
		}
	}
	return ""
}

// isOutputStorageWriteFailure reports whether an error indicates the output
// directory is unwritable (no space left, permission denied, read-only fs).
// Cuando este es el caso there es sin point trying más proveedores — el archivo// cannot be written regardless of the source — so the fallback loop should
// stop immediately instead of burning the remaining budget.
func esFalloEscrituraAlmacenamiento(errMsg string) bool {
	e := strings.ToLower(errMsg)
	for _, marker := range []string{
		"no space left on device", "disk full", "enospc",
		"permission denied", "eacces", "read-only file system", "erofs",
		"unable to create", "cannot create", "mkdir",
		"input/output error", "eio",
	} {
		if strings.Contains(e, marker) {
			return true
		}
	}
	return false
}

// isRateLimitError reports whether an error is a rate-limit / quota / bot
// detection that should pause fallback for this provider (via cooldown)
// instead of immediately trying the next source. Helps avoid burning the
// budget on a provider that will keep 429ing.
