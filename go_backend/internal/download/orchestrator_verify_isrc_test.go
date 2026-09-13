package download

import (
	"testing"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// matchStubProvider devuelve un registro fijo para probar la confirmación de
// match de descarga sin tocar la red.
type matchStubProvider struct {
	name  string
	track *provider.TrackResult
}

func (s *matchStubProvider) Name() string { return s.name }
func (s *matchStubProvider) SearchTracks(q string, l int) ([]provider.TrackResult, error) {
	return nil, nil
}
func (s *matchStubProvider) SearchAlbums(q string, l int) ([]provider.AlbumResult, error) {
	return nil, nil
}
func (s *matchStubProvider) SearchArtists(q string, l int) ([]provider.ArtistResult, error) {
	return nil, nil
}
func (s *matchStubProvider) SearchPlaylists(q string, l int) ([]provider.PlaylistResult, error) {
	return nil, nil
}
func (s *matchStubProvider) GetTrack(id string) (*provider.TrackResult, error) { return s.track, nil }
func (s *matchStubProvider) GetTrackByISRC(isrc string) (*provider.TrackResult, error) {
	return nil, nil
}
func (s *matchStubProvider) GetAlbum(id string) (*provider.AlbumResult, error)   { return nil, nil }
func (s *matchStubProvider) GetArtist(id string) (*provider.ArtistResult, error) { return nil, nil }
func (s *matchStubProvider) GetStreamURL(id, quality string) (string, error)     { return "", nil }

// El rescate indexado por ISRC (flac-rescue) confirma el match por el ISRC: su
// registro NO trae título ni artista (el título es el propio ISRC), así que sin
// esta regla quedaba rechazado y nunca se descargaba el FLAC exacto por ISRC.
func TestConfirmarMatchDescargaAceptaRescatePorISRC(t *testing.T) {
	const isrc = "USRC17607839"
	fr := &matchStubProvider{name: "flac-rescue", track: &provider.TrackResult{
		ID: isrc, Title: isrc, ISRC: isrc,
	}}
	if !confirmarMatchDescarga(fr, isrc, isrc, "Mi Cancion", "Artista Real", 0) {
		t.Fatal("confirmarMatchDescarga rechazó el rescate por ISRC")
	}
}

// Un re-subido (SoundCloud/YouTube) infiere el ISRC por nombre: no basta con que
// lo declare si el título/artista no son los pedidos.
func TestConfirmarMatchDescargaRechazaReSubidoConTituloAjeno(t *testing.T) {
	const isrc = "USRC17607839"
	sc := &matchStubProvider{name: "soundcloud", track: &provider.TrackResult{
		ID: "1", Title: "Otro Remix Random", Artist: "Dj Random", ISRC: isrc,
	}}
	if confirmarMatchDescarga(sc, "1", isrc, "Mi Cancion", "Artista Real", 0) {
		t.Fatal("confirmarMatchDescarga aceptó un re-subido por el ISRC declarado")
	}
}

// Un catálogo con el ISRC exacto confirma la grabación (el ISRC viene del sello).
func TestConfirmarMatchDescargaAceptaCatalogoConMismoISRC(t *testing.T) {
	const isrc = "USRC17607839"
	deezer := &matchStubProvider{name: "deezer", track: &provider.TrackResult{
		ID: "1", Title: "Mi Cancion (Album Version)", Artist: "Artista Real", ISRC: isrc,
	}}
	if !confirmarMatchDescarga(deezer, "1", isrc, "Mi Cancion", "Artista Real", 0) {
		t.Fatal("confirmarMatchDescarga rechazó un catálogo con el ISRC exacto")
	}
}

// Un ISRC distinto es otra grabación: siempre se rechaza.
func TestConfirmarMatchDescargaRechazaISRCDistinto(t *testing.T) {
	deezer := &matchStubProvider{name: "deezer", track: &provider.TrackResult{
		ID: "1", Title: "Mi Cancion", Artist: "Artista Real", ISRC: "OTRO0000001",
	}}
	if confirmarMatchDescarga(deezer, "1", "USRC17607839", "Mi Cancion", "Artista Real", 0) {
		t.Fatal("confirmarMatchDescarga aceptó un ISRC distinto")
	}
}

// La duración sigue siendo un filtro fuerte: una toma mucho más larga/corta es
// otra versión aunque el título y el artista coincidan.
func TestConfirmarMatchDescargaRechazaDuracionMuyDistinta(t *testing.T) {
	deezer := &matchStubProvider{name: "deezer", track: &provider.TrackResult{
		ID: "1", Title: "Mi Cancion", Artist: "Artista Real", Duration: 420000,
	}}
	if confirmarMatchDescarga(deezer, "1", "", "Mi Cancion", "Artista Real", 180000) {
		t.Fatal("confirmarMatchDescarga aceptó una duración incompatible")
	}
}
