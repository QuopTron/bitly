// release_notas_test.dart — Las notas de una release leídas como texto.
//
// El bug reportado: la hoja de versiones mostraba las novedades con el
// markdown crudo a la vista (almohadillas, asteriscos y el texto repetido en
// español y en inglés, todo dentro de un `Text` recortado a tres líneas), así
// que no se entendía qué traía la versión nueva.
//
// La regla que fija este test: de un cuerpo de release quedan SOLO las
// novedades de UN idioma, partidas en secciones y viñetas, con el titular de
// cada cosa separado del resto y sin ningún símbolo del markdown.
//
// Se conecta con: features/ajustes/update/base/release_notas.dart.
import 'package:flutter_test/flutter_test.dart';

import 'package:bitly/features/ajustes/update/base/release_notas.dart';

/// Cuerpo real de la release 0.9.26: primero español, después inglés,
/// separados por `---`, con las secciones que publica el script de release.
const _cuerpoV0926 = '''
## 🎵 Bitly 0.9.26

### ✨ Novedades
- **Gestos rápidos en las tarjetas de canción**: deslizá para agregar a la cola y doble toque para más opciones. Se configuran en Ajustes → Apariencia.
- **Info de canción, artista y álbum con traducción**: abrí la info de un tema y traducí nombre, artistas y álbum al idioma que elijas.
- **La actualización se descarga en segundo plano**: al haber una versión nueva aparece una notificación con el progreso y la instalás cuando quieras.

### 🔧 Mejoras y correcciones
- Rescate de FLAC y pool de Qobuz más sólidos (timeouts, reintentos y diagnóstico).
- Búsqueda sin duplicados entre fuentes.
- Límite al motor de extensiones para que una extensión no cuelgue la app.
- Correcciones de desbordes y de escalas en la interfaz.

### ⬇️ Descargas
- Android: app-arm64-v8a-release.apk / app-armeabi-v7a-release.apk
- Windows: Bitly-Setup-0.9.26.exe

---

## 🎵 Bitly 0.9.26

### ✨ Highlights
- **Quick gestures on song cards**: swipe to queue, double-tap for more actions.
- **Song, artist and album info with translation**: open a track's info and translate it.

### 🔧 Fixes
- More robust FLAC rescue and Qobuz pool (timeouts, retries, diagnostics).
- A limit on the extension JS engine so one extension cannot hang the app.

### ⬇️ Downloads
- Android: app-arm64-v8a-release.apk
''';

/// Todas las palabras visibles de las notas (títulos y viñetas).
List<String> _palabras(NotasRelease notas) => [
  for (final b in notas.bloques) ...[
    b.titulo,
    for (final i in b.items) ...[i.titulo, i.texto],
  ],
];

void main() {
  group('notas de release', () {
    test('en español deja las secciones y las viñetas de las novedades', () {
      final notas = NotasRelease.parsear(
        _cuerpoV0926,
        esEspanol: true,
        version: '0.9.26',
      );

      expect(
        notas.bloques.map((b) => b.titulo),
        ['✨ Novedades', '🔧 Mejoras y correcciones'],
        reason:
            'quedan las dos secciones de novedades: el encabezado que repite '
            'la versión y las descargas no son novedades',
      );
      expect(notas.total, 7, reason: '3 novedades + 4 mejoras');

      final primera = notas.bloques.first.items.first;
      expect(primera.titulo, 'Gestos rápidos en las tarjetas de canción');
      expect(
        primera.texto,
        startsWith('deslizá para agregar a la cola'),
        reason: 'el destacado en negrita se guarda aparte para pintarlo',
      );
    });

    test('en inglés usa la otra mitad del cuerpo, no las dos', () {
      final notas = NotasRelease.parsear(
        _cuerpoV0926,
        esEspanol: false,
        version: '0.9.26',
      );

      expect(notas.bloques.map((b) => b.titulo), ['✨ Highlights', '🔧 Fixes']);
      expect(
        notas.bloques.first.items.first.titulo,
        'Quick gestures on song cards',
      );
    });

    test('no queda ningún símbolo del markdown a la vista', () {
      for (final esEspanol in [true, false]) {
        final palabras = _palabras(
          NotasRelease.parsear(
            _cuerpoV0926,
            esEspanol: esEspanol,
            version: '0.9.26',
          ),
        );
        for (final palabra in palabras) {
          expect(palabra, isNot(contains('#')), reason: 'almohadillas fuera');
          expect(palabra, isNot(contains('*')), reason: 'asteriscos fuera');
          expect(palabra, isNot(contains('`')), reason: 'código fuera');
          expect(palabra, isNot(contains('](')), reason: 'enlaces resueltos');
          expect(palabra, isNot(contains('http')), reason: 'sin URLs crudas');
        }
      }
    });

    test('saca el rastro de las notas autogeneradas de GitHub', () {
      // GitHub arma "Full Changelog" con "* Fix X by @user in https://...".
      final notas = NotasRelease.parsear('''
## What's Changed
* Bump the Go backend by @QuopTron in https://github.com/QuopTron/bitly/pull/12
* Fix the seek bar by @otro in https://github.com/QuopTron/bitly/pull/13
''', esEspanol: false);

      expect(notas.bloques.single.items.first.texto, 'Bump the Go backend');
      expect(
        notas.bloques.single.items.last.texto,
        'Fix the seek bar',
        reason: 'el "by @usuario in https://..." no le dice nada a nadie',
      );
    });

    test('un cuerpo vacío o sin viñetas no inventa bloques', () {
      expect(NotasRelease.parsear('', esEspanol: true).vacias, isTrue);
      expect(
        NotasRelease.parsear('   \n\n---\n\n  ', esEspanol: true).vacias,
        isTrue,
      );
    });

    test('con un solo idioma lo muestra igual', () {
      // Sin `---` no hay dos mitades: no se puede quedar sin nada.
      final notas = NotasRelease.parsear(
        '### Novedades\n- Algo nuevo\n- Otra cosa',
        esEspanol: false,
      );

      expect(notas.bloques.single.titulo, 'Novedades');
      expect(notas.total, 2);
    });

    test('pega las líneas cortadas al medio en una sola viñeta', () {
      final notas = NotasRelease.parsear(
        '### Novedades\nUn párrafo largo que\nsigue en el renglón de abajo\n- Otra',
        esEspanol: true,
      );

      expect(
        notas.bloques.single.items.first.texto,
        'Un párrafo largo que sigue en el renglón de abajo',
        reason: 'un párrafo cortado no son dos novedades',
      );
      expect(notas.total, 2);
    });
  });
}
