package main

import (
	backend "github.com/zarz/bitly/go_backend/internal/gobackend"
)

// dispatchFuentes maneja las tipografías descargables (Ajustes → Apariencia →
// Tipografía). Va aparte de dispatchMedia porque no es media: son datos de la
// UI que Flutter pide una vez y cachea en disco.
//
// Devuelve handled=false para métodos fuera de este dominio.
func dispatchFuentes(method string, params map[string]interface{}) (interface{}, string, bool) {
	switch method {
	case "descargarFuente":
		// Devuelve la RUTA local del .ttf ("" si no se pudo), igual que
		// saveCover con las carátulas: Flutter lee el archivo de ahí.
		return backend.DescargarFuente(rpcBody(params)), "", true
	case "borrarFuentes":
		return backend.BorrarFuentes(), "", true
	}
	return nil, "", false
}
