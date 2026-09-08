package streaming

// availableQualities returns the preferred quality plus a set of fallback
// qualities a provider is more likely to support (many providers only expose
// mp3/opus transcodes and fail on FLAC). The preferred one is tried first.
func calidadesDisponibles(preferred string) []string {
	seen := map[string]bool{}
	var out []string
	add := func(q string) {
		if q != "" && !seen[q] {
			seen[q] = true
			out = append(out, q)
		}
	}
	add(preferred)
	add("high")
	add("3")
	add("192")
	add("mp3")
	add("128")
	add("low")
	add("flac")
	return out
}
