// motivos_descarga_test.dart — Fija QUÉ fallos de descarga se reintentan
// solos. Es lo que decide si una canción que falló vuelve al frente de la cola
// FIFO o si se espera al usuario: reintentar un corte que necesita al usuario
// (sin espacio, carpeta sin permiso, sesión por verificar) solo repite el
// mismo aviso, y no reintentar un fallo de red deja la canción en rojo para
// siempre aunque otro intento hubiera funcionado.
import 'package:bitly/core/servicios/descargas/motivos_descarga.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('falloDescargaReintentable', () {
    test('los fallos de red/proveedor se reintentan', () {
      for (final motivo in [
        'all providers failed',
        'flac-rescue: sin stream',
        'https://dzr.tabs-vs-spaces.wtf (503): All Deezer accounts are dead',
        'tramo 0-100: HTTP 502',
        'preview/clip descartado de ytmusic-spotiflac',
      ]) {
        expect(
          falloDescargaReintentable(motivo),
          isTrue,
          reason: 'debía reintentarse: $motivo',
        );
      }
    });

    test('los cortes que necesitan al usuario NO se reintentan', () {
      for (final motivo in [
        'no space left on device',
        'permission denied',
        'read-only file system',
        'verification_required en deezer',
        'session expired',
        'HTTP 428',
        'Tu prueba gratis de 8 horas terminó',
        'las descargas requieren premium',
      ]) {
        expect(
          falloDescargaReintentable(motivo),
          isFalse,
          reason: 'no debía reintentarse: $motivo',
        );
      }
    });

    test('sin motivo declarado se intenta una vez más', () {
      expect(falloDescargaReintentable(null), isTrue);
      expect(falloDescargaReintentable('   '), isTrue);
    });
  });

  group('claveMotivoDescarga', () {
    test('clasifica cada familia de error en su código', () {
      const casos = {
        'no space left on device': MotivosDescarga.espacio,
        'mkdir: EACCES permission denied': MotivosDescarga.permiso,
        'captcha en deezer': MotivosDescarga.verificacion,
        'las descargas requieren premium': MotivosDescarga.premium,
        'la carpeta de descargas no existe': MotivosDescarga.carpeta,
        'connect: network unreachable': MotivosDescarga.red,
        'all providers failed': MotivosDescarga.desconocido,
      };
      for (final c in casos.entries) {
        expect(
          claveMotivoDescarga(c.key),
          c.value,
          reason: 'no clasificó bien: ${c.key}',
        );
      }
    });

    test('sin mensaje cae a desconocido, nunca a vacío', () {
      expect(claveMotivoDescarga(null), MotivosDescarga.desconocido);
      expect(claveMotivoDescarga('  '), MotivosDescarga.desconocido);
    });

    test('un error crudo de Go nunca llega a la UI tal cual', () {
      // El texto crudo SIEMPRE se reduce a un código neutro de idioma, sin
      // espacios ni prosa: la UI elige el texto con l10n.
      const crudo =
          'tidal-web: session expired, verification_required en tidal.com';
      final clave = claveMotivoDescarga(crudo);
      expect(clave, MotivosDescarga.verificacion);
      expect(clave, isNot(contains(' ')));
      expect(clave, isNot(contains('session')));
    });
  });
}
