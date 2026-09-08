package audio

import (
	"bytes"
	"encoding/binary"
	"os"
	"strings"
)

func WriteAPETags(path string, tags *APETags) error {
	data := codificarItemsAPE(tags.Items)

	// Construye el pie
	footer := make([]byte, apeFooterSize)
	copy(footer[0:8], apeHeaderMagic)
	binary.LittleEndian.PutUint32(footer[8:12], uint32(len(data)))
	binary.LittleEndian.PutUint32(footer[12:16], 2000) // version 2.0
	binary.LittleEndian.PutUint32(footer[16:20], uint32(len(tags.Items)))
	binary.LittleEndian.PutUint32(footer[20:24], apeFlagContainsHeader)

	// Construye la cabecera (igual que el pie pero con el flag de cabecera)
	header := make([]byte, apeHeaderSize)
	copy(header[0:8], apeHeaderMagic)
	binary.LittleEndian.PutUint32(header[8:12], uint32(len(data)))
	binary.LittleEndian.PutUint32(header[12:16], 2000)
	binary.LittleEndian.PutUint32(header[16:20], uint32(len(tags.Items)))
	binary.LittleEndian.PutUint32(header[20:24], 0) // no footer flag

	// Lee el archivo existente
	existing, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	// Quita el tag APE existente si lo hay
	trimmed := quitarAPEAlFinal(existing)

	// Escribe: cabecera + datos + pie + contenido original
	var buf bytes.Buffer
	buf.Write(header)
	buf.Write(data)
	buf.Write(footer)
	buf.Write(trimmed)

	return SafeSaveFLAC(path, buf.Bytes())
}

func codificarItemsAPE(items []APETagItem) []byte {
	var buf bytes.Buffer
	for _, item := range items {
		keyBytes := []byte(strings.ToUpper(item.Key))
		buf.Write(keyBytes)
		buf.WriteByte(0)
		binary.Write(&buf, binary.LittleEndian, uint32(len(item.Value)))
		binary.Write(&buf, binary.LittleEndian, item.Flag)
		buf.Write(item.Value)
	}
	return buf.Bytes()
}

func quitarAPEAlFinal(data []byte) []byte {
	// Comprueba si hay un tag ID3v1 al final
	offset := len(data)
	if offset >= 128 && string(data[offset-128:offset-125]) == "TAG" {
		offset -= 128
	}

	// Comprueba si hay un footer APEv2
	if offset >= apeFooterSize {
		footer := data[offset-apeFooterSize : offset]
		if string(footer[0:8]) == apeHeaderMagic {
			size := int64(binary.LittleEndian.Uint32(footer[8:12]))
			flags := binary.LittleEndian.Uint32(footer[20:24])
			totalTagSize := size + apeFooterSize
			if flags&apeFlagContainsHeader != 0 {
				totalTagSize += apeHeaderSize
			}
			newOffset := offset - int(totalTagSize)
			if newOffset >= 0 {
				return data[:newOffset]
			}
		}
	}
	return data
}

// MergeAPEItems fusiona items nuevos con los existentes, preservando los no reemplazados.
