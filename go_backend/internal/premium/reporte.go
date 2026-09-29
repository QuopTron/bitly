// reporte.go — Envío de reportes (bug / sugerencia) por tu Worker.
//
// Antes lo hacía la app directamente contra la API de GitHub usando el mismo PAT
// que estaba COMPILADO adentro (lib/config/secretos.dart), creando un issue en
// el repo del código. Como ese token ya no viaja en el binario, el issue lo crea
// el Worker, que es el que tiene la llave en su entorno.
//
// Sin URL de registro configurada, el reporte no se puede enviar: se devuelve un
// error explícito y la UI lo dice (mejor eso que fallar en silencio).
package premium

// EnviarReporte manda el reporte al Worker. El título y el cuerpo son texto
// plano; el Worker los usa para el issue.
func EnviarReporte(titulo, cuerpo string) error {
	url := premiumRegistroURL()
	if url == "" {
		return nuevoError("reporte_no_configurado", "el envío de reportes no está configurado")
	}
	_, err := pedirAlRegistro(url, "reporte", map[string]string{
		"titulo": titulo,
		"cuerpo": cuerpo,
	})
	return err
}
