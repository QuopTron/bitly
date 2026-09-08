package audio

import (
	"bytes"
	"fmt"
	"os"
)

func WriteM4AFreeformTags(path string, tags map[string]string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	if len(data) < 8 || string(data[4:8]) != "ftyp" {
		return fmt.Errorf("ERR_M4A_INVALIDO: no es un archivo MP4/M4A valido")
	}

	var buf bytes.Buffer
	offset := 0

	for offset < len(data) {
		if offset+8 > len(data) {
			buf.Write(data[offset:])
			break
		}
		atomSize := int(data[offset])<<24 | int(data[offset+1])<<16 | int(data[offset+2])<<8 | int(data[offset+3])
		atomType := string(data[offset+4 : offset+8])

		if atomSize < 8 || offset+atomSize > len(data) {
			buf.Write(data[offset:])
			break
		}

		atomData := data[offset : offset+atomSize]

		switch atomType {
		case "moov":
			// Walk into moov to find udta
			newMoov, err := inyectarM4AUdta(atomData, tags)
			if err == nil {
				buf.Write(newMoov)
			} else {
				buf.Write(atomData)
			}
		default:
			buf.Write(atomData)
		}

		offset += atomSize
	}

	return SafeSaveFLAC(path, buf.Bytes())
}

func inyectarM4AUdta(moovAtom []byte, tags map[string]string) ([]byte, error) {
	var buf bytes.Buffer
	offset := 8 // skip moov header

	for offset < len(moovAtom) {
		if offset+8 > len(moovAtom) {
			buf.Write(moovAtom[offset:])
			break
		}
		atomSize := int(moovAtom[offset])<<24 | int(moovAtom[offset+1])<<16 | int(moovAtom[offset+2])<<8 | int(moovAtom[offset+3])
		atomType := string(moovAtom[offset+4 : offset+8])

		if atomSize < 8 || offset+atomSize > len(moovAtom) {
			buf.Write(moovAtom[offset:])
			break
		}

		atomData := moovAtom[offset : offset+atomSize]

		switch atomType {
		case "udta":
			newUdta := inyectarFreeformEnUdta(atomData, tags)
			buf.Write(newUdta)
		default:
			buf.Write(atomData)
		}

		offset += atomSize
	}

	return buf.Bytes(), nil
}
