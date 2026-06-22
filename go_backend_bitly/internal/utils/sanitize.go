package utils

import "regexp"

var (
	authorizationBearerPattern = regexp.MustCompile(`(?i)\bAuthorization\b\s*[:=]\s*Bearer\s+[A-Za-z0-9._~+/\-]+=*`)
	genericKeyValuePattern     = regexp.MustCompile(`(?i)\b(access[_\s-]?token|refresh[_\s-]?token|id[_\s-]?token|client[_\s-]?secret|authorization|password|api[_\s-]?key)\b(\s*[:=]\s*)([^\s,;]+)`)
	queryTokenPattern          = regexp.MustCompile(`(?i)([?&](?:access_token|refresh_token|id_token|token|client_secret|api_key|apikey|password)=)[^&\s]+`)
	bearerTokenPattern         = regexp.MustCompile(`(?i)\bBearer\s+[A-Za-z0-9._~+/\-]+=*`)
)

func sanitizeSensitiveLogText(message string) string {
	redacted := message
	redacted = authorizationBearerPattern.ReplaceAllString(redacted, "Authorization: Bearer [REDACTED]")
	redacted = genericKeyValuePattern.ReplaceAllString(redacted, `${1}${2}[REDACTED]`)
	redacted = queryTokenPattern.ReplaceAllString(redacted, `${1}[REDACTED]`)
	redacted = bearerTokenPattern.ReplaceAllString(redacted, "Bearer [REDACTED]")
	return redacted
}
