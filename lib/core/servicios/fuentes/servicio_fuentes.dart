// ─────────────────────────────────────────────────────────────
// servicio_fuentes.dart — Puerta única a la tipografía activa: bajarla (si
// hace falta), registrarla en Flutter y publicar su familia para el tema.
//
// Por qué existe: hasta ahora la app EMPAQUETABA Google Sans Flex y nunca la
// usaba (el `ThemeData` no declaraba `fontFamily`), así que todo se dibujaba en
// la tipografía del sistema. Acá se cierra ese agujero: se registra la fuente
// y se avisa por un notifier para que el tema se repinte con ella.
//
// Reglas:
//   · la empaquetada siempre funciona (sin red, sin descarga);
//   · si la bajada falla, se VUELVE a la empaquetada y se informa el estado —
//     nunca se queda "elegida pero invisible";
//   · en web no hay archivo local que leer, así que se usa la empaquetada.
//
// La descarga la hace el backend Go (RPC `descargarFuente`), que deja el .ttf
// en disco y devuelve su ruta; la segunda vez no toca la red.
//
// Se conecta con: catalogo_fuentes.dart (qué es cada una) + BackendService
// (descargarFuente/borrarFuentes) + inyeccion (el notifier de la familia) +
// envoltorio_color_dinamico (que pinta con esa familia).
// Parte del flujo: arranque y Ajustes → Apariencia → Tipografía.
// ─────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../app/inyeccion/inyeccion.dart';
import '../../backend_go/nucleo/base/contrato_backend.dart';
import '../../modelos/usuario/fuentes/catalogo_fuentes.dart';
import '../../modelos/usuario/fuentes/fuente_app.dart';

/// Cómo salió la última activación de tipografía (lo que muestra Ajustes).
enum EstadoFuente {
  /// Se está usando la que trae la app.
  empaquetada,

  /// Una bajada quedó registrada y en uso.
  lista,

  /// Se está bajando ahora mismo.
  descargando,

  /// No se pudo bajar: se sigue con la empaquetada.
  sinRed,

  /// La bajada llegó pero no se pudo registrar.
  error,
}

/// Cómo salió el intento de tener una familia lista para pintar.
enum _ResultadoFamilia { listo, sinRed, error }

/// Activa la tipografía elegida y publica su familia.
class ServicioFuentes {
  ServicioFuentes._();

  static final instancia = ServicioFuentes._();

  /// Estado de la última activación. Lo lee la UI de Ajustes.
  static final ValueNotifier<EstadoFuente> estado =
      ValueNotifier<EstadoFuente>(EstadoFuente.empaquetada);

  /// Sube cada vez que una familia queda registrada en Flutter.
  ///
  /// Lo escucha el diseño por vista: una vista puede pintar con una tipografía
  /// distinta a la global y necesita repintar cuando esa familia termina de
  /// bajar. Sin esto, la bajada terminaba y la vista seguía con la letra vieja
  /// hasta el próximo repintado de casualidad.
  static final ValueNotifier<int> generacion = ValueNotifier<int>(0);

  /// Ids cuya bajada está EN CURSO.
  ///
  /// Lo lee la UI de diseño por vista para poder decir "bajando…" mientras
  /// pasa y, cuando termina, distinguir si quedó lista o falló. Sin esto la
  /// pantalla no tenía forma de saber qué estaba pasando y una bajada lenta se
  /// veía igual que una que nunca arrancó.
  static final ValueNotifier<Set<String>> bajando =
      ValueNotifier<Set<String>>(const {});

  /// Id de la tipografía activa: evita repetir el trabajo cuando la vista se
  /// reconstruye (el caso normal, porque el tema se repinta seguido).
  String? _activa;

  /// Ids ya registrados en Flutter. Arranca con la empaquetada, que siempre
  /// está disponible sin red.
  final Set<String> _registradas = <String>{fuenteEmpaquetada.id};

  /// Ids que se están bajando, para no encolar dos veces la misma.
  final Set<String> _enCurso = <String>{};

  /// Familia con la que el tema tiene que pintar. La publica este servicio y
  /// la escucha la raíz de la app.
  ValueNotifier<String?> get familia => sl<ValueNotifier<String?>>();

