package core

func bestQualityFor(requested, provider string) string {
	if requested != "" {
		if _, ok := providerQualityRank[requested]; ok {
			return requested
		}
	}
	switch provider {
	case "deezer":
		return "flac"
	case "tidal":
		return "hifi"
	case "qobuz":
		return "flac"
	default:
		return "high"
	}
}
