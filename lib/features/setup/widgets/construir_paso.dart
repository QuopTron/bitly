// ─────────────────────────────────────────────────────────────
// construir_paso.dart — Constructor global del paso actual del
// setup: dado el estado, devuelve el slide correspondiente
// (chequeo, prompt de reingreso, idioma, usuario, Google, modo,
// carpeta, notificaciones, verificación, gracias). Es COMPARTIDO
// por las variantes móvil y escritorio para no duplicar el switch.
// Se conecta con: todos los slides del setup + setup_estado + l10n.
// Parte del flujo: setup (bienvenida, ambas variantes).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utilidades/responsive.dart';
import '../bloc/setup_estado.dart';
import 'prompt_reingreso.dart';
import 'slide_idioma.dart';
import 'slide_usuario.dart';
import 'slide_google.dart';
import 'slide_modo.dart';
import 'slide_carpeta_almacenamiento.dart';
import 'slide_notificaciones.dart';
import 'slide_verificacion.dart';
import 'slide_gracias.dart';

/// Devuelve el slide del paso actual del setup.
Widget construirPasoSetup(
  EstadoSetup state,
  AppLocalizations loc,
  Responsive r,
  bool esOscuro,
  TextEditingController controladorUsuario,
  void Function(String titulo, String mensaje) mostrarInfo,
) {
  switch (state.paso) {
    case PasoSetup.chequeandoExistente:
      return const Center(
        key: ValueKey('checking'),
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    case PasoSetup.promptReingreso:
      return PromptReingreso(
        key: const ValueKey('returning'),
        state: state,
        loc: loc,
        r: r,
        isDark: esOscuro,
      );
    case PasoSetup.idioma:
      return SlideIdioma(
        key: const ValueKey('language'),
        state: state,
        loc: loc,
        r: r,
        isDark: esOscuro,
      );
    case PasoSetup.usuario:
      return SlideUsuario(
        key: const ValueKey('username'),
        state: state,
        loc: loc,
        r: r,
        isDark: esOscuro,
        controller: controladorUsuario,
      );
    case PasoSetup.googleSignIn:
      return SlideGoogle(
        key: const ValueKey('googleSignIn'),
        state: state,
        loc: loc,
        r: r,
        isDark: esOscuro,
      );
    case PasoSetup.modo:
      return SlideModo(
        key: const ValueKey('mode'),
        state: state,
        loc: loc,
        r: r,
        isDark: esOscuro,
        showInfo: mostrarInfo,
      );
    case PasoSetup.carpetaAlmacenamiento:
      return SlideCarpetaAlmacenamiento(
        key: const ValueKey('storageFolder'),
        state: state,
        loc: loc,
        r: r,
        isDark: esOscuro,
      );
    case PasoSetup.notificaciones:
      return SlideNotificaciones(
        key: const ValueKey('notifications'),
        state: state,
        loc: loc,
        r: r,
        isDark: esOscuro,
      );
    case PasoSetup.verificacion:
      return SlideVerificacion(
        key: const ValueKey('verification'),
        state: state,
        loc: loc,
        r: r,
        isDark: esOscuro,
      );
    case PasoSetup.gracias:
      return SlideGracias(
        key: const ValueKey('thankYou'),
        state: state,
        loc: loc,
        r: r,
        isDark: esOscuro,
      );
  }
}