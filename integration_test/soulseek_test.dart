// Test en EMULADOR del alta de cuenta de Soulseek: backend Go real (dentro
// del AAR) + la UI real de Ajustes → Más → Soulseek.
//
// QUÉ SE PRUEBA DE VERDAD, Y QUÉ NO
// Se prueba todo el camino que existe FUERA de la red: el RPC
// `soulseekConectar` del backend Go que va dentro del APK, la validación del
// nombre, y que la tarjeta/hoja/widgets se dibujen y reaccionen.
//
// NO se prueba el alta real contra el servidor de Soulseek, a propósito: en
// Soulseek conectar ES registrarse, así que un test con un nombre inventado
// crearía (o intentaría entrar a) una cuenta con un usuario aleatorio en la
// red. El spec oficial del protocolo lo prohíbe por escrito ("It is
// unacceptable to use randomly generated usernames, as such automated
// scripting is disallowed by the official server rules") y el baneo lo come
// el usuario, en su IP.
//
// Por eso TODOS los nombres de este test son rechazados por `ValidarUsuario`
// ANTES de que el cliente abra cualquier conexión. Si alguien agrega un caso
// con un nombre válido, este archivo deja de ser seguro: no lo hagas.
//
// Correr:
//   flutter test integration_test/soulseek_test.dart -d emulator-5554

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:bitly/app/inyeccion.dart' as inj;
import 'package:bitly/core/backend_go/plataformas/backend_android.dart';
import 'package:bitly/core/cache/almacenes/cache_ajustes.dart';
import 'package:bitly/features/ajustes/sheet/settings_sheet_new.dart';
import 'package:bitly/l10n/app_localizations.dart';

/// Nombre que el servidor rechazaría igual por no ser ASCII imprimible.
/// Go lo corta localmente, así que el test recorre el bridge sin tocar la red.
const _nombreNoAscii = 'pablo_con_acento_é';

/// 31 caracteres ASCII: el límite del protocolo es 30. También local.
const _nombreLargo = 'abcdefghijklmnopqrstuvwxyz01234';

/// Host mínimo que abre la hoja de ajustes real, igual que lo hace la app
/// desde el perfil (perfil_mi_espacio_avatar → showSettingsSheet).
class _HostAjustes extends StatelessWidget {
  const _HostAjustes();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showSettingsSheet(
              context,
              username: 'tester',
              isDark: true,
              onThemeChanged: (_) {},
              onLanguageChanged: () {},
            ),
            child: const Text('Abrir ajustes'),
          ),
        ),
      ),
    );
  }
}

Widget _appDePrueba() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    supportedLocales: const [Locale('es'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const _HostAjustes(),
  );
}

