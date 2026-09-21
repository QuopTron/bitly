// ─────────────────────────────────────────────────────────────
// reproductor_fiesta_nativo.dart — Implementación NATIVA del motor del
// invitado: un reproductor media_kit (mpv) propio del modo fiesta.
//
// Es uno más de los que ya usa la app, así que hereda lo mismo: interfaz
// chica (abrir, buscar, reproducir, pausar) y nada de la cola ni del streaming
// por internet — acá el audio viene del aparato que manda, por la red local.
//
// Se conecta con: reproductor_fiesta.dart (lo elige por plataforma).
// Parte del flujo: reproductor → modo fiesta → unirme.
// ─────────────────────────────────────────────────────────────

import '../../../audio/base/reproductor_audio.dart';
import '../../../audio/base/reproductor_audio_nativo.dart';

/// Motor del invitado en Android/iOS/escritorio.
ReproductorAudio? crearReproductorFiesta() => ReproductorMediaKit();
