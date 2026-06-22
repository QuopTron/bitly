package availability

// ResolveByISRC resolves an ISRC to platform URLs using available resolvers.
func (lr *LinkResolver) ResolveByISRC(isrc string) (*ISRCResolutionResult, error) {
	lr.mu.RLock()
	priority := lr.resolverPriority
	lr.mu.RUnlock()

	for _, resolver := range priority {
		var result *ISRCResolutionResult
		var err error

		switch resolver {
		case "deezer_songlink":
			result, err = lr.resolveViaDeezerSonglink(isrc)
		case "songstats":
			result, err = lr.resolveViaSongstats(isrc)
		}

		if err == nil && result != nil {
			if result.DeezerURL != "" || result.TidalURL != "" || result.QobuzURL != "" {
				result.Provider = resolver
				return result, nil
			}
		}
	}

	return &ISRCResolutionResult{ISRC: isrc}, nil
}
