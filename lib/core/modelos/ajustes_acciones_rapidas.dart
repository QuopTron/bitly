// ─────────────────────────────────────────────────────────────
// ajustes_acciones_rapidas.dart — Qué hace cada gesto sobre una
// tarjeta de canción, configurable desde Ajustes → Apariencia.
//
// Por qué existe: la tarjeta ya traía UN gesto fijo —deslizar a la
// derecha agregaba a la cola— escrito a mano en el widget. Eso obligaba
// a abrir el menú de los tres puntos para cualquier otra cosa (quitar de
// Mi Espacio, ir al álbum, compartir...). Acá está el mapa gesto → acción
// que reemplaza a ese gesto fijo, con el de fábrica igual al de antes
// para no cambiarle el comportamiento a nadie.
//
// Se guarda con la caché de ajustes (clave/valor), igual que el resto de
// las preferencias que NO necesita viajar al backend Go: esto es
// puramente de interfaz, así que no se empuja al motor de extensiones.
//
// Se conecta con: cache_ajustes (persistencia), tarjeta_acciones_rapidas
// (la burbuja de Ajustes), tarjeta_track_deslizar (el gesto) y main.dart
// (carga al arrancar).
// Parte del flujo: Ajustes → Apariencia → acciones rápidas.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

import '../cache/almacenes/sistema/cache_ajustes.dart';

/// Qué puede hacer un gesto sobre una canción.
///
/// [ninguna] es un valor de pleno derecho (y el de fábrica en casi todos
/// los gestos): deja el gesto sin efecto en vez de obligar a elegir algo.
enum AccionRapida {
  ninguna('nada'),
  agregarCola('cola'),
  meGusta('megusta'),
  descargar('descargar'),
  compartir('compartir'),
  info('info'),
  irAlbum('album'),
  quitarMiEspacio('quitar');

  /// Lo que se guarda en la caché. Es corto y estable: cambiar el nombre
  /// del enum no tiene que invalidar lo que el usuario ya eligió.
  final String clave;

  const AccionRapida(this.clave);

  /// Lee lo guardado. Un valor ausente o desconocido cae en [ninguna].
  static AccionRapida desde(String? guardado) {
    final v = (guardado ?? '').trim().toLowerCase();
    for (final a in values) {
      if (a.clave == v) return a;
    }
    return AccionRapida.ninguna;
  }
}

/// El mapa completo: un gesto por campo.
class AjustesAccionesRapidas {
  /// Id del bloque en la caché de ajustes.
  static const String id = 'acciones_rapidas';

  // Claves de cada gesto (se guardan como `<id>_<clave>`).
  static const String claveDerecha = 'deslizar_derecha';
  static const String claveIzquierda = 'deslizar_izquierda';
  static const String claveArriba = 'deslizar_arriba';
  static const String claveAbajo = 'deslizar_abajo';
  static const String claveDobleToque = 'doble_toque';

  final AccionRapida derecha;
  final AccionRapida izquierda;
  final AccionRapida arriba;
  final AccionRapida abajo;
  final AccionRapida dobleToque;

  const AjustesAccionesRapidas({
    required this.derecha,
    required this.izquierda,
    required this.arriba,
    required this.abajo,
    required this.dobleToque,
  });

  /// De fábrica: solo el gesto que ya existía (deslizar a la derecha
  /// encola). Todo lo demás apagado, así la app se comporta igual que
  /// antes de que existiera esta burbuja.
  static const AjustesAccionesRapidas porDefecto = AjustesAccionesRapidas(
    derecha: AccionRapida.agregarCola,
    izquierda: AccionRapida.ninguna,
    arriba: AccionRapida.ninguna,
    abajo: AccionRapida.ninguna,
    dobleToque: AccionRapida.ninguna,
  );

  /// ¿Hay al menos un gesto con acción? Sin ninguno, la tarjeta no envuelve
  /// nada (ni un widget de más).
  bool get hayAlgo =>
      derecha != AccionRapida.ninguna ||
      izquierda != AccionRapida.ninguna ||
      arriba != AccionRapida.ninguna ||
      abajo != AccionRapida.ninguna ||
      dobleToque != AccionRapida.ninguna;

  /// ¿Algún gesto horizontal? Los horizontales no pelean con el scroll de la
  /// lista; los verticales sí (ver la ayuda de la burbuja).
  bool get hayHorizontal =>
      derecha != AccionRapida.ninguna || izquierda != AccionRapida.ninguna;

