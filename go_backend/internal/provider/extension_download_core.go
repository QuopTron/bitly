package provider

import (
	"fmt"
)

type DownloadResult struct {
	Success   bool   `json:"success"`
	FilePath  string `json:"filePath"`
	Title     string `json:"title"`
	Artist    string `json:"artist"`
	Album     string `json:"album"`
	Encrypted bool   `json:"encrypted,omitempty"`
	// DecryptionKey is the optional key a provider supplies (e.g. amazon's
	// mov_key) to decrypt an encrypted stream into a playable file. Absent when
	// Si la descarga ya es reproducible o el proveedor no puede descifrar.
	DecryptionKey   string `json:"decryption_key,omitempty"`
	OutputExtension string `json:"output_extension,omitempty"`
	// InputFormat is the container the encrypted stream uses (e.g. "mov"),
	// informing the decrypt step which demuxer to force. Read from the nested
	// `decryption` object (or a top-level `input_format`) so any provider with
	// Para que una descarga encriptada/DRM pueda descifrarse bien, no solo amazon.
	InputFormat string `json:"input_format,omitempty"`
	Error       string `json:"error,omitempty"`
}

// Download invokes the extension's full download pipeline (JS download() function).
func (p *ExtensionProvider) Download(trackID, quality, outputPath string, onProgress func(int)) *DownloadResult {
	progressFn := func(percent float64) {
		if onProgress != nil {
			onProgress(int(percent))
		}
	}

	result, err := p.callOp("download", "download", trackID, quality, outputPath, progressFn)
	if err != nil {
		// cooldown already marked inside call(); a second mark here would
		// double the window via the backoff for a single 429 event.
		return &DownloadResult{Success: false, Error: fmt.Sprintf("ext %s download call failed: %v", p.extID, err)}
	}
	if result == nil {
		return &DownloadResult{Success: false, Error: "ext returned nil"}
	}

	m, ok := result.(map[string]interface{})
	if !ok {
		return &DownloadResult{Success: false, Error: fmt.Sprintf("ext returned unexpected type: %T", result)}
	}

	dr := &DownloadResult{}
	if s, ok := m["success"].(bool); ok {
		dr.Success = s
	}
	dr.FilePath = getString(m, "file_path", "filePath")
	dr.Title = getString(m, "title")
	dr.Artist = getString(m, "artist")
	dr.Album = getString(m, "album")
	if e, ok := m["encrypted"].(bool); ok {
		dr.Encrypted = e
	}
	dr.DecryptionKey = getString(m, "decryption_key")
	dr.OutputExtension = getString(m, "output_extension")
	if dec, ok := m["decryption"].(map[string]interface{}); ok {
		// Nested descriptor (strategy/key/input_format/output_extension) is the
		// richer form most providers emit; fall back to it for input_format.
		if dr.DecryptionKey == "" {
			dr.DecryptionKey = getString(dec, "key")
		}
		if dr.OutputExtension == "" {
			dr.OutputExtension = getString(dec, "output_extension")
		}
		dr.InputFormat = getString(dec, "input_format")
	}
	if dr.InputFormat == "" {
		dr.InputFormat = getString(m, "input_format")
	}
	if e, ok := m["error_message"].(string); ok && e != "" {
		dr.Error = e
	} else if e, ok := m["error"].(string); ok && e != "" {
		dr.Error = e
	}
	return dr
}
