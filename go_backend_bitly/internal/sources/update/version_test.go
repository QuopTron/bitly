package update

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

type testTransport struct {
	handler http.Handler
}

func (t *testTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	w := httptest.NewRecorder()
	t.handler.ServeHTTP(w, req)
	return w.Result(), nil
}

func testHTTPClient(handler http.Handler) *http.Client {
	return &http.Client{Transport: &testTransport{handler: handler}}
}

func TestParseVersionString(t *testing.T) {
	tests := []struct {
		in  string
		out []int
	}{
		{"1.2.3", []int{1, 2, 3}},
		{"v1.2.3", []int{1, 2, 3}},
		{"1.2.3.4", []int{1, 2, 3, 4}},
		{"abc", []int{0}},
		{"", []int{0}},
		{"1.2-beta", []int{1, 2}},
	}
	for _, tt := range tests {
		got := parseVersionString(tt.in)
		if len(got) != len(tt.out) {
			t.Errorf("parseVersionString(%q) = %v, want %v", tt.in, got, tt.out)
			continue
		}
		for i := range got {
			if got[i] != tt.out[i] {
				t.Errorf("parseVersionString(%q) = %v, want %v", tt.in, got, tt.out)
			}
		}
	}
}

func TestIsNewerVersion(t *testing.T) {
	tests := []struct {
		latest, current string
		want            bool
	}{
		{"v1.0.0", "v0.9.0", true},
		{"v0.9.0", "v1.0.0", false},
		{"v1.0.0", "v1.0.0", false},
		{"v1.0.1", "v1.0.0", true},
		{"v1.1.0", "v1.0.9", true},
		{"v2.0.0", "v1.9.9", true},
		{"1.0.0", "0.9.0", true},
		{"1.0.0", "2.0.0", false},
		{"1.0.0-beta", "1.0.0", false},
		{"1.0.0", "1.0.0-beta", true},
		{"1.0.0-alpha", "1.0.0-beta", false},
		{"0.0.0", "0.0.0", false},
	}
	for _, tt := range tests {
		got := isNewerVersion(tt.latest, tt.current)
		if got != tt.want {
			t.Errorf("isNewerVersion(%q, %q) = %v, want %v", tt.latest, tt.current, got, tt.want)
		}
	}
}
