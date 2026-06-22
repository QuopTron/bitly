package metadata

import "encoding/binary"

func decodeUTF16(data []byte) string {
	if len(data) < 2 {
		return ""
	}
	var littleEndian bool
	if data[0] == 0xFF && data[1] == 0xFE {
		littleEndian = true
		data = data[2:]
	} else if data[0] == 0xFE && data[1] == 0xFF {
		littleEndian = false
		data = data[2:]
	}
	return decodeUTF16Data(data, littleEndian)
}

func decodeUTF16BE(data []byte) string {
	return decodeUTF16Data(data, false)
}

func decodeUTF16Data(data []byte, littleEndian bool) string {
	if len(data) < 2 {
		return ""
	}
	var runes []rune
	for i := 0; i+1 < len(data); i += 2 {
		var r uint16
		if littleEndian {
			r = uint16(data[i]) | uint16(data[i+1])<<8
		} else {
			r = uint16(data[i])<<8 | uint16(data[i+1])
		}
		if r == 0 {
			break
		}
		runes = append(runes, rune(r))
	}
	return string(runes)
}

func removeUnsync(data []byte) []byte {
	if len(data) == 0 {
		return data
	}
	out := make([]byte, 0, len(data))
	for i := 0; i < len(data); i++ {
		b := data[i]
		out = append(out, b)
		if b == 0xFF && i+1 < len(data) && data[i+1] == 0x00 {
			i++
		}
	}
	return out
}

func extendedHeaderSize(data []byte, version byte) int {
	if len(data) < 4 {
		return 0
	}
	var size int
	switch version {
	case 3:
		size = int(binary.BigEndian.Uint32(data[:4]))
	case 4:
		size = syncsafeToInt(data[:4])
	default:
		return 0
	}
	if size <= 0 {
		return 0
	}
	total := size + 4
	if total <= len(data) {
		return total
	}
	if size <= len(data) {
		return size
	}
	return 0
}

func syncsafeToInt(b []byte) int {
	if len(b) < 4 {
		return 0
	}
	return int(b[0])<<21 | int(b[1])<<14 | int(b[2])<<7 | int(b[3])
}