  /// Pone a andar la tipografía [fuenteId] ('' = la que trae la app).
  ///
  /// [forzar] vuelve a hacer el trabajo aunque ya esté activa: lo usa Ajustes
  /// cuando el usuario toca la que ya tenía para reintentar una bajada fallida.
  Future<void> activar(String fuenteId, {bool forzar = false}) async {
    final fuente = fuentePorId(fuenteId) ?? fuenteEmpaquetada;
    if (!forzar && _activa == fuente.id) return;
    _activa = fuente.id;

    if (fuente.empaquetada) {
      estado.value = EstadoFuente.empaquetada;
      familia.value = fuente.familia;
      return;
    }
    // Web: el backend corre en otro lado, así que la ruta que devuelve no es un
    // archivo de ESTE dispositivo y no hay nada que registrar.
    if (kIsWeb) {
      estado.value = EstadoFuente.sinRed;
      familia.value = fuenteEmpaquetada.familia;
      return;
    }
    if (_enCurso.contains(fuente.id)) return;
    _entrarEnCurso(fuente.id);
    estado.value = EstadoFuente.descargando;
    try {
      await _bajarYRegistrar(fuente);
    } finally {
      _salirDeCurso(fuente.id);
    }
  }

  /// Reintenta la activación de la tipografía que ya está elegida.
  Future<void> reintentar(String fuenteId) => activar(fuenteId, forzar: true);

  /// Deja la familia de [fuenteId] LISTA para pintar, sin cambiar la elección
  /// global.
  ///
  /// Es lo que necesita el diseño por vista: una vista puede escribir con otra
  /// tipografía mientras el resto de la app sigue con la del usuario. Si ya
  /// está registrada no hace nada (ni red), así que es barato llamarlo de más.
  Future<void> asegurarFamilia(String? fuenteId) async {
    final fuente = fuentePorId(fuenteId) ?? fuenteEmpaquetada;
    if (_registradas.contains(fuente.id)) return;
    // La empaquetada ya está puesta y en web no hay archivo de ESTE
    // dispositivo que registrar: en los dos casos no hay nada que bajar.
    if (fuente.empaquetada || kIsWeb) {
      _registradas.add(fuente.id);
      return;
    }
    if (_enCurso.contains(fuente.id)) return;
    _entrarEnCurso(fuente.id);
    try {
      await _registrar(fuente);
    } finally {
      _salirDeCurso(fuente.id);
    }
  }

  /// ¿Esa tipografía ya se puede pintar ahora mismo?
  bool estaRegistrada(String? fuenteId) =>
      _registradas.contains((fuentePorId(fuenteId) ?? fuenteEmpaquetada).id);

  /// ¿Se está bajando esa tipografía?
  bool estaBajando(String? fuenteId) =>
      bajando.value.contains((fuentePorId(fuenteId) ?? fuenteEmpaquetada).id);

  void _entrarEnCurso(String id) {
    _enCurso.add(id);
    bajando.value = {...bajando.value, id};
  }

  void _salirDeCurso(String id) {
    _enCurso.remove(id);
    bajando.value = {...bajando.value}..remove(id);
  }

  /// Borra las tipografías bajadas (Ajustes → liberar espacio). La activa sigue
  /// en uso hasta reiniciar: el archivo ya registrado queda en memoria, y el
  /// próximo arranque vuelve a la empaquetada si no se puede bajar de nuevo.
  Future<void> liberarDescargadas() async {
    try {
      await sl<BackendService>().borrarFuentes();
    } catch (e) {
      debugPrint('[Fuentes] no se pudieron borrar: $e');
    }
  }

  /// Baja el archivo por el backend, lo registra y publica su familia.
  /// Cualquier falla deja la empaquetada puesta.
  Future<void> _bajarYRegistrar(FuenteApp fuente) async {
    switch (await _registrar(fuente)) {
      case _ResultadoFamilia.listo:
        familia.value = fuente.familia;
        estado.value = EstadoFuente.lista;
      case _ResultadoFamilia.sinRed:
        _caerAEmpaquetada(EstadoFuente.sinRed);
      case _ResultadoFamilia.error:
        _caerAEmpaquetada(EstadoFuente.error);
    }
  }

  /// Baja el .ttf y lo deja registrado en Flutter. NO toca la familia activa ni
  /// el estado: los que deciden qué hacer con el resultado son los que llaman.
  Future<_ResultadoFamilia> _registrar(FuenteApp fuente) async {
    try {
      final ruta = await sl<BackendService>().descargarFuente(
        id: fuente.id,
        url: fuente.url,
        sha256: fuente.sha256,
      );
      if (ruta == null || ruta.isEmpty) return _ResultadoFamilia.sinRed;
      final bytes = await File(ruta).readAsBytes();
      final cargador = FontLoader(fuente.familia);
      cargador.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
      await cargador.load();
      _registradas.add(fuente.id);
      generacion.value++;
      return _ResultadoFamilia.listo;
    } catch (e) {
      debugPrint('[Fuentes] no se pudo activar ${fuente.id}: $e');
      return _ResultadoFamilia.error;
    }
  }

  void _caerAEmpaquetada(EstadoFuente motivo) {
    estado.value = motivo;
    familia.value = fuenteEmpaquetada.familia;
  }
}
