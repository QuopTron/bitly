package metadata

import (
	"encoding/binary"
	"fmt"
	"io"
	"os"
)

type atomHeader struct {
	offset     int64
	size       int64
	headerSize int64
	typ        string
}

func readAtomHeaderAt(f *os.File, offset, fileSize int64) (atomHeader, error) {
	if offset+8 > fileSize {
		return atomHeader{}, io.ErrUnexpectedEOF
	}
	headerBuf := make([]byte, 8)
	if _, err := f.ReadAt(headerBuf, offset); err != nil {
		return atomHeader{}, err
	}
	size32 := binary.BigEndian.Uint32(headerBuf[0:4])
	typ := string(headerBuf[4:8])
	if size32 == 1 {
		if offset+16 > fileSize {
			return atomHeader{}, io.ErrUnexpectedEOF
		}
		extBuf := make([]byte, 8)
		if _, err := f.ReadAt(extBuf, offset+8); err != nil {
			return atomHeader{}, err
		}
		size64 := binary.BigEndian.Uint64(extBuf)
		return atomHeader{offset: offset, size: int64(size64), headerSize: 16, typ: typ}, nil
	}
	return atomHeader{offset: offset, size: int64(size32), headerSize: 8, typ: typ}, nil
}

func findAtomInRange(f *os.File, start, size int64, target string, fileSize int64) (atomHeader, bool, error) {
	if size <= 0 {
		return atomHeader{}, false, nil
	}
	end := start + size
	pos := start
	for pos+8 <= end {
		header, err := readAtomHeaderAt(f, pos, fileSize)
		if err != nil {
			return atomHeader{}, false, err
		}
		atomSize := header.size
		if atomSize == 0 {
			atomSize = end - pos
		}
		if atomSize < header.headerSize {
			return atomHeader{}, false, fmt.Errorf("invalid atom size for %s", header.typ)
		}
		header.size = atomSize
		if header.typ == target {
			return header, true, nil
		}
		pos += atomSize
	}
	return atomHeader{}, false, nil
}
