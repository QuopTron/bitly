package audio

const (
	apeHeaderMagic        = "APETAGEX"
	apeFooterSize         = 32
	apeHeaderSize         = 32
	apeFlagContainsHeader = 0x80000000
)

// APETagItem represents a single APEv2 tag item.
type APETagItem struct {
	Key   string
	Value []byte
	Flag  uint32 // 0=utf8, 1=binary, 2=locator
}

// APETags holds parsed APEv2 tag data.
type APETags struct {
	Items     []APETagItem
	HasHeader bool
}

// ReadAPETags reads APEv2 tags from a file (FLAC, APE, WavPack, Musepack, MP3).
