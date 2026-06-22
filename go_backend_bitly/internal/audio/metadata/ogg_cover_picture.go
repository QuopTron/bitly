package metadata

import (
	"bytes"
	"encoding/binary"
	"io"
)

func parseFLACPictureBlock(data []byte) ([]byte, string) {
	if len(data) < 32 {
		return nil, ""
	}
	reader := bytes.NewReader(data)
	var pictureType uint32
	binary.Read(reader, binary.BigEndian, &pictureType)
	_ = pictureType

	var mimeLen uint32
	binary.Read(reader, binary.BigEndian, &mimeLen)
	if mimeLen > 256 {
		return nil, ""
	}
	mimeBytes := make([]byte, mimeLen)
	reader.Read(mimeBytes)
	mimeType := string(mimeBytes)

	var descLen uint32
	binary.Read(reader, binary.BigEndian, &descLen)
	if descLen > 10000 {
		return nil, ""
	}
	reader.Seek(int64(descLen), io.SeekCurrent)
	reader.Seek(16, io.SeekCurrent)

	var dataLen uint32
	binary.Read(reader, binary.BigEndian, &dataLen)
	if dataLen > 10000000 {
		return nil, ""
	}
	imageData := make([]byte, dataLen)
	reader.Read(imageData)
	return imageData, mimeType
}
