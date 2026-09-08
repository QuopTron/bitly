package extensions

import (
	"net/http"
)

func (s *SignedSessionState) doSignedRequest(
	client *http.Client,
	cfg SignedSessionConfig,
	record *signedSessionRecord,
	method, requestPath string,
	body []byte,
	extraHeaders map[string]string,
) (*http.Response, []byte, map[string]any, error) {
	fullURL, err := signedSessionURL(cfg, requestPath)
	if err != nil {
		return nil, nil, nil, err
	}
	req, err := signAndBuildRequest(cfg, record, method, fullURL, body, extraHeaders)
	if err != nil {
		return nil, nil, nil, err
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, nil, nil, err
	}
	respBody, err := readSignedBody(resp)
	if err != nil {
		return nil, nil, nil, err
	}
	headers := make(map[string]any)
	for k, v := range resp.Header {
		if len(v) == 1 {
			headers[k] = v[0]
		} else {
			headers[k] = v
		}
	}
	return resp, respBody, headers, nil
}

// signedFetch executes a signed request, handling bootstrap/verification and
// stale-session retries. It returns the JS-facing response object.
