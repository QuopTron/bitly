package artist

// Artist represents a music artist/band.
type Artist struct {
	ID             string                 `json:"id"`
	Name           string                 `json:"name"`
	NormalizedName string                 `json:"normalized_name"`
	ImageURL       string                 `json:"image_url,omitempty"`
	Metadata       map[string]interface{} `json:"metadata,omitempty"`
}
