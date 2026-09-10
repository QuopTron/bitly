// ─────────────────────────────────────────────────────────────
// setup_evento.dart — Eventos del bloc de setup: selección de
// idioma, navegación de pasos (siguiente/anterior), cambios de
// usuario/modo/código premium, validación del código, completar el
// setup, chequeo de datos existentes y verificación de fuentes.
// Se conecta con: setup_bloc.dart (maneja los eventos).
// Parte del flujo: setup (flujo de bienvenida).
// ─────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

/// Evento base del bloc de setup.
abstract class EventoSetup extends Equatable {
  const EventoSetup();

  @override
  List<Object?> get props => [];
}

/// Selecciona el idioma de la app.
class SeleccionarIdioma extends EventoSetup {
  final String locale;

  const SeleccionarIdioma(this.locale);

  @override
  List<Object?> get props => [locale];
}

/// Avanza al siguiente paso del setup.
class SiguientePaso extends EventoSetup {
  const SiguientePaso();
}

/// Vuelve al paso anterior del setup.
class PasoAnterior extends EventoSetup {
  const PasoAnterior();
}

/// Cambia el nombre de usuario escrito.
class UsuarioCambiado extends EventoSetup {
  final String usuario;

  const UsuarioCambiado(this.usuario);

  @override
  List<Object?> get props => [usuario];
}

/// Genera un nombre de usuario aleatorio.
class GenerarNombreAleatorio extends EventoSetup {
  const GenerarNombreAleatorio();
}

/// Selecciona el modo de uso (free/premium).
class SeleccionarModo extends EventoSetup {
  final String modo;

  const SeleccionarModo(this.modo);

  @override
  List<Object?> get props => [modo];
}

/// Notifica el cambio de estado de la conexión con Google.
class EstadoGoogleCambiado extends EventoSetup {
  final bool conectado;

  const EstadoGoogleCambiado(this.conectado);

  @override
  List<Object?> get props => [conectado];
}

/// Cambia el código premium escrito.
class CodigoPremiumCambiado extends EventoSetup {
  final String codigo;

  const CodigoPremiumCambiado(this.codigo);

  @override
  List<Object?> get props => [codigo];
}

/// Valida el código premium contra el backend Go.
class ValidarCodigoPremium extends EventoSetup {
  const ValidarCodigoPremium();
}

/// Completa el setup guardando idioma/modo/usuario en CacheAjustes.
class CompletarSetup extends EventoSetup {
  const CompletarSetup();
}

/// Chequea si existe una cuenta previa (setup ya completado).
class ChequearDatosExistentes extends EventoSetup {
  const ChequearDatosExistentes();
}

/// Acepta o descarta los datos de la cuenta existente.
class AceptarDatosExistentes extends EventoSetup {
  final bool aceptar;

  const AceptarDatosExistentes(this.aceptar);

  @override
  List<Object?> get props => [aceptar];
}

/// Notifica que la verificación de fuentes terminó (éxito o error).
class VerificacionCompletada extends EventoSetup {
  final bool exito;
  final String? error;

  const VerificacionCompletada({this.exito = true, this.error});
}