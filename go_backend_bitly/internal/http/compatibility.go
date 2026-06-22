package httpclient

import (
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
)

type compatibilityTransport struct {
	base http.RoundTripper
}

func newCompatibilityTransport(base http.RoundTripper) http.RoundTripper {
	return &compatibilityTransport{base: base}
}

func (t *compatibilityTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	if req == nil || req.URL == nil {
		return t.base.RoundTrip(req)
	}

	opts := GetNetworkCompatibilityOptions()
	if !opts.AllowHTTP || req.URL.Scheme != "https" {
		return t.base.RoundTrip(req)
	}

	resp, err := t.base.RoundTrip(req)
	if err == nil {
		return resp, nil
	}

	if !canFallbackToHTTP(req) {
		return nil, err
	}

	fallbackReq, cloneErr := cloneRequestWithHTTPScheme(req, "http")
	if cloneErr != nil {
		return nil, err
	}

	return t.base.RoundTrip(fallbackReq)
}

func canFallbackToHTTP(req *http.Request) bool {
	if req == nil {
		return false
	}
	switch strings.ToUpper(req.Method) {
	case http.MethodGet, http.MethodHead, http.MethodOptions, http.MethodDelete:
		return true
	default:
		return req.GetBody != nil
	}
}

func cloneRequestWithHTTPScheme(req *http.Request, scheme string) (*http.Request, error) {
	reqCopy := req.Clone(req.Context())
	if req.Body != nil && req.GetBody != nil {
		bodyCopy, err := req.GetBody()
		if err != nil {
			return nil, err
		}
		reqCopy.Body = bodyCopy
	}
	urlCopy := *req.URL
	urlCopy.Scheme = scheme
	reqCopy.URL = &urlCopy
	return reqCopy, nil
}

func DoRequest(client *http.Client, req *http.Request) (*http.Response, error) {
	req.Header.Set("User-Agent", UserAgentForURL(req.URL))
	return client.Do(req)
}

type ISPBlockingError struct {
	Domain      string
	Reason      string
	OriginalErr error
}

func (e *ISPBlockingError) Error() string {
	return fmt.Sprintf("ISP blocking detected for %s: %s", e.Domain, e.Reason)
}

func IsISPBlocking(err error, requestURL string) *ISPBlockingError {
	if err == nil {
		return nil
	}
	domain := extractDomain(requestURL)
	return &ISPBlockingError{
		Domain:      domain,
		Reason:      err.Error(),
		OriginalErr: err,
	}
}

func extractDomain(rawURL string) string {
	if rawURL == "" {
		return "unknown"
	}
	parsed, err := url.Parse(rawURL)
	if err != nil {
		rawURL = strings.TrimPrefix(rawURL, "https://")
		rawURL = strings.TrimPrefix(rawURL, "http://")
		if idx := strings.Index(rawURL, "/"); idx > 0 {
			return rawURL[:idx]
		}
		return rawURL
	}
	if parsed.Host != "" {
		return parsed.Host
	}
	return "unknown"
}

func ReadResponseBody(resp *http.Response) ([]byte, error) {
	if resp == nil {
		return nil, fmt.Errorf("response is nil")
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response body: %w", err)
	}
	if len(body) == 0 {
		return nil, fmt.Errorf("response body is empty")
	}
	return body, nil
}
