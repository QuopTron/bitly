package audio

import (
	"bytes"
	"fmt"
	"os"
)

func writeMP4Cover(filePath string, coverData []byte) error {
	f, err := os.ReadFile(filePath)
	if err != nil {
		return err
	}

	moovPos := findAtom(f, "moov")
	if moovPos < 0 {
		return fmt.Errorf("cover: no moov atom found")
	}

	udtaPos := findAtomIn(f[moovPos:], "udta")
	if udtaPos >= 0 {
		absUdta := moovPos + udtaPos
		metaPos := findAtomIn(f[absUdta:], "meta")
		if metaPos >= 0 {
			absMeta := absUdta + metaPos
			ilstPos := findAtomIn(f[absMeta:], "ilst")
			if ilstPos >= 0 {
				absIlst := absMeta + ilstPos
				covrPos := findAtomIn(f[absIlst:], "covr")
				if covrPos >= 0 {
					absCovr := absIlst + covrPos
					covrSize := int(f[absCovr])<<24 | int(f[absCovr+1])<<16 |
						int(f[absCovr+2])<<8 | int(f[absCovr+3])
					f = append(f[:absCovr], f[absCovr+covrSize:]...)
				}
			}
		}
	}

	var dataAtom bytes.Buffer
	dataAtom.Write(encodeBE32(16 + uint32(len(coverData))))
	dataAtom.Write([]byte("data"))
	dataAtom.Write([]byte{0, 0, 0, 0})
	dataAtom.Write(coverData)
	dataBytes := dataAtom.Bytes()

	var covrAtom bytes.Buffer
	covrAtom.Write(encodeBE32(8 + uint32(len(dataBytes))))
	covrAtom.Write([]byte("covr"))
	covrAtom.Write(dataBytes)
	covrBytes := covrAtom.Bytes()

	ilstPos := findAtomIn(f, "ilst")
	var out bytes.Buffer
	if ilstPos >= 0 {
		out.Write(f[:ilstPos+8])
		out.Write(covrBytes)
		oldSize := int(f[ilstPos])<<24 | int(f[ilstPos+1])<<16 |
			int(f[ilstPos+2])<<8 | int(f[ilstPos+3])
		out.Write(encodeBE32(uint32(oldSize + len(covrBytes))))
		out.Write(f[ilstPos+8:])
	} else {
		return fmt.Errorf("cover: MP4 metadata not found, use a tagger tool first")
	}
	return os.WriteFile(filePath, out.Bytes(), 0644)
}
