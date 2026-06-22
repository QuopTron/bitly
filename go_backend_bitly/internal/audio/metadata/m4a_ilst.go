package metadata

import (
	"fmt"
	"os"
)

type m4aMetadataPath struct {
	moov atomHeader
	udta *atomHeader
	meta atomHeader
	ilst atomHeader
}

func findM4AIlstAtom(f *os.File, fileSize int64) (atomHeader, error) {
	moov, found, err := findAtomInRange(f, 0, fileSize, "moov", fileSize)
	if err != nil || !found {
		return atomHeader{}, fmt.Errorf("moov not found")
	}
	moovBodyStart := moov.offset + moov.headerSize
	moovBodySize := moov.size - moov.headerSize

	if udta, ok, _ := findAtomInRange(f, moovBodyStart, moovBodySize, "udta", fileSize); ok {
		udtaBodyStart := udta.offset + udta.headerSize
		udtaBodySize := udta.size - udta.headerSize
		if meta, ok2, _ := findAtomInRange(f, udtaBodyStart, udtaBodySize, "meta", fileSize); ok2 {
			metaBodyStart := meta.offset + meta.headerSize + 4
			metaBodySize := meta.size - meta.headerSize - 4
			if ilst, ok3, _ := findAtomInRange(f, metaBodyStart, metaBodySize, "ilst", fileSize); ok3 {
				return ilst, nil
			}
		}
	}

	if meta, ok, _ := findAtomInRange(f, moovBodyStart, moovBodySize, "meta", fileSize); ok {
		metaBodyStart := meta.offset + meta.headerSize + 4
		metaBodySize := meta.size - meta.headerSize - 4
		if ilst, ok2, _ := findAtomInRange(f, metaBodyStart, metaBodySize, "ilst", fileSize); ok2 {
			return ilst, nil
		}
	}
	return atomHeader{}, fmt.Errorf("ilst not found")
}

func findM4AMetadataPath(f *os.File, fileSize int64) (m4aMetadataPath, error) {
	moov, found, err := findAtomInRange(f, 0, fileSize, "moov", fileSize)
	if err != nil || !found {
		return m4aMetadataPath{}, fmt.Errorf("moov not found")
	}
	moovBodyStart := moov.offset + moov.headerSize
	moovBodySize := moov.size - moov.headerSize

	if udta, ok, _ := findAtomInRange(f, moovBodyStart, moovBodySize, "udta", fileSize); ok {
		udtaBodyStart := udta.offset + udta.headerSize
		udtaBodySize := udta.size - udta.headerSize
		if meta, ok2, _ := findAtomInRange(f, udtaBodyStart, udtaBodySize, "meta", fileSize); ok2 {
			metaBodyStart := meta.offset + meta.headerSize + 4
			metaBodySize := meta.size - meta.headerSize - 4
			if ilst, ok3, _ := findAtomInRange(f, metaBodyStart, metaBodySize, "ilst", fileSize); ok3 {
				udtaCopy := udta
				return m4aMetadataPath{moov: moov, udta: &udtaCopy, meta: meta, ilst: ilst}, nil
			}
		}
	}
	if meta, ok, _ := findAtomInRange(f, moovBodyStart, moovBodySize, "meta", fileSize); ok {
		metaBodyStart := meta.offset + meta.headerSize + 4
		metaBodySize := meta.size - meta.headerSize - 4
		if ilst, ok2, _ := findAtomInRange(f, metaBodyStart, metaBodySize, "ilst", fileSize); ok2 {
			return m4aMetadataPath{moov: moov, meta: meta, ilst: ilst}, nil
		}
	}
	return m4aMetadataPath{}, fmt.Errorf("ilst not found")
}
