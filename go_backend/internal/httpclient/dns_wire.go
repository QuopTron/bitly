package httpclient

import (
	"encoding/binary"
	"fmt"
	"net"
	"strings"
)

func consultaWireDNS(hostname string) []byte {
	header := make([]byte, 12)
	binary.BigEndian.PutUint16(header[0:2], 0xABCD)
	binary.BigEndian.PutUint16(header[2:4], 0x0100)
	binary.BigEndian.PutUint16(header[4:6], 1)

	var qname []byte
	for _, label := range strings.Split(hostname, ".") {
		qname = append(qname, byte(len(label)))
		qname = append(qname, []byte(label)...)
	}
	qname = append(qname, 0)

	question := make([]byte, 0, len(qname)+4)
	question = append(question, qname...)
	question = append(question, 0, 1) // QTYPE = A
	question = append(question, 0, 1) // QCLASS = IN

	return append(header, question...)
}

func parsearRespuestaWire(data []byte) ([]net.IP, error) {
	if len(data) < 12 {
		return nil, fmt.Errorf("dns: response too short")
	}
	ancount := int(binary.BigEndian.Uint16(data[6:8]))
	if ancount == 0 {
		return nil, fmt.Errorf("dns: no A records")
	}
	offset := 12
	for offset < len(data) {
		if data[offset] == 0 {
			offset++
			break
		}
		if data[offset]&0xC0 == 0xC0 {
			offset += 2
			break
		}
		offset += int(data[offset]) + 1
	}
	offset += 4

	var ips []net.IP
	for i := 0; i < ancount && offset < len(data); i++ {
		if offset < len(data) && data[offset]&0xC0 == 0xC0 {
			offset += 2
		} else {
			for offset < len(data) && data[offset] != 0 {
				offset += int(data[offset]) + 1
			}
			offset++
		}
		if offset+10 > len(data) {
			break
		}
		rType := binary.BigEndian.Uint16(data[offset : offset+2])
		offset += 2
		offset += 2
		offset += 4
		rdLength := int(binary.BigEndian.Uint16(data[offset : offset+2]))
		offset += 2
		if rType == 1 && rdLength == 4 && offset+4 <= len(data) {
			ips = append(ips, net.IP(data[offset:offset+4]))
		}
		offset += rdLength
	}
	if len(ips) == 0 {
		return nil, fmt.Errorf("dns: no A records parsed")
	}
	return ips, nil
}

// ClearCache removes all cached DNS entries.
func (dm *DNSManager) ClearCache() {
	dm.mutexCache.Lock()
	defer dm.mutexCache.Unlock()
	dm.almacenCache = make(map[string]*entradaCacheDNS)
}

// ═══════════════════════════════════════════════════════════════════════
// Legacy API — backward-compatible functions
// ═══════════════════════════════════════════════════════════════════════

// DoHResolver resolves hostnames via DNS-over-HTTPS (legacy API).
