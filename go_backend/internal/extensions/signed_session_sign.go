package extensions

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

func hmacSHA256Bytes(key, message []byte) []byte {
	mac := hmac.New(sha256.New, key)
	mac.Write(message)
	return mac.Sum(nil)
}

// signedSessionURL resolves an endpoint against the config base URL.
func signedSessionURL(cfg SignedSessionConfig, endpoint string) (string, error) {
	base, err := url.Parse(strings.TrimRight(cfg.BaseURL, "/") + "/")
	if err != nil || base.Scheme != "https" || base.Host == "" {
		return "", errSignedSession("invalid signed session baseUrl")
	}
	endpoint = strings.TrimSpace(endpoint)
	if endpoint == "" {
		return "", errSignedSession("signed session endpoint is empty")
	}
	if strings.HasPrefix(endpoint, "https://") {
		return endpoint, nil
	}
	endpoint = strings.TrimLeft(endpoint, "/")
	ref, _ := url.Parse(endpoint)
	return base.ResolveReference(ref).String(), nil
}

type errSigned string

func (e errSigned) Error() string { return string(e) }

func errSignedSession(msg string) error { return errSigned(msg) }

// signAndBuildRequest applies the ZARZ-HMAC-V1 rolling HMAC signature.
func signAndBuildRequest(
	cfg SignedSessionConfig,
	record *signedSessionRecord,
	method, fullURL string,
	body []byte,
	extraHeaders map[string]string,
) (*http.Request, error) {
	parsed, err := url.Parse(fullURL)
	if err != nil {
		return nil, err
	}
	ts := time.Now().UTC().Format("2006-01-02T15:04:05.000Z")
	nonce := randomHex(12)
	bodyHashBytes := sha256.Sum256(body)
	bodyHash := hex.EncodeToString(bodyHashBytes[:])
	parsedTs, _ := time.Parse("2006-01-02T15:04:05.000Z", ts)
	window := parsedTs.Unix() / int64(cfg.TimeWindowSeconds)
	rollingInput := strconv.FormatInt(window, 10) + ":" + record.SessionID
	rk := base64.RawURLEncoding.EncodeToString(
		hmacSHA256Bytes([]byte(record.SessionSecret), []byte(rollingInput)),
	)
	signingInput := strings.Join([]string{
		cfg.SchemeLabel,
		strings.ToUpper(method),
		parsed.EscapedPath(),
		"",
		bodyHash,
		ts,
		nonce,
		record.SessionID,
		cfg.AppVersion,
		cfg.Platform,
	}, "\n")
	sig := base64.RawURLEncoding.EncodeToString(
		hmacSHA256Bytes([]byte(rk), []byte(signingInput)),
	)

	req, err := http.NewRequest(method, fullURL, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/json")
	if len(body) > 0 {
		req.Header.Set("Content-Type", "application/json")
	}
	req.Header.Set("User-Agent", "SpotiFLAC-Mobile/"+cfg.AppVersion)
	prefix := cfg.HeaderPrefix
	req.Header.Set(prefix+"Session", record.SessionID)
	req.Header.Set(prefix+"Timestamp", ts)
	req.Header.Set(prefix+"Nonce", nonce)
	req.Header.Set(prefix+"Body-SHA256", bodyHash)
	req.Header.Set(prefix+"Signature", sig)
	req.Header.Set(prefix+"App-Version", cfg.AppVersion)
	req.Header.Set(prefix+"Platform", cfg.Platform)
	for k, v := range extraHeaders {
		req.Header.Set(k, v)
	}
	return req, nil
}

func readSignedBody(resp *http.Response) ([]byte, error) {
	defer resp.Body.Close()
	return io.ReadAll(io.LimitReader(resp.Body, 32<<20))
}

func parseSignedErrorContract(body []byte) (signedSessionErrorContract, bool) {
	var contract signedSessionErrorContract
	if len(body) == 0 || jsonUnmarshal(body, &contract) != nil {
		return signedSessionErrorContract{}, false
	}
	contract.Code = strings.ToUpper(strings.TrimSpace(contract.Code))
	contract.Origin = strings.ToLower(strings.TrimSpace(contract.Origin))
	contract.Action = strings.ToLower(strings.TrimSpace(contract.Action))
	contract.RetryMode = strings.ToLower(strings.TrimSpace(contract.RetryMode))
	if contract.RetryAfterSeconds < 0 {
		contract.RetryAfterSeconds = 0
	}
	return contract, contract.Code != "" || contract.Origin != "" || contract.Action != ""
}

func signedRetryAfterSeconds(resp *http.Response) int {
	if resp == nil {
		return 0
	}
	value := strings.TrimSpace(resp.Header.Get("Retry-After"))
	if value == "" {
		return 0
	}
	if seconds, err := strconv.Atoi(value); err == nil && seconds >= 0 {
		return seconds
	}
	if retryAt, err := http.ParseTime(value); err == nil {
		seconds := int(time.Until(retryAt).Seconds())
		if seconds > 0 {
			return seconds
		}
	}
	return 0
}
