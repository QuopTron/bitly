package audio

import (
	"bytes"
	"fmt"
	"os"
)

// WriteM4AFreeformTags escribe las etiquetas dentro de un MP4/M4A como átomos
// de iTunes (©nam/©ART/©alb/…) en moov→udta→meta→ilst, más el ISRC como átomo
// freeform.
//
// Recorre los átomos de nivel superior y reescribe el moov COMPLETO, con su
// cabecera y su tamaño actualizados: antes se volcaba solo el CONTENIDO del
// moov, así que el archivo resultante perdía la caja moov, quedaba con
// mvhd/trak/udta sueltos al tope y ningún reproductor podía abrir la canción.
func WriteM4AFreeformTags(path string, tags map[string]string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	if len(data) < 8 || string(data[4:8]) != "ftyp" {
		return fmt.Errorf("ERR_M4A_INVALIDO: no es un archivo MP4/M4A valido")
	}
	cajas, ok := leerCajasMP4(data)
	if !ok {
		return errM4AEstructura
	}

	atomos := atomosEtiquetasM4A(tags)
	if len(atomos) == 0 {
		return nil
	}

	var buf bytes.Buffer
	for _, c := range cajas {
		atomData := data[c.inicio:c.fin]
		if c.tipo != "moov" {
			buf.Write(atomData)
			continue
		}
		newMoov, err := inyectarM4AUdta(atomData, atomos)
		if err != nil {
			// Sin poder reescribir el moov se conserva el original: la canción ya
			// es reproducible y las etiquetas no valen romperla.
			buf.Write(atomData)
			continue
		}
		buf.Write(newMoov)
	}
	return SafeSaveFLAC(path, buf.Bytes())
}

// inyectarM4AUdta reescribe el moov con las etiquetas dentro de su udta.
// Si el archivo no trae udta (típico de InnerTube), se crea uno con meta+ilst.
func inyectarM4AUdta(moovAtom []byte, atomos []byte) ([]byte, error) {
	if len(moovAtom) < 8 {
		return nil, errM4AEstructura
	}
	hijos := moovAtom[8:]
	contenido, err := reemplazarHijaMP4(
		hijos,
		"udta",
		func(udta []byte) ([]byte, error) { return inyectarEtiquetasEnUdta(udta, atomos) },
	)
	if err != nil {
		contenido, err = agregarUdtaNuevo(hijos, atomos)
		if err != nil {
			return nil, err
		}
	}
	return armarCajaMP4("moov", contenido), nil
}

// inyectarEtiquetasEnUdta mete los átomos dentro del meta/ilst existente y
// reenvuelve el udta. Si el udta no tiene meta (o su estructura no se puede
// recorrer), se agrega un meta nuevo al final.
func inyectarEtiquetasEnUdta(udta []byte, atomos []byte) ([]byte, error) {
	if len(udta) < 8 {
		return nil, errM4AEstructura
	}
	contenido, err := reemplazarHijaMP4(
		udta[8:],
		"meta",
		func(meta []byte) ([]byte, error) { return inyectarEtiquetasEnMeta(meta, atomos) },
	)
	if err != nil {
		contenido = nil
	}
	if contenido == nil {
		// Sin meta: se arma uno nuevo y se agrega al udta existente.
		hijos, ok := leerCajasMP4(udta[8:])
		if !ok {
			return nil, errM4AEstructura
		}
		construido := make([]byte, 0, len(udta))
		for _, h := range hijos {
			construido = append(construido, udta[8:][h.inicio:h.fin]...)
		}
		construido = append(construido, armarMetaConItunes(atomos)...)
		return armarCajaMP4("udta", construido), nil
	}
	return armarCajaMP4("udta", contenido), nil
}

// inyectarEtiquetasEnMeta agrega los átomos al ilst del meta (creándolo si falta)
// y reenvuelve el meta conservando su versión/flags.
func inyectarEtiquetasEnMeta(meta []byte, atomos []byte) ([]byte, error) {
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
	hijos, ok := leerCajasMP4(cuerpo)
	if !ok {
		return nil, errM4AEstructura
	}

	var dentro bytes.Buffer
	hayIlst := false
	for _, h := range hijos {
		hija := cuerpo[h.inicio:h.fin]
		if h.tipo != "ilst" {
			dentro.Write(hija)
			continue
		}
		hayIlst = true
		agregado, err := agregarAtomosAIlst(hija, atomos)
		if err != nil {
			dentro.Write(hija)
			continue
		}
		dentro.Write(agregado)
	}
	if !hayIlst {
		dentro.Write(armarCajaMP4("ilst", atomos))
	}

	salida := make([]byte, 0, prefijo+dentro.Len())
	salida = append(salida, meta[8:8+prefijo]...)
	salida = append(salida, dentro.Bytes()...)
	return armarCajaMP4("meta", salida), nil
}

// agregarAtomosAIlst agrega (o reemplaza) los átomos de etiqueta en un ilst.
func agregarAtomosAIlst(ilst []byte, atomos []byte) ([]byte, error) {
	if len(ilst) < 8 {
		return nil, errM4AEstructura
	}
	nuevos, ok := leerCajasMP4(atomos)
	if !ok {
		return nil, errM4AEstructura
	}
	reemplazables := map[string]bool{}
	for _, n := range nuevos {
		reemplazables[n.tipo] = true
	}
	hijos, ok := leerCajasMP4(ilst[8:])
	if !ok {
		return nil, errM4AEstructura
	}
	var out bytes.Buffer
	for _, h := range hijos {
		if reemplazables[h.tipo] {
			continue // se reemplaza por la versión nueva
		}
		out.Write(ilst[8:][h.inicio:h.fin])
	}
	out.Write(atomos)
	return armarCajaMP4("ilst", out.Bytes()), nil
}

// agregarUdtaNuevo agrega un udta con las etiquetas al final del moov, para los
// archivos que no traen ninguno.
func agregarUdtaNuevo(hijos []byte, atomos []byte) ([]byte, error) {
	cajas, ok := leerCajasMP4(hijos)
	if !ok {
		return nil, errM4AEstructura
	}
	out := make([]byte, 0, len(hijos)+len(atomos)+40)
	for _, c := range cajas {
		out = append(out, hijos[c.inicio:c.fin]...)
	}
	return append(out, armarUdtaConEtiquetas(atomos)...), nil
}
