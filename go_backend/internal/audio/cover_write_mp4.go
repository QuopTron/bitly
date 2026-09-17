package audio

import (
	"bytes"
	"fmt"
	"os"
)

// writeMP4Cover incrusta la portada en moov→udta→meta→ilst→covr de un MP4/M4A.
//
// Reescribe la cadena de cajas de adentro hacia afuera, recalculando el tamaño
// de cada contenedor. Antes el ilst se "reconstruía" pegando un tamaño nuevo en
// el medio del flujo y sin tocar los tamaños de los padres (moov/udta/meta
// quedaban con su tamaño viejo), así que el archivo terminaba corrupto: la
// canción descargada con portada no abría en ningún reproductor.
func writeMP4Cover(filePath string, coverData []byte) error {
	original, err := os.ReadFile(filePath)
	if err != nil {
		return err
	}
	cajas, ok := leerCajasMP4(original)
	if !ok {
		return errM4AEstructura
	}

	var out bytes.Buffer
	encontrado := false
	for _, c := range cajas {
		contenido := original[c.inicio:c.fin]
		if c.tipo != "moov" {
			out.Write(contenido)
			continue
		}
		nuevoMoov, err := inyectarCoverEnMoov(contenido, coverData)
		if err != nil {
			return err
		}
		out.Write(nuevoMoov)
		encontrado = true
	}
	if !encontrado {
		return fmt.Errorf("cover: no moov atom found")
	}
	return os.WriteFile(filePath, out.Bytes(), 0o644)
}

// inyectarCoverEnMoov baja hasta el udta y devuelve el moov completo.
func inyectarCoverEnMoov(moov []byte, cover []byte) ([]byte, error) {
	if len(moov) < 8 {
		return nil, errM4AEstructura
	}
	contenido, err := reemplazarHijaMP4(
		moov[8:],
		"udta",
		func(udta []byte) ([]byte, error) { return inyectarCoverEnUdta(udta, cover) },
	)
	if err != nil {
		return nil, err
	}
	return armarCajaMP4("moov", contenido), nil
}

// inyectarCoverEnUdta baja hasta el meta y reenvuelve el udta.
func inyectarCoverEnUdta(udta []byte, cover []byte) ([]byte, error) {
	if len(udta) < 8 {
		return nil, errM4AEstructura
	}
	contenido, err := reemplazarHijaMP4(
		udta[8:],
		"meta",
		func(meta []byte) ([]byte, error) { return inyectarCoverEnMeta(meta, cover) },
	)
	if err != nil {
		return nil, err
	}
	return armarCajaMP4("udta", contenido), nil
}

// inyectarCoverEnMeta baja hasta el ilst y reenvuelve el meta. `meta` es una
// FULL box: puede llevar 4 bytes de versión+flags antes de sus hijas, así que
// primero se intenta leerlas directo y, si eso falla, se descartan esos 4 bytes.
func inyectarCoverEnMeta(meta []byte, cover []byte) ([]byte, error) {
	if len(meta) < 8 {
		return nil, errM4AEstructura
	}
	cuerpo := meta[8:]
	prefijo := 0
	if _, ok := leerCajasMP4(cuerpo); !ok {
		if len(cuerpo) < 4 {
			return nil, errM4AEstructura
		}
		cuerpo = cuerpo[4:]
		prefijo = 4
	}
	contenido, err := reemplazarHijaMP4(
		cuerpo,
		"ilst",
		func(ilst []byte) ([]byte, error) { return inyectarCoverEnIlst(ilst, cover) },
	)
	if err != nil {
		return nil, err
	}
	salida := make([]byte, 0, prefijo+len(contenido))
	salida = append(salida, meta[8:8+prefijo]...)
	salida = append(salida, contenido...)
	return armarCajaMP4("meta", salida), nil
}

// inyectarCoverEnIlst reemplaza el covr existente por uno nuevo (último hijo,
// como hace iTunes) y devuelve el ilst completo.
func inyectarCoverEnIlst(ilst []byte, cover []byte) ([]byte, error) {
	if len(ilst) < 8 {
		return nil, errM4AEstructura
	}
	hijos, ok := leerCajasMP4(ilst[8:])
	if !ok {
		return nil, errM4AEstructura
	}
	var out bytes.Buffer
	for _, h := range hijos {
		if h.tipo == "covr" {
			continue // se reemplaza por el nuevo
		}
		out.Write(ilst[8:][h.inicio:h.fin])
	}
	out.Write(armarAtomoCovr(cover))
	return armarCajaMP4("ilst", out.Bytes()), nil
}

// armarAtomoCovr devuelve el átomo covr con su átomo data adentro (tipo de dato
// 13 = JPEG, 14 = PNG, como esperan los reproductores).
func armarAtomoCovr(cover []byte) []byte {
	tipo := byte(13) // JPEG por defecto
	if detectMIME(cover) == "image/png" {
		tipo = 14
	}
	data := make([]byte, 0, 8+len(cover))
	data = append(data, 0, 0, 0, tipo) // versión/flags con el tipo de imagen
	data = append(data, 0, 0, 0, 0)    // locale
	data = append(data, cover...)
	return armarCajaMP4("covr", armarCajaMP4("data", data))
}
