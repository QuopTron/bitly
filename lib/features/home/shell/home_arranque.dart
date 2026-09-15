// ─────────────────────────────────────────────────────────────
// home_arranque.dart — Helpers de arranque de la Home: armar el
// tutorial interactivo con los textos del locale, provisionar las
// sesiones firmadas al montar y abrir el destino natural de un
// ítem del feed (álbum/playlist/artista/canción).
// Se conecta con: ensamblador_home + tutorial_controller/pasos +
// servicio_verificacion + navegador_detalle.
// Parte del flujo: Home (arranque y navegación del feed).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/modelos/feed/item_feed.dart';
import '../../../core/servicios/verificacion/servicio_verificacion.dart';
import '../../../l10n/app_localizations.dart';
import '../../detalle/comun/navegador_detalle.dart';
import '../../tutorial_interactivo/motor/tutorial_controller.dart';
import '../../tutorial_interactivo/motor/tutorial_pasos.dart';

/// Arranca el tutorial con los textos del locale. Los textos salen del locale
/// (una lista, en el mismo orden que los pasos) y los widgets objetivo se
/// resuelven por GlobalKey.
///
/// Un respiro antes de arrancar: el feed ocupa media pantalla y el primer
/// objetivo del tutorial es su contenido. Sin esta espera el overlay sale en
/// el primer frame, cuando todavía no hay ningún objetivo montado.
Future<void> armarTutorialHome({
  required TutorialController ctrl,
  required AppLocalizations loc,
  required bool Function() estaMontado,
}) async {
  final pasos = crearPasosTutorial(loc.tutorialInteractivo.pasos);
  await Future<void>.delayed(const Duration(milliseconds: 600));
  if (!estaMontado()) return;
  await ctrl.inicializar(pasos);
}

/// Provisiona las sesiones firmadas al arrancar la Home y reintenta las que
/// quedaron pendientes (sin abrir UI).
Future<void> provisionarSesionesHome() async {
  await Future<void>.delayed(const Duration(milliseconds: 500));
  final servicio = ServicioVerificacion();
  try {
    await servicio.provisionarSesionesFirmadas();
    await servicio.reintentarPendientesSilencioso();
  } catch (e) {
    debugPrint("[Home] $e");
  }
}

/// Abre el destino natural de un ítem del feed. Una canción (o un tipo
/// desconocido con álbum) abre su álbum; el resto va a su propia ruta.
void navegarItemFeed(BuildContext context, ItemFeed item) {
  final fuente = item.source ?? '';
  switch (item.type) {
    case 'album':
      abrirDetalleAlbum(
        context,
        id: item.id,
        fuente: fuente,
        coverUrl: item.coverUrl,
      );
    case 'playlist':
      abrirDetallePlaylist(
        context,
        id: item.id,
        nombre: item.name,
        fuente: fuente,
        coverUrl: item.coverUrl,
      );
    case 'artist':
      abrirDetalleArtista(
        context,
        id: item.id,
        nombre: item.name,
        fuente: fuente,
      );
    default:
      if (item.albumId != null && item.albumId!.isNotEmpty) {
        abrirDetalleAlbum(
          context,
          id: item.albumId!,
          fuente: fuente,
          coverUrl: item.coverUrl,
        );
      }
  }
}
