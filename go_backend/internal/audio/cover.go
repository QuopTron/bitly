package audio

// CoverData holds cover art image data.
type CoverData struct {
	Data     []byte `json:"data"`
	MimeType string `json:"mimeType"`
	Width    int    `json:"width"`
	Height   int    `json:"height"`
}
