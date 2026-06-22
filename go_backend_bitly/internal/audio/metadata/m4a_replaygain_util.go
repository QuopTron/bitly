package metadata

import (
	"encoding/binary"
	"fmt"
	"io"
	"math"
	"regexp"
	"strconv"
	"strings"
)

func buildM4AAtom(typ string, payload []byte) []byte {
	size := int64(8 + len(payload))
	buf := make([]byte, 8+len(payload))
	binary.BigEndian.PutUint32(buf[0:4], uint32(size))
	copy(buf[4:8], []byte(typ))
	copy(buf[8:], payload)
	return buf
}

func buildM4AFreeformAtom(name, value string) []byte {
	meanPayload := append([]byte{0, 0, 0, 0}, []byte("com.apple.iTunes")...)
	namePayload := append([]byte{0, 0, 0, 0}, []byte(name)...)
	dataPayload := make([]byte, 8+len(value))
	binary.BigEndian.PutUint32(dataPayload[0:4], 1)
	copy(dataPayload[8:], []byte(value))

	payload := buildM4AAtom("mean", meanPayload)
	payload = append(payload, buildM4AAtom("name", namePayload)...)
	payload = append(payload, buildM4AAtom("data", dataPayload)...)
	return buildM4AAtom("----", payload)
}

func writeAtomSize(buf []byte, header atomHeader, newSize int64) error {
	if newSize <= 0 {
		return fmt.Errorf("invalid size for %s", header.typ)
	}
	if header.headerSize == 16 {
		if int(header.offset)+16 > len(buf) {
			return io.ErrUnexpectedEOF
		}
		binary.BigEndian.PutUint32(buf[header.offset:header.offset+4], 1)
		binary.BigEndian.PutUint64(buf[header.offset+8:header.offset+16], uint64(newSize))
		return nil
	}
	if newSize > math.MaxUint32 {
		return fmt.Errorf("atom %s too large for 32-bit header", header.typ)
	}
	if int(header.offset)+8 > len(buf) {
		return io.ErrUnexpectedEOF
	}
	binary.BigEndian.PutUint32(buf[header.offset:header.offset+4], uint32(newSize))
	return nil
}

func collectM4AReplayGainFields(fields map[string]string) map[string]string {
	result := map[string]string{}
	if value := strings.TrimSpace(fields["replaygain_track_gain"]); value != "" {
		result["replaygain_track_gain"] = value
	}
	if value := strings.TrimSpace(fields["replaygain_track_peak"]); value != "" {
		result["replaygain_track_peak"] = value
	}
	if value := strings.TrimSpace(fields["replaygain_album_gain"]); value != "" {
		result["replaygain_album_gain"] = value
	}
	if value := strings.TrimSpace(fields["replaygain_album_peak"]); value != "" {
		result["replaygain_album_peak"] = value
	}
	if norm := buildITunNORMTag(result["replaygain_track_gain"], result["replaygain_track_peak"]); norm != "" {
		result["iTunNORM"] = norm
	}
	return result
}

func buildITunNORMTag(trackGain, trackPeak string) string {
	gainDb, ok := parseReplayGainDb(trackGain)
	if !ok {
		return ""
	}
	peakLinear, ok := parseReplayGainPeak(trackPeak)
	if !ok {
		return ""
	}
	clamp := func(v int64) int64 {
		if v < 0 {
			return 0
		}
		if v > 65534 {
			return 65534
		}
		return v
	}

	g1 := clamp(int64(math.Round(math.Pow(10, gainDb/-10.0) * 1000.0)))
	g2 := clamp(int64(math.Round(math.Pow(10, gainDb/-10.0) * 2500.0)))
	peak := clamp(int64(math.Round(peakLinear * 32768.0)))
	values := []int64{g1, g1, g2, g2, 0, 0, peak, peak, 0, 0}
	parts := make([]string, 0, len(values))
	for _, value := range values {
		parts = append(parts, strings.ToUpper(fmt.Sprintf("%08x", value)))
	}
	return strings.Join(parts, " ")
}

func parseReplayGainDb(value string) (float64, bool) {
	match := regexp.MustCompile(`([+-]?\d+(?:\.\d+)?)`).FindStringSubmatch(strings.TrimSpace(value))
	if len(match) < 2 {
		return 0, false
	}
	parsed, err := strconv.ParseFloat(match[1], 64)
	if err != nil {
		return 0, false
	}
	return parsed, true
}

func parseReplayGainPeak(value string) (float64, bool) {
	parsed, err := strconv.ParseFloat(strings.TrimSpace(value), 64)
	if err != nil || parsed <= 0 {
		return 0, false
	}
	return parsed, true
}
