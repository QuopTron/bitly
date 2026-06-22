package utils

import (
	"strings"
	"testing"
)

func TestSanitizeSensitiveLogText(t *testing.T) {
	tests := []struct {
		name    string
		message string
		want    string
	}{
		{
			name:    "no sensitive data",
			message: "normal log message",
			want:    "normal log message",
		},
		{
			name:    "authorization bearer header",
			message: `Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9`,
			want:    "Authorization: [REDACTED] [REDACTED]",
		},
		{
			name:    "authorization bearer with equals",
			message: `Authorization=Bearer some.token.here`,
			want:    "Authorization: [REDACTED] [REDACTED]",
		},
		{
			name:    "access token key-value",
			message: "access_token=secret123",
			want:    "access_token=[REDACTED]",
		},
		{
			name:    "refresh token key-value",
			message: "refresh_token=abc123",
			want:    "refresh_token=[REDACTED]",
		},
		{
			name:    "client secret key-value",
			message: "client_secret:supersecret",
			want:    "client_secret:[REDACTED]",
		},
		{
			name:    "api key key-value",
			message: "api_key=abc123def",
			want:    "api_key=[REDACTED]",
		},
		{
			name:    "password key-value",
			message: "password=hunter2",
			want:    "password=[REDACTED]",
		},
		{
			name:    "query token parameter",
			message: "https://example.com?access_token=secret&other=value",
			want:    "https://example.com?access_token=[REDACTED]",
		},
		{
			name:    "bearer token standalone",
			message: "Bearer eyJhbGciOiJIUzI1NiJ9",
			want:    "Bearer [REDACTED]",
		},
		{
			name:    "multiple sensitive patterns",
			message: `Authorization: Bearer token1; access_token=secret2`,
			want:    "Authorization: [REDACTED] [REDACTED]; access_token=[REDACTED]",
		},
		{
			name:    "id token key-value",
			message: "id_token=abc.def.ghi",
			want:    "id_token=[REDACTED]",
		},
		{
			name:    "case insensitive",
			message: "ACCESS_TOKEN=secret",
			want:    "ACCESS_TOKEN=[REDACTED]",
		},
		{
			name:    "empty string",
			message: "",
			want:    "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := sanitizeSensitiveLogText(tt.message)
			if got != tt.want {
				t.Errorf("sanitizeSensitiveLogText(%q) = %q, want %q", tt.message, got, tt.want)
			}
			if !strings.EqualFold(got, tt.want) && strings.Contains(got, "secret") {
				t.Errorf("sanitizeSensitiveLogText(%q) still contains 'secret': %q", tt.message, got)
			}
		})
	}
}
