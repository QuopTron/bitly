package tidal

import "strings"

var qualityPriority = []string{"HI_RES_LOSSLESS", "HI_RES", "LOSSLESS", "HIGH", "LOW"}

func GetQuality(quality string) string {
	q := strings.ToUpper(quality)
	for _, qp := range qualityPriority {
		if q == "LOSSLESS" && (qp == "LOSSLESS" || qp == "HI_RES" || qp == "HI_RES_LOSSLESS") {
			continue
		}
		if q == qp {
			return qp
		}
	}
	if quality == "24" || quality == "24/192" || quality == "24/96" || quality == "24/48" {
		return "HI_RES_LOSSLESS"
	}
	if quality == "16" || quality == "16/44" || quality == "16/44.1" {
		return "LOSSLESS"
	}
	return "LOSSLESS"
}

func QualityFallback(quality string) []string {
	seen := map[string]bool{}
	var chain []string
	normalized := GetQuality(quality)
	chain = append(chain, normalized)
	seen[normalized] = true
	for _, q := range qualityPriority {
		if !seen[q] {
			chain = append(chain, q)
			seen[q] = true
		}
	}
	return chain
}
