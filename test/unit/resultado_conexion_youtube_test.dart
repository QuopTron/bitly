// resultado_conexion_youtube_test.dart — El éxito de conectar YouTube se lee
// por `ok`, nunca comparando el mensaje (que se traduce y cambia).
// Se conecta con: ServicioOAuthYouTube (devuelve este resultado).
// Parte del flujo: Ajustes/Setup → Google.

import 'package:bitly/core/servicios/oauth/base/servicio_oauth_youtube.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResultadoConexionYouTube', () {
    test('el fallo marca ok=false y conserva el mensaje', () {
      const r = ResultadoConexionYouTube.fallo('Inicio de sesión cancelado.');
      expect(r.ok, isFalse);
      expect(r.mensaje, 'Inicio de sesión cancelado.');
    });

    test('el éxito se decide por ok, aunque el mensaje cambie de texto', () {
      // Dos mensajes distintos (idiomas/copy diferentes) siguen siendo éxito:
      // la lógica no depende del texto.
      const a = ResultadoConexionYouTube(ok: true, mensaje: 'Conectado ✓');
      const b = ResultadoConexionYouTube(
        ok: true,
        mensaje: 'YouTube connected ✓ — user@gmail.com',
      );
      expect(a.ok && b.ok, isTrue);
      expect(a.mensaje, isNot(b.mensaje));
    });
  });
}
