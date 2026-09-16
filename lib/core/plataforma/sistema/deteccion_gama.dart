// ─────────────────────────────────────────────────────────────
// deteccion_gama.dart — Deduce la gama del equipo (baja/media/alta) a partir
// de sus núcleos y su RAM, para elegir el perfil de rendimiento SIN que el
// usuario tenga que configurar nada.
//
// Por qué existe: el perfil se quedaba siempre en "medio", así que un celular
// de gama baja (Helio G / PowerVR, 2–4 GB) arrancaba con desenfoques a
// pantalla completa, 240 imágenes en caché y 3 descargas simultáneas: eso es
// justo lo que lo congelaba. Detectando la gama desde el arranque, ese equipo
// entra en el perfil "bajo" (sin blur, 1 descarga, caché chica) solo.
//
// La RAM se lee de /proc/meminfo (Android/Linux): es la fuente real, no una
// estimación por modelo. Si no se puede leer (iOS, web), se decide por núcleos
// y se asume que alcanza.
//
// Se conecta con: cache_ajustes.getNivelRendimiento (primera vez) y
// perfil_runtime.cargarPerfilRuntime (caché de imágenes).
// Parte del flujo: arranque (adaptación al equipo).
// ─────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../modelos/usuario/perfil_rendimiento.dart';

/// Núcleos y RAM total detectados.
@immutable
class CapacidadDispositivo {
  /// Núcleos lógicos (Dart los reporta siempre, en cualquier plataforma).
  final int nucleos;

  /// RAM total en MB. 0 = no se pudo leer.
  final int ramMb;

  const CapacidadDispositivo({required this.nucleos, required this.ramMb});
}

/// Gama según la capacidad real del equipo.
///
/// Móvil: 4 núcleos o menos, o ≤ 3,3 GB de RAM → baja (es la franja de un
/// Helio G de entrada, y ahí un blur a pantalla completa se paga en frames).
/// Escritorio: se mantiene "media" (la GPU y la RAM de una PC aguantan los
/// efectos; y así no cambia el comportamiento que ya funcionaba).
NivelRendimiento gamaSegunCapacidad({
  required int nucleos,
  required int ramMb,
  required bool esMovil,
}) {
  if (!esMovil) return NivelRendimiento.medio;

  if (nucleos <= 4) return NivelRendimiento.bajo;
  if (ramMb > 0 && ramMb <= 3300) return NivelRendimiento.bajo;
  if (nucleos <= 6) return NivelRendimiento.medio;
  if (ramMb > 0 && ramMb <= 6000) return NivelRendimiento.medio;
  return NivelRendimiento.alto;
}

/// Lee la capacidad del equipo actual.
Future<CapacidadDispositivo> leerCapacidadDispositivo() async {
  final nucleos = Platform.numberOfProcessors;
  return CapacidadDispositivo(nucleos: nucleos, ramMb: await _ramTotalMb());
}

/// Perfil sugerido para ESTE equipo (sin consultar preferencias guardadas).
Future<NivelRendimiento> detectarNivelRendimiento() async {
  if (kIsWeb) return NivelRendimiento.medio;
  final cap = await leerCapacidadDispositivo();
  return gamaSegunCapacidad(
    nucleos: cap.nucleos,
    ramMb: cap.ramMb,
    esMovil: Platform.isAndroid || Platform.isIOS,
  );
}

/// RAM total del sistema en MB (0 si no se puede leer).
Future<int> _ramTotalMb() async {
  if (kIsWeb) return 0;
  if (!Platform.isAndroid && !Platform.isLinux) return 0;
  try {
    final texto = await File('/proc/meminfo').readAsString();
    final m = RegExp(r'MemTotal:\s*(\d+)\s*kB').firstMatch(texto);
    if (m == null) return 0;
    return (int.parse(m.group(1)!) / 1024).round();
  } catch (e) {
    debugPrint("[Gama] $e");
    return 0;
  }
}
