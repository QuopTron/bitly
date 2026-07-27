package httpclient

import (
	"net"
	"time"

	utls "github.com/refraction-networking/utls"
)

// Well-known TLS fingerprint identifiers.
const (
	FingerprintChrome  = "chrome"
	FingerprintFirefox = "firefox"
	FingerprintSafari  = "safari"
	FingerprintIOS     = "ios"
	FingerprintAndroid = "android"
	FingerprintRandom  = "random"
	FingerprintEdge    = "edge"
)

// fingerprints maps string identifiers to utls ClientHelloID values.
var fingerprints = map[string]utls.ClientHelloID{
	FingerprintChrome:  utls.HelloChrome_Auto,
	FingerprintFirefox: utls.HelloFirefox_Auto,
	FingerprintSafari:  utls.HelloSafari_Auto,
	FingerprintIOS:     utls.HelloIOS_Auto,
	FingerprintAndroid: utls.HelloAndroid_11_OkHttp,
	FingerprintRandom:  utls.HelloRandomized,
	FingerprintEdge:    utls.HelloEdge_Auto,
}

// NewUTLSDialer returns a dial function that mimics the specified browser's
// TLS handshake. This is critical for bypassing Cloudflare and other bot
// detection systems.
func NewUTLSDialer(fingerprint string) func(network, addr string) (net.Conn, error) {
	helloID, ok := fingerprints[fingerprint]
	if !ok {
		helloID = utls.HelloChrome_Auto
	}

	return func(network, addr string) (net.Conn, error) {
		conn, err := (&net.Dialer{Timeout: 30 * time.Second}).Dial(network, addr)
		if err != nil {
			return nil, err
		}

		tlsConn := utls.UClient(conn, &utls.Config{
			InsecureSkipVerify: false,
		}, helloID)

		if err := tlsConn.Handshake(); err != nil {
			conn.Close()
			return nil, err
		}
		return tlsConn, nil
	}
}

// AvailableFingerprints returns the list of supported fingerprint identifiers.
func AvailableFingerprints() []string {
	keys := make([]string, 0, len(fingerprints))
	for k := range fingerprints {
		keys = append(keys, k)
	}
	return keys
}
