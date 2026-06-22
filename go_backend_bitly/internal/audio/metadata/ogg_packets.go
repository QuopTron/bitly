package metadata

import (
	"encoding/binary"
	"fmt"
	"os"
)

func collectOggPackets(file *os.File, maxPackets, maxPages int) ([][]byte, error) {
	const maxPacketSize = 10 * 1024 * 1024
	var packets [][]byte
	var cur []byte
	skipPacket := false

	for pageNum := 0; pageNum < maxPages && len(packets) < maxPackets; pageNum++ {
		page, err := readOggPageWithHeader(file)
		if err != nil {
			if len(packets) > 0 {
				return packets, nil
			}
			return nil, err
		}
		if page.headerType&0x01 == 0 && len(cur) > 0 {
			cur = nil
			skipPacket = false
		}

		offset := 0
		for _, seg := range page.segmentTable {
			segLen := int(seg)
			if offset+segLen > len(page.data) {
				return packets, fmt.Errorf("invalid ogg segment size")
			}
			if skipPacket {
				offset += segLen
				if segLen < 255 {
					skipPacket = false
				}
				continue
			}
			if len(cur)+segLen > maxPacketSize {
				cur = nil
				skipPacket = true
				offset += segLen
				if segLen < 255 {
					skipPacket = false
				}
				continue
			}
			cur = append(cur, page.data[offset:offset+segLen]...)
			offset += segLen
			if segLen < 255 {
				if len(cur) > 0 {
					packets = append(packets, cur)
				}
				cur = nil
				if len(packets) >= maxPackets {
					return packets, nil
				}
			}
		}
	}
	return packets, nil
}

func readLastOggGranulePosition(file *os.File, fileSize int64) int64 {
	searchSize := int64(65536)
	if searchSize > fileSize {
		searchSize = fileSize
	}
	buf := make([]byte, searchSize)
	offset := fileSize - searchSize
	if offset < 0 {
		offset = 0
	}
	n, err := file.ReadAt(buf, offset)
	if err != nil && n == 0 {
		return 0
	}
	buf = buf[:n]
	for i := n - 4; i >= 0; i-- {
		if buf[i] != 'O' || buf[i+1] != 'g' || buf[i+2] != 'g' || buf[i+3] != 'S' {
			continue
		}
		if i+27 > n {
			continue
		}
		headerType := buf[i+5]
		if headerType > 0x07 {
			continue
		}
		segCount := int(buf[i+26])
		headerLen := 27 + segCount
		if i+headerLen > n {
			continue
		}
		return int64(binary.LittleEndian.Uint64(buf[i+6 : i+14]))
	}
	return 0
}