/// Bombea frames durante [veces] * 100 ms. En el dispositivo el reloj corre de
/// verdad, así que esto es lo que le da tiempo a un RPC nativo a volver: un
/// `Future` en vuelo no agenda frames y `pumpAndSettle` lo ignoraría.
Future<void> _bombear(WidgetTester tester, {int veces = 45}) async {
  for (var i = 0; i < veces; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Abre Ajustes → Más y deja la hoja estable.
Future<void> _abrirMas(WidgetTester tester) async {
  await tester.pumpWidget(_appDePrueba());
  // Las localizaciones se cargan async: sin este settle el árbol todavía no
  // tiene contenido y los finders no encuentran nada.
  await tester.pumpAndSettle();

  await tester.tap(find.text('Abrir ajustes'));
  await tester.pumpAndSettle();

  final mas = find.text('Más');
  expect(mas, findsWidgets, reason: 'la hoja debe mostrar la pestaña Más');
  await tester.tap(mas.first);
  await tester.pumpAndSettle();
}

/// Deja el tile de Soulseek a la vista (el tab tiene scroll).
Future<void> _traerTile(WidgetTester tester, Finder tile) async {
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await inj.configurarDependencias();
  });

  testWidgets(
    'backend en el dispositivo: soulseekConectar existe y valida el nombre '
    'ANTES de tocar la red',
    (tester) async {
      final backend = BackendAndroid();
      expect(
        await backend.healthCheck(),
        isTrue,
        reason: 'el backend Go debe inicializarse dentro del APK',
      );

      // 1. Nombre no-ASCII. Este es el viaje completo Flutter → bridge → Go.
      final noAscii = await backend.rpcCall('soulseekConectar', {
        'usuario': _nombreNoAscii,
      });
      expect(
        noAscii.toString(),
        contains('ASCII'),
        reason: 'Go debe rechazar el nombre no-ASCII: $noAscii',
      );
      expect(
        noAscii.toString(),
        isNot(contains('"ok":true')),
        reason: 'no debe reportar éxito: $noAscii',
      );

      // 2. Nombre de 31 caracteres (el límite son 30).
      final largo = await backend.rpcCall('soulseekConectar', {
        'usuario': _nombreLargo,
      });
      expect(largo.toString(), contains('30 caracteres'));

      // 3. Sin nombre.
      final vacio = await backend.rpcCall('soulseekConectar', {'usuario': ''});
      expect(vacio.toString(), contains('nombre de usuario'));

      // Los tres rechazos salieron del backend, no de Dart: la respuesta es la
      // forma {ok:false, motivo, error} que emite Go. El motivo es lo que le
      // permite al setup BLOQUEAR el paso en vez de dejar pasar al usuario.
      for (final r in [noAscii, largo, vacio]) {
        final texto = r.toString();
        expect(texto, contains('"ok":false'));
        expect(texto, contains('"motivo":"nombre_invalido"'),
            reason: 'el backend debe marcar el motivo accionable: $texto');
      }
    },
  );

  testWidgets(
    'UI: la tarjeta de Soulseek vive en Más y la hoja pide un solo dato',
    (tester) async {
      final cache = inj.sl<CacheAjustes>();
      await cache.guardarAjuste('soulseek_usuario', '');
      await cache.guardarAjuste('soulseek_password', '');
      // Sin nombre de app no hay nada que proponer: es el usuario nuevo.
      await cache.guardarAjuste('username', '');

      await _abrirMas(tester);

      // La tarjeta: título + una línea + el tile que invita a conectar.
      expect(find.text('Soulseek'), findsWidgets);
      expect(find.text('Conectar Soulseek'), findsOneWidget);
      expect(find.text('Elegís un nombre y listo'), findsOneWidget);
      // No invasiva: nada de campos a la vista en el panel.
      expect(
        find.byType(TextField),
        findsNothing,
        reason: 'el panel no debe mostrar campos hasta abrir la hoja',
      );

      // Abrir la hoja.
      await _traerTile(tester, find.text('Conectar Soulseek'));
      await tester.tap(find.text('Conectar Soulseek'));
      await tester.pumpAndSettle();

      // La hoja: un nombre, el aviso, y el botón que crea la cuenta.
      expect(find.text('Tu nombre en Soulseek'), findsOneWidget);
      expect(find.text('Siguiente'), findsOneWidget);
      expect(
        find.textContaining('Al tocar Siguiente se crea tu cuenta'),
        findsOneWidget,
        reason: 'se avisa al usuario: no se crea nada a sus espaldas',
      );

      // Un nombre que el servidor rechaza (no-ASCII) → error visible en la
      // hoja, sin ninguna conexión a la red.
      await tester.enterText(find.byType(TextField), _nombreNoAscii);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Siguiente'));
      await _bombear(tester);

      expect(
        find.textContaining('ASCII'),
        findsOneWidget,
        reason: 'la hoja debe mostrar el motivo del rechazo',
      );
      expect(
        find.text('Siguiente'),
        findsOneWidget,
        reason: 'la hoja sigue abierta para corregir el nombre',
      );
    },
  );

  testWidgets(
    'UI: con cuenta guardada el tile se pinta y "Ver" revela la contraseña',
    (tester) async {
      final cache = inj.sl<CacheAjustes>();
      await cache.guardarAjuste('soulseek_usuario', 'pablo_bz');
      await cache.guardarAjuste(
        'soulseek_password',
        'ClaveDePrueba1234567890',
      );
      addTearDown(() async {
        await cache.guardarAjuste('soulseek_usuario', '');
        await cache.guardarAjuste('soulseek_password', '');
      });

      await _abrirMas(tester);

      expect(find.text('Soulseek conectado'), findsOneWidget);
      expect(find.text('@pablo_bz'), findsOneWidget);

      await _traerTile(tester, find.text('Soulseek conectado'));
      await tester.tap(find.text('Soulseek conectado'));
      await tester.pumpAndSettle();

      expect(find.text('Cuenta conectada'), findsOneWidget);
      expect(find.text('Contraseña guardada'), findsOneWidget);
      // Invisible por defecto: no hay nada que memorizar.
      expect(find.text('ClaveDePrueba1234567890'), findsNothing);

      // Pero se puede revelar: Soulseek no tiene recuperación de contraseña.
      await tester.tap(find.text('Ver'));
      await tester.pumpAndSettle();
      expect(find.text('ClaveDePrueba1234567890'), findsOneWidget);
      expect(find.text('Ocultar'), findsOneWidget);
    },
  );

  testWidgets(
    'UI: usuario que ya tenía la app → la tarjeta propone sincronizar con su '
    'nombre y la hoja lo trae puesto',
    (tester) async {
      final cache = inj.sl<CacheAjustes>();
      // Caso real: la app ya está configurada (tiene nombre) y Soulseek no.
      await cache.guardarAjuste('username', 'pablo_bz');
      await cache.guardarAjuste('soulseek_usuario', '');
      await cache.guardarAjuste('soulseek_password', '');
      addTearDown(() async {
        await cache.guardarAjuste('username', '');
        await cache.guardarAjuste('soulseek_usuario', '');
        await cache.guardarAjuste('soulseek_password', '');
      });

      await _abrirMas(tester);

      // No se le pide el nombre de nuevo: se le propone el suyo.
      expect(find.text('Sincronizar Soulseek'), findsOneWidget);
      expect(find.text('Usar tu nombre: pablo_bz'), findsOneWidget);

      await _traerTile(tester, find.text('Sincronizar Soulseek'));
      await tester.tap(find.text('Sincronizar Soulseek'));
      await tester.pumpAndSettle();

      // El campo ya viene con su nombre, y se avisa de dónde salió.
      expect(find.text('pablo_bz'), findsWidgets);
      expect(
        find.textContaining('Es el nombre de tu cuenta de la app'),
        findsOneWidget,
      );
      expect(find.text('Siguiente'), findsOneWidget);
    },
  );
}
