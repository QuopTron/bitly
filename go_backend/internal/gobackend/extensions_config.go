package gobackend

import "encoding/json"

type SearchFilterConfig struct {
	ID    string `json:"id"`
	Label string `json:"label"`
	Icon  string `json:"icon"`
}

// SourceSearchConfig maps a source id to the search qualifiers declared in its
// manifest (searchBehavior), so Flutter can build the category bubbles per
// source exactly as the extension intends — the Bitly flow equivalent of
// SpotiFLAC reading the manifest.
type SourceSearchConfig struct {
	Source string `json:"source"`
	// Primary mirrors the manifest's searchBehavior.primary — the default
	// search source (SpotiFLAC's defaultSearchExtension). The UI preselects
	// it and the backend tries it first on a "Todas" search.
	Primary        bool                 `json:"primary"`
	ThumbnailRatio string               `json:"thumbnailRatio,omitempty"`
	Placeholder    string               `json:"placeholder,omitempty"`
	Filters        []SearchFilterConfig `json:"filters"`
}

// GetSearchConfig returns the search category bubbles for every bundled source
// that declares a searchBehavior. Sources without one (e.g. pandora) are
// omitted so the UI offers no bogus category chips for them.
func GetSearchConfig() string {
	out := make([]SourceSearchConfig, 0, len(bundledExts))
	for _, e := range bundledExts {
		if len(e.Search.Filters) == 0 {
			continue
		}
		cfg := SourceSearchConfig{
			Source:         e.ID,
			Primary:        e.Search.Primary,
			ThumbnailRatio: e.Search.ThumbnailRatio,
			Placeholder:    e.Search.Placeholder,
			Filters:        make([]SearchFilterConfig, 0, len(e.Search.Filters)),
		}
		for _, f := range e.Search.Filters {
			cfg.Filters = append(cfg.Filters, SearchFilterConfig{
				ID:    f.ID,
				Label: f.Label,
				Icon:  f.Icon,
			})
		}
		out = append(out, cfg)
	}
	data, err := json.Marshal(out)
	if err != nil {
		return `[]`
	}
	return string(data)
}
