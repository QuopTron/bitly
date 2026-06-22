package httpclient

import (
	"crypto/tls"
	"net"
	"net/http"
	"sync"
	"time"
)

type NetworkCompatibilityOptions struct {
	AllowHTTP   bool
	InsecureTLS bool
}

var (
	networkCompatibilityMu      sync.RWMutex
	networkCompatibilityOptions NetworkCompatibilityOptions
)

var sharedTransport = &http.Transport{
	DialContext: (&net.Dialer{
		Timeout:   30 * time.Second,
		KeepAlive: 30 * time.Second,
	}).DialContext,
	MaxIdleConns:          100,
	MaxIdleConnsPerHost:   10,
	MaxConnsPerHost:       20,
	IdleConnTimeout:       90 * time.Second,
	TLSHandshakeTimeout:   10 * time.Second,
	ExpectContinueTimeout: 1 * time.Second,
	ForceAttemptHTTP2:     true,
	WriteBufferSize:       64 * 1024,
	ReadBufferSize:        64 * 1024,
	DisableCompression:    true,
}

var metadataTransport = &http.Transport{
	DialContext: (&net.Dialer{
		Timeout:   30 * time.Second,
		KeepAlive: 30 * time.Second,
	}).DialContext,
	MaxIdleConns:          30,
	MaxIdleConnsPerHost:   5,
	MaxConnsPerHost:       10,
	IdleConnTimeout:       90 * time.Second,
	TLSHandshakeTimeout:   10 * time.Second,
	ExpectContinueTimeout: 1 * time.Second,
	ForceAttemptHTTP2:     true,
	WriteBufferSize:       32 * 1024,
	ReadBufferSize:        32 * 1024,
	DisableCompression:    true,
}

var DefaultClient = &http.Client{
	Transport: newCompatibilityTransport(sharedTransport),
	Timeout:   DefaultTimeout,
}

var DownloadClient = &http.Client{
	Transport: newCompatibilityTransport(sharedTransport),
	Timeout:   DownloadTimeout,
}

func NewClient(timeout time.Duration) *http.Client {
	return &http.Client{
		Transport: newCompatibilityTransport(sharedTransport),
		Timeout:   timeout,
	}
}

func NewMetadataClient(timeout time.Duration) *http.Client {
	return &http.Client{
		Transport: newCompatibilityTransport(metadataTransport),
		Timeout:   timeout,
	}
}

func GetSharedClient() *http.Client {
	return DefaultClient
}

func GetDownloadClient() *http.Client {
	return DownloadClient
}

func CloseIdleConnections() {
	sharedTransport.CloseIdleConnections()
	metadataTransport.CloseIdleConnections()
}

func SetNetworkCompatibilityOptions(allowHTTP, insecureTLS bool) {
	networkCompatibilityMu.Lock()
	networkCompatibilityOptions = NetworkCompatibilityOptions{
		AllowHTTP:   allowHTTP,
		InsecureTLS: insecureTLS,
	}
	networkCompatibilityMu.Unlock()
	applyTLSCompatibility(sharedTransport, insecureTLS)
	applyTLSCompatibility(metadataTransport, insecureTLS)
	CloseIdleConnections()
}

func GetNetworkCompatibilityOptions() NetworkCompatibilityOptions {
	networkCompatibilityMu.RLock()
	defer networkCompatibilityMu.RUnlock()
	return networkCompatibilityOptions
}

func applyTLSCompatibility(transport *http.Transport, insecureTLS bool) {
	if insecureTLS {
		cfg := &tls.Config{InsecureSkipVerify: true}
		if transport.TLSClientConfig != nil {
			cfg = transport.TLSClientConfig.Clone()
			cfg.InsecureSkipVerify = true
		}
		transport.TLSClientConfig = cfg
		return
	}
	transport.TLSClientConfig = nil
}
