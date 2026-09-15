// ─────────────────────────────────────────────────────────────
// setup_bloc.dart — Bloc del flujo de setup (bienvenida): registra
// todos los eventos del flujo y delega la lógica al mixin
// ManejadoresSetup (navegación de pasos, validación premium,
// completado, datos existentes). Recibe el notifier de idioma para
// reflejar la selección en tiempo real.
// Se conecta con: ManejadoresSetup (lógica) + inyeccion (notifier).
// Parte del flujo: setup (flujo de bienvenida).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/servicios/proveedores/servicio_soulseek.dart';
import 'setup_estado.dart';
import 'setup_evento.dart';
import 'setup_manejadores.dart';

/// Bloc del setup: orquesta los 10 pasos del flujo de bienvenida.
class SetupBloc extends Bloc<EventoSetup, EstadoSetup>
    with ManejadoresSoulseekSetup, ManejadoresSetup, ManejadoresSetupAvanzado {
  final ValueNotifier<Locale> _notifierIdioma;
  final ServicioSoulseek _soulseek;

  /// [soulseek] es un punto de inyección para los tests: el alta real pega
  /// contra la red y el servidor de Soulseek, así que sin esto no se puede
  /// verificar que un nombre tomado BLOQUEA el paso en vez de dejarlo pasar.
  SetupBloc(this._notifierIdioma, {ServicioSoulseek? soulseek})
      : _soulseek = soulseek ?? ServicioSoulseek(),
        super(const EstadoSetup()) {
    on<SeleccionarIdioma>(onSeleccionarIdioma$);
    on<SiguientePaso>(onSiguientePaso$);
    on<PasoAnterior>(onPasoAnterior$);
    on<UsuarioCambiado>(onUsuarioCambiado$);
    on<GenerarNombreAleatorio>(onGenerarNombreAleatorio$);
    on<SeleccionarModo>(onSeleccionarModo$);
    on<EstadoGoogleCambiado>(onEstadoGoogleCambiado$);
    on<CodigoPremiumCambiado>(onCodigoPremiumCambiado$);
    on<ValidarCodigoPremium>(onValidarCodigoPremium$);
    on<CompletarSetup>(onCompletarSetup$);
    on<ChequearDatosExistentes>(onChequearDatosExistentes$);
    on<AceptarDatosExistentes>(onAceptarDatosExistentes$);
    on<VerificacionCompletada>(onVerificacionCompletada$);
    on<IniciarSyncSoulseek>(onIniciarSyncSoulseek$);
    on<SoulseekSyncCompletada>(onSoulseekSyncCompletada$);
  }

  @override
  ValueNotifier<Locale> get notifierIdioma => _notifierIdioma;

  @override
  ServicioSoulseek get servicioSoulseek => _soulseek;
}