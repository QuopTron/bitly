package audio

import (
	"encoding/binary"
	"strings"
)

func parsearItemsAPE(data []byte, numItems int) ([]APETagItem, error) {
	var items []APETagItem
	offset := 0
	for i := 0; i < numItems && offset < len(data); i++ {
		if offset+8 > len(data) {
			break
		}
		itemSize := int(binary.LittleEndian.Uint32(data[offset : offset+4]))
		itemFlag := binary.LittleEndian.Uint32(data[offset+4 : offset+8])
		offset += 8

		// Read null-terminated key
		keyStart := offset
		for offset < len(data) && data[offset] != 0 {
			offset++
		}
		if offset >= len(data) {
			break
		}
		key := string(data[keyStart:offset])
		offset++ // skip null

		// Read value
		if offset+itemSize > len(data) {
			break
		}
		value := make([]byte, itemSize)
		copy(value, data[offset:offset+itemSize])
		offset += itemSize

		items = append(items, APETagItem{
			Key:   strings.ToUpper(key),
			Value: value,
			Flag:  itemFlag,
		})
	}
	return items, nil
}

// Obtiene devuelve el valor para un clave (caso-insensitive).