  bool get hayVertical =>
      arriba != AccionRapida.ninguna || abajo != AccionRapida.ninguna;

  AjustesAccionesRapidas copyWith({
    AccionRapida? derecha,
    AccionRapida? izquierda,
    AccionRapida? arriba,
    AccionRapida? abajo,
    AccionRapida? dobleToque,
  }) {
    return AjustesAccionesRapidas(
      derecha: derecha ?? this.derecha,
      izquierda: izquierda ?? this.izquierda,
      arriba: arriba ?? this.arriba,
      abajo: abajo ?? this.abajo,
      dobleToque: dobleToque ?? this.dobleToque,
    );
  }

  /// Devuelve una copia con UN gesto cambiado. Lo usa la burbuja de Ajustes:
  /// cambiar un gesto no puede tocar los otros cuatro.
  AjustesAccionesRapidas conGesto(String clave, AccionRapida accion) {
    switch (clave) {
      case claveDerecha:
        return copyWith(derecha: accion);
      case claveIzquierda:
        return copyWith(izquierda: accion);
      case claveArriba:
        return copyWith(arriba: accion);
      case claveAbajo:
        return copyWith(abajo: accion);
      case claveDobleToque:
        return copyWith(dobleToque: accion);
      default:
        return this;
    }
  }

  /// La acción de un gesto, por su clave de guardado.
  AccionRapida gesto(String clave) {
    switch (clave) {
      case claveDerecha:
        return derecha;
      case claveIzquierda:
        return izquierda;
      case claveArriba:
        return arriba;
      case claveAbajo:
        return abajo;
      case claveDobleToque:
        return dobleToque;
      default:
        return AccionRapida.ninguna;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AjustesAccionesRapidas &&
      other.derecha == derecha &&
      other.izquierda == izquierda &&
      other.arriba == arriba &&
      other.abajo == abajo &&
      other.dobleToque == dobleToque;

  @override
  int get hashCode =>
      Object.hash(derecha, izquierda, arriba, abajo, dobleToque);

  /// Lee las cinco claves de la caché. Lo que falte cae en el valor de
  /// fábrica de ese gesto: así una instalación vieja (sin claves) arranca
  /// con el comportamiento de siempre.
  static Future<AjustesAccionesRapidas> leer(CacheAjustes cache) async {
    Future<AccionRapida> g(String clave, AccionRapida siFalta) async {
      final guardado = await cache.getAjuste('${id}_$clave');
      return guardado == null ? siFalta : AccionRapida.desde(guardado);
    }

    return AjustesAccionesRapidas(
      derecha: await g(claveDerecha, porDefecto.derecha),
      izquierda: await g(claveIzquierda, porDefecto.izquierda),
      arriba: await g(claveArriba, porDefecto.arriba),
      abajo: await g(claveAbajo, porDefecto.abajo),
      dobleToque: await g(claveDobleToque, porDefecto.dobleToque),
    );
  }

  /// Guarda los cinco gestos.
  Future<void> guardar(CacheAjustes cache) async {
    await cache.guardarAjuste('${id}_$claveDerecha', derecha.clave);
    await cache.guardarAjuste('${id}_$claveIzquierda', izquierda.clave);
    await cache.guardarAjuste('${id}_$claveArriba', arriba.clave);
    await cache.guardarAjuste('${id}_$claveAbajo', abajo.clave);
    await cache.guardarAjuste('${id}_$claveDobleToque', dobleToque.clave);
  }
}

/// Lo que las tarjetas leen para saber qué hace cada gesto.
///
/// Es un notifier de nivel de archivo (mismo criterio que
/// `notificacionesTuerca`): la tarjeta lo escucha y se repinta sola cuando el
/// usuario cambia algo en Ajustes, sin pasar por el árbol de providers.
final ValueNotifier<AjustesAccionesRapidas> accionesRapidas =
    ValueNotifier<AjustesAccionesRapidas>(AjustesAccionesRapidas.porDefecto);

/// Carga lo guardado en el notifier. Best-effort: si la caché falla, quedan
/// los valores de fábrica.
Future<void> cargarAccionesRapidas(CacheAjustes cache) async {
  try {
    accionesRapidas.value = await AjustesAccionesRapidas.leer(cache);
  } catch (e) {
    debugPrint('[AccionesRapidas] no se pudo cargar: $e');
  }
}
