package audio

import (
	"encoding/binary"
	"fmt"
	"io"
	"os"
)

func ReadAPETags(path string) (*APETags, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	info, err := f.Stat()
	if err != nil {
		return nil, err
	}

	// APEv2 tag is at the end of the file (before ID3v1 if present)
	offset := info.Size()

	// Skip ID3v1 tag (128 bytes at end) if present
	id3v1 := make([]byte, 3)
	if _, err := f.ReadAt(id3v1, offset-128); err == nil && string(id3v1) == "TAG" {
		offset -= 128
	}

	// Read APEv2 footer
	if offset < apeFooterSize {
		return nil, fmt.Errorf("ERR_APE_ARCHIVO_PEQUENO: archivo demasiado pequeño para tag APE")
	}
	footer := make([]byte, apeFooterSize)
	if _, err := f.ReadAt(footer, offset-apeFooterSize); err != nil {
		return nil, err
	}

	if string(footer[0:8]) != apeHeaderMagic {
		return nil, fmt.Errorf("ERR_APE_NO_ENCONTRADO: no se encontró tag APEv2")
	}

	size := int64(binary.LittleEndian.Uint32(footer[8:12]))
	version := binary.LittleEndian.Uint32(footer[12:16])
	numItems := int(binary.LittleEndian.Uint32(footer[16:20]))
	flags := binary.LittleEndian.Uint32(footer[20:24])

	if version != 2000 {
		return nil, fmt.Errorf("ERR_APE_VERSION: versión APEv2 no soportada %d", version)
	}

	hasHeader := flags&apeFlagContainsHeader != 0
	tagStart := offset - apeFooterSize - size
	if hasHeader {
		tagStart -= apeHeaderSize
	}

	if tagStart < 0 {
		return nil, fmt.Errorf("ERR_APE_TAMANO_INVALIDO: tamaño de tag inválido")
	}

	// Read tag data
	tagData := make([]byte, size)
	if _, err := f.ReadAt(tagData, tagStart); err != nil {
		return nil, err
	}

	tags := &APETags{HasHeader: hasHeader}
	parsed, err := parsearItemsAPE(tagData, numItems)
	if err != nil {
		return nil, err
	}
	tags.Items = parsed
	return tags, nil
}

// ReadAPETagsFromReader reads APEv2 tags from an io.ReaderAt.
func ReadAPETagsFromReader(r io.ReaderAt, size int64) (*APETags, error) {
	if size < apeFooterSize {
		return nil, fmt.Errorf("ERR_APE_ARCHIVO_PEQUENO: demasiado pequeño para tag APE")
	}

	footer := make([]byte, apeFooterSize)
	if _, err := r.ReadAt(footer, size-apeFooterSize); err != nil {
		return nil, err
	}

	if string(footer[0:8]) != apeHeaderMagic {
		return nil, fmt.Errorf("ERR_APE_NO_ENCONTRADO: no se encontró tag APEv2")
	}

	tagSize := int64(binary.LittleEndian.Uint32(footer[8:12]))
	numItems := int(binary.LittleEndian.Uint32(footer[16:20]))
	flags := binary.LittleEndian.Uint32(footer[20:24])
	hasHeader := flags&apeFlagContainsHeader != 0

	tagStart := size - apeFooterSize - tagSize
	if hasHeader {
		tagStart -= apeHeaderSize
	}
	if tagStart < 0 {
		return nil, fmt.Errorf("ERR_APE_TAMANO_INVALIDO: tamaño de tag inválido")
	}

	tagData := make([]byte, tagSize)
	if _, err := r.ReadAt(tagData, tagStart); err != nil {
		return nil, err
	}

	tags := &APETags{HasHeader: hasHeader}
	parsed, err := parsearItemsAPE(tagData, numItems)
	if err != nil {
		return nil, err
	}
	tags.Items = parsed
	return tags, nil
}
