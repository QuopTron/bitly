package metadata

import (
	"fmt"
	"os"
)

// ID3v1Genres is the list of ID3v1 genre names.
var ID3v1Genres = []string{
	"Blues", "Classic Rock", "Country", "Dance", "Disco", "Funk", "Grunge",
	"Hip-Hop", "Jazz", "Metal", "New Age", "Oldies", "Other", "Pop", "R&B",
	"Rap", "Reggae", "Rock", "Techno", "Industrial", "Alternative", "Ska",
	"Death Metal", "Pranks", "Soundtrack", "Euro-Techno", "Ambient",
	"Trip-Hop", "Vocal", "Jazz+Funk", "Fusion", "Trance", "Classical",
	"Instrumental", "Acid", "House", "Game", "Sound Clip", "Gospel",
	"Noise", "AlternRock", "Bass", "Soul", "Punk", "Space", "Meditative",
	"Instrumental Pop", "Instrumental Rock", "Ethnic", "Gothic",
	"Darkwave", "Techno-Industrial", "Electronic", "Pop-Folk", "Eurodance",
	"Dream", "Southern Rock", "Comedy", "Cult", "Gangsta", "Top 40",
	"Christian Rap", "Pop/Funk", "Jungle", "Native American", "Cabaret",
	"New Wave", "Psychedelic", "Rave", "Showtunes", "Trailer", "Lo-Fi",
	"Tribal", "Acid Punk", "Acid Jazz", "Polka", "Retro", "Musical",
	"Rock & Roll", "Hard Rock", "Folk", "Folk-Rock", "National Folk",
	"Swing", "Fast Fusion", "Bebop", "Latin", "Revival", "Celtic",
	"Bluegrass", "Avantgarde", "Gothic Rock", "Progressive Rock",
	"Psychedelic Rock", "Symphonic Rock", "Slow Rock", "Big Band",
	"Chorus", "Easy Listening", "Acoustic", "Humour", "Speech", "Chanson",
	"Opera", "Chamber Music", "Sonata", "Symphony", "Booty Bass", "Primus",
	"Porn Groove", "Satire", "Slow Jam", "Club", "Tango", "Samba",
	"Folklore", "Ballad", "Power Ballad", "Rhythmic Soul", "Freestyle",
	"Duet", "Punk Rock", "Drum Solo", "A capella", "Euro-House",
	"Dance Hall", "Goa", "Drum & Bass", "Club-House", "Hardcore",
	"Terror", "Indie", "BritPop", "Negerpunk", "Polsk Punk", "Beat",
	"Christian Gangsta Rap", "Heavy Metal", "Black Metal", "Crossover",
	"Contemporary Christian", "Christian Rock", "Merengue", "Salsa",
	"Thrash Metal", "Anime", "J-Pop", "Synthpop",
}

// ReadID3Tags reads ID3v2 and ID3v1 tags from an MP3 file.
func ReadID3Tags(filePath string) (*AudioMetadata, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	meta := &AudioMetadata{}

	id3v2, err := readID3v2(file)
	if err == nil && id3v2 != nil {
		meta = id3v2
	}

	if meta.Title == "" || meta.Artist == "" {
		id3v1, err := readID3v1(file)
		if err == nil && id3v1 != nil {
			if meta.Title == "" {
				meta.Title = id3v1.Title
			}
			if meta.Artist == "" {
				meta.Artist = id3v1.Artist
			}
			if meta.Album == "" {
				meta.Album = id3v1.Album
			}
			if meta.Year == "" {
				meta.Year = id3v1.Year
			}
			if meta.Genre == "" {
				meta.Genre = id3v1.Genre
			}
		}
	}

	if meta.Title == "" && meta.Artist == "" {
		return nil, fmt.Errorf("no ID3 tags found")
	}
	return meta, nil
}
