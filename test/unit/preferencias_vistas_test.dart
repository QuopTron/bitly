// ─────────────────────────────────────────────────────────────
// preferencias_vistas_test.dart — El núcleo del diseño POR VISTA (v1.0.0):
// que "no tocar nada" herede, que lo personalizado sobreviva al guardado y que
// una preferencia vieja o rota NUNCA rompa el arranque.
// Parte del flujo: Ajustes → Apariencia → Vistas (y el arranque que las lee).
// ─────────────────────────────────────────────────────────────

import 'package:bitly/core/modelos/usuario/disenos/vistas/diseno_vista.dart';
import 'package:bitly/core/modelos/usuario/disenos/vistas/preferencias_vistas.dart';
import 'package:bitly/core/modelos/usuario/disenos/vistas/preferencias_vistas_json.dart';
import 'package:bitly/core/modelos/usuario/disenos/vistas/vista_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('estado de fábrica', () {
    test('ninguna vista tocada: todas heredan', () {
      const prefs = PreferenciasVistas.deFabrica;
      expect(prefs.esDeFabrica, isTrue);
      expect(prefs.cantidadPersonalizadas, 0);
      expect(prefs.personalizadas, isEmpty);
      for (final vista in VistaApp.values) {
        expect(prefs.para(vista).esHereda, isTrue, reason: vista.clave);
      }
    });

    test('un diseño vacío es "hereda" y no se guarda', () {
      final prefs = PreferenciasVistas.deFabrica.conVista(
        VistaApp.ajustes,
        DisenoVista.hereda,
      );
      expect(prefs.esDeFabrica, isTrue);
      expect(prefs.personalizadas, isEmpty);
    });
  });

  group('personalizar una vista', () {
    test('solo queda tocada la vista que cambió', () {
      const diseno = DisenoVista(disenoId: 'paleta_oro');
      final prefs = PreferenciasVistas.deFabrica.conVista(
        VistaApp.feed,
        diseno,
      );

      expect(prefs.cantidadPersonalizadas, 1);
      expect(prefs.personalizadas, [VistaApp.feed]);
      expect(prefs.para(VistaApp.feed).disenoId, 'paleta_oro');
      // Las demás siguen heredando: la app no se las toca.
      expect(prefs.para(VistaApp.ajustes).esHereda, isTrue);
    });

    test('restablecer una vista la devuelve a heredar', () {
      final prefs = PreferenciasVistas.deFabrica
          .conVista(VistaApp.feed, const DisenoVista(disenoId: 'aurora'))
          .restablecer(VistaApp.feed);
      expect(prefs.esDeFabrica, isTrue);
      expect(prefs.para(VistaApp.feed).esHereda, isTrue);
    });

    test('el mapa NO se muta: cada cambio devuelve uno nuevo', () {
      final base = PreferenciasVistas.deFabrica.conVista(
        VistaApp.feed,
        const DisenoVista(disenoId: 'a'),
      );
      base.conVista(VistaApp.feed, const DisenoVista(disenoId: 'b'));
      expect(base.cantidadPersonalizadas, 1, reason: 'base intacta');
    });
  });

  // El constructor `const` es sólo datos (igual que PreferenciasApariencia):
  // el acotado vive en los dos caminos de ESCRITURA, que son los que pueden
  // recibir un valor de un deslizador o de un json viejo.
  group('acotado de rangos', () {
    test('copiarCon acota densidad, radio y columnas', () {
      final d = DisenoVista.hereda.copiarCon(
        densidad: 9,
        columnasMax: 12,
        radioTarjeta: 99,
      );
      expect(d.densidad, DisenoVista.maxDensidad);
      expect(d.columnasMax, DisenoVista.maxColumnas);
      expect(d.radioTarjeta, DisenoVista.maxRadio);
    });

    test('copiarCon acota también por abajo', () {
      expect(
        DisenoVista.hereda.copiarCon(densidad: 0.1).densidad,
        DisenoVista.minDensidad,
      );
      expect(DisenoVista.hereda.copiarCon(columnasMax: -3).columnasMax, 0);
      expect(DisenoVista.hereda.copiarCon(radioTarjeta: -10).radioTarjeta, 0);
    });

    test('desdeJson acota lo que venga guardado', () {
      final d = DisenoVista.desdeJson({
        'disenoId': 'aurora',
        'densidad': 9,
        'columnasMax': 12,
        'radioTarjeta': 99,
      });
      expect(d.disenoId, 'aurora');
      expect(d.densidad, DisenoVista.maxDensidad);
      expect(d.columnasMax, DisenoVista.maxColumnas);
      expect(d.radioTarjeta, DisenoVista.maxRadio);
    });

    test('desdeJson no inventa campos que no vinieron', () {
      final d = DisenoVista.desdeJson({'disenoId': 'aurora'});
      expect(d.densidad, isNull, reason: 'null = hereda la densidad global');
      expect(d.radioTarjeta, isNull);
      expect(d.columnasMax, 0, reason: '0 = automático');
    });

    test('borrarRadio / borrarDensidad vuelven el eje a "hereda"', () {
      const d = DisenoVista(radioTarjeta: 20, densidad: 1.3);
      final borrado = d.copiarCon(borrarRadio: true, borrarDensidad: true);
      expect(borrado.radioTarjeta, isNull);
      expect(borrado.densidad, isNull);
      expect(borrado.esHereda, isTrue);
    });

    test('copiarCon sin argumentos no toca nada', () {
      const d = DisenoVista(disenoId: 'x', densidad: 1.2);
      expect(d.copiarCon().disenoId, 'x');
      expect(d.copiarCon().densidad, 1.2);
    });
  });

  group('guardar y leer (JSON)', () {
    test('lo personalizado sobrevive el viaje de ida y vuelta', () {
      final prefs = PreferenciasVistas.deFabrica
          .conVista(
            VistaApp.reproductor,
            const DisenoVista(
              disenoId: 'olas',
              tipografiaId: 'inter',
              radioTarjeta: 22,
              densidad: 1.4,
              columnasMax: 3,
            ),
          )
          .conVista(VistaApp.busqueda, const DisenoVista(fondoId: 'vidrio'));

      final guardado = PreferenciasVistasJson.codificar(prefs);
      final leido = PreferenciasVistasJson.decodificar(guardado);

      expect(leido.cantidadPersonalizadas, 2);
      final repro = leido.para(VistaApp.reproductor);
      expect(repro.disenoId, 'olas');
      expect(repro.tipografiaId, 'inter');
      expect(repro.radioTarjeta, 22);
      expect(repro.densidad, 1.4);
      expect(repro.columnasMax, 3);
      expect(leido.para(VistaApp.busqueda).fondoId, 'vidrio');
    });

    test('sin nada guardado (o con basura) vuelve a fábrica', () {
      expect(PreferenciasVistasJson.decodificar(null).esDeFabrica, isTrue);
      expect(PreferenciasVistasJson.decodificar('').esDeFabrica, isTrue);
      expect(
        PreferenciasVistasJson.decodificar('no soy json').esDeFabrica,
        isTrue,
      );
      expect(PreferenciasVistasJson.decodificar('[1,2,3]').esDeFabrica, isTrue);
      expect(PreferenciasVistasJson.decodificar('{}').esDeFabrica, isTrue);
    });

    test('una vista que ya no existe se ignora, sin perder las otras', () {
      const raw = '{"vista_que_ya_no_esta":{"disenoId":"x"},'
          '"ajustes":{"disenoId":"paleta_oro"}}';
      final prefs = PreferenciasVistasJson.decodificar(raw);
      expect(prefs.cantidadPersonalizadas, 1);
      expect(prefs.para(VistaApp.ajustes).disenoId, 'paleta_oro');
    });

    test('un diseño vacío guardado no deja la vista "personalizada"', () {
      const raw = '{"feed":{"disenoId":""}}';
      expect(PreferenciasVistasJson.decodificar(raw).esDeFabrica, isTrue);
    });
  });

  group('claves de vista', () {
    test('la clave guardada es estable y no depende del índice', () {
      expect(VistaApp.desdeClave('mi_espacio'), VistaApp.miEspacio);
      expect(VistaApp.desdeClave('ajustes'), VistaApp.ajustes);
      expect(VistaApp.desdeClave('no_existe'), isNull);
      expect(VistaApp.desdeClave(null), isNull);
      final claves = VistaApp.values.map((v) => v.clave).toSet();
      expect(claves.length, VistaApp.values.length, reason: 'sin repetidas');
    });
  });
}
