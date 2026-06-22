package metadata

func base64StdDecodeLen(n int) int {
	return n * 6 / 8
}

func base64StdDecode(dst, src []byte) (int, error) {
	const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	decodeMap := make([]byte, 256)
	for i := range decodeMap {
		decodeMap[i] = 0xFF
	}
	for i := 0; i < len(alphabet); i++ {
		decodeMap[alphabet[i]] = byte(i)
	}
	si, di := 0, 0
	for si < len(src) {
		for si < len(src) && (src[si] == '\n' || src[si] == '\r' || src[si] == ' ' || src[si] == '\t') {
			si++
		}
		if si >= len(src) {
			break
		}
		var vals [4]byte
		var valCount int
		for valCount < 4 && si < len(src) {
			c := src[si]
			si++
			if c == '=' {
				vals[valCount] = 0
				valCount++
			} else if c == '\n' || c == '\r' || c == ' ' || c == '\t' {
				continue
			} else if decodeMap[c] != 0xFF {
				vals[valCount] = decodeMap[c]
				valCount++
			}
		}
		if valCount < 2 {
			break
		}
		if di < len(dst) {
			dst[di] = vals[0]<<2 | vals[1]>>4
			di++
		}
		if valCount >= 3 && di < len(dst) {
			dst[di] = vals[1]<<4 | vals[2]>>2
			di++
		}
		if valCount >= 4 && di < len(dst) {
			dst[di] = vals[2]<<6 | vals[3]
			di++
		}
	}
	return di, nil
}
