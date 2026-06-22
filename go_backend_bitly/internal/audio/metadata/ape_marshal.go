package metadata

import (
	"encoding/binary"
	"fmt"
)

func marshalAPETag(tag *APETag) ([]byte, error) {
	if tag == nil || len(tag.Items) == 0 {
		return nil, fmt.Errorf("empty APE tag")
	}

	var itemsData []byte
	for _, item := range tag.Items {
		keyBytes := []byte(item.Key)
		valueBytes := []byte(item.Value)

		sizeBuf := make([]byte, 4)
		binary.LittleEndian.PutUint32(sizeBuf, uint32(len(valueBytes)))

		flagsBuf := make([]byte, 4)
		binary.LittleEndian.PutUint32(flagsBuf, item.Flags)

		itemsData = append(itemsData, sizeBuf...)
		itemsData = append(itemsData, flagsBuf...)
		itemsData = append(itemsData, keyBytes...)
		itemsData = append(itemsData, 0)
		itemsData = append(itemsData, valueBytes...)
	}

	tagSize := uint32(len(itemsData) + apeTagHeaderSize)
	itemCount := uint32(len(tag.Items))

	version := uint32(apeTagVersion2)
	if tag.Version != 0 {
		version = tag.Version
	}

	headerFlags := uint32(apeTagFlagHeader | (1 << 31))
	header := buildAPEHeaderFooter(version, tagSize, itemCount, headerFlags)

	footerFlags := uint32(1 << 31)
	footer := buildAPEHeaderFooter(version, tagSize, itemCount, footerFlags)

	result := make([]byte, 0, len(header)+len(itemsData)+len(footer))
	result = append(result, header...)
	result = append(result, itemsData...)
	result = append(result, footer...)
	return result, nil
}

func buildAPEHeaderFooter(version, tagSize, itemCount, flags uint32) []byte {
	buf := make([]byte, apeTagHeaderSize)
	copy(buf[0:8], apeTagPreamble)
	binary.LittleEndian.PutUint32(buf[8:12], version)
	binary.LittleEndian.PutUint32(buf[12:16], tagSize)
	binary.LittleEndian.PutUint32(buf[16:20], itemCount)
	binary.LittleEndian.PutUint32(buf[20:24], flags)
	return buf
}
