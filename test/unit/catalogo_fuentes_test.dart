// ─────────────────────────────────────────────────────────────
// catalogo_fuentes_test.dart — El catálogo de tipografías: que el respaldo
// (la empaquetada) siempre exista, que una preferencia vieja no rompa el tema y
// que el desbloqueo respete horas/versión.
// Parte del flujo: Ajustes → Apariencia → Tipografía.
// ─────────────────────────────────────────────────────────────

import 'package:bitly/core/modelos/usuario/disenos/barra/catalogo_disenos_barra_desbloqueo.dart'
    show versionEnNumero;
import 'package:bitly/core/modelos/usuario/fuentes/catalogo_fuentes.dart';
import 'package:bitly/core/modelos/usuario/fuentes/fuente_app.dart';
import 'package:bitly/core/modelos/usuario/preferencias/preferencias_apariencia.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('el respaldo siempre existe', () {
    test('la empaquetada es la única sin url', () {
      final empaquetadas = catalogoFuentes.where((f) => f.empaquetada);
      expect(empaquetadas.length, 1);
      expect(empaquetadas.single.id, fuenteEmpaquetada.id);
      expect(fuenteEmpaquetada.familia, 'Google Sans Flex');
    });

    test('sin elección, o con un id que ya no existe, se usa la empaquetada', () {
      expect(fuentePorId('')?.id, fuenteEmpaquetada.id);
      expect(fuentePorId(null)?.id, fuenteEmpaquetada.id);
      // Un id que se quitó del catálogo devuelve null…
      expect(fuentePorId('fuente_que_ya_no_esta'), isNull);
      // …y la familia cae a la de la app, que es lo que pinta el tema.
      expect(familiaDeFuente('fuente_que_ya_no_esta'), fuenteEmpaquetada.familia);
      expect(familiaDeFuente(null), fuenteEmpaquetada.familia);
    });

    test('cada id resuelve su propia familia', () {
      for (final f in catalogoFuentes) {
        expect(familiaDeFuente(f.id), f.familia, reason: f.id);
      }
    });
  });

  group('integridad del catálogo', () {
    test('los ids no se repiten', () {
      final ids = catalogoFuentes.map((f) => f.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('las familias descargables no pisan la de la app', () {
      for (final f in catalogoFuentes.where((f) => f.descargable)) {
        expect(f.familia, startsWith('bitly_'), reason: f.id);
        expect(f.familia, isNot(fuenteEmpaquetada.familia), reason: f.id);
      }
    });

    test('el id es un nombre de archivo válido (el backend lo valida así)', () {
      final seguro = RegExp(r'^[a-z0-9_]{1,32}$');
      for (final f in catalogoFuentes) {
        expect(seguro.hasMatch(f.id), isTrue, reason: f.id);
      }
    });

    test('lo descargable apunta al espejo con el nombre del id', () {
      for (final f in catalogoFuentes.where((f) => f.descargable)) {
        expect(f.url, startsWith(baseFuentesUrl), reason: f.id);
        expect(f.url, endsWith('/${f.id}.ttf'), reason: f.id);
      }
    });
  });

  group('desbloqueo', () {
    FuenteApp porId(String id) => catalogoFuentes.firstWhere((f) => f.id == id);

    test('lo libre se usa desde el primer día', () {
      expect(fuenteDesbloqueada(fuenteEmpaquetada, horas: 0, version: 0), isTrue);
      expect(fuenteDesbloqueada(porId('inter'), horas: 0, version: 0), isTrue);
    });

    test('lo de horas se abre al llegar a las horas', () {
      final manrope = porId('manrope');
      expect(manrope.desbloqueo, DesbloqueoFuente.horas);
      expect(fuenteDesbloqueada(manrope, horas: 4, version: 0), isFalse);
      expect(fuenteDesbloqueada(manrope, horas: 5, version: 0), isTrue);
      expect(fuenteDesbloqueada(manrope, horas: 900, version: 0), isTrue);
    });

    test('lo de versión no se abre si la versión no se pudo leer', () {
      final nunito = porId('nunito');
      expect(nunito.desbloqueo, DesbloqueoFuente.version);
      // version 0 = no se pudo leer: mejor no mostrar un regalo fantasma.
      expect(fuenteDesbloqueada(nunito, horas: 99999, version: 0), isFalse);
      expect(
        fuenteDesbloqueada(nunito, horas: 0, version: versionEnNumero('0.9.27')),
        isFalse,
      );
      expect(
        fuenteDesbloqueada(nunito, horas: 0, version: versionEnNumero('1.0.0')),
        isTrue,
      );
    });

    test('la escalera de horas es creciente', () {
      final porHoras = catalogoFuentes
          .where((f) => f.desbloqueo == DesbloqueoFuente.horas)
          .map((f) => f.valor)
          .toList();
      expect(porHoras, isNotEmpty);
      final ordenadas = [...porHoras]..sort();
      expect(porHoras, ordenadas);
    });

    test('con cero horas solo están las libres', () {
      final disponibles = fuentesDisponibles(horas: 0, version: 0);
      expect(disponibles.every((f) => f.desbloqueo == DesbloqueoFuente.libre),
          isTrue);
      expect(disponibles.length, greaterThanOrEqualTo(1));
    });
  });

  group('la elección se guarda', () {
    test('fuenteId sobrevive el ida y vuelta a JSON', () {
      final prefs = PreferenciasApariencia.deFabrica.copiarCon(
        fuenteId: 'jetbrains_mono',
      );
      expect(prefs.fuenteId, 'jetbrains_mono');
      expect(prefs.esDeFabrica, isFalse);

      final leido = PreferenciasApariencia.desdeJsonString(prefs.toJsonString());
      expect(leido.fuenteId, 'jetbrains_mono');
    });

    test('sin la clave guardada (versión anterior) queda en la de la app', () {
      const viejo = '{"radioCards":14,"escalaTexto":1}';
      expect(PreferenciasApariencia.desdeJsonString(viejo).fuenteId, '');
    });

    test('el diseño de fábrica usa la tipografía de la app', () {
      expect(PreferenciasApariencia.deFabrica.fuenteId, '');
      expect(PreferenciasApariencia.deFabrica.esDeFabrica, isTrue);
    });
  });
}
