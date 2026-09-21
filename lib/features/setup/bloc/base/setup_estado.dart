// ─────────────────────────────────────────────────────────────
// setup_estado.dart — Estado del bloc de setup: paso actual del
// flujo de bienvenida (checking → idioma → usuario → Google →
// modo → verificación → carpeta → notificaciones → gracias), datos
// elegidos (idioma, usuario, modo, código premium), flags de
// guardado/validación y los datos de una cuenta existente para el
// prompt de "¿Continuar con tu cuenta?".
// Se conecta con: setup_bloc.dart (estado del bloc) + slides.
// Parte del flujo: setup (flujo de bienvenida de 10 pasos).
// ─────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';
part 'setup_estado_clase.dart';

/// Pasos del flujo de setup en orden.
enum PasoSetup {
  chequeandoExistente,
  promptReingreso,
  idioma,
  usuario,
  googleSignIn,
  modo,
  carpetaAlmacenamiento,
  notificaciones,
  verificacion,
  gracias,
}

/// Estado del alta de la cuenta de Soulseek durante el setup.
///
/// `inactivo` = todavía no se intentó (el usuario no pasó por el paso de
/// nombre), `creando` = el backend está conectando por detrás, y los otros dos
/// son el resultado. El paso final lo muestra: la cuenta se crea sin pedir
/// nada, pero el usuario tiene que poder enterarse de que existe.
enum SyncSoulseek { inactivo, creando, listo, fallo }
