// ─────────────────────────────────────────────────────────────
// slide_verificacion.dart — Paso de verificación de fuentes del
// setup: recorre los proveedores con sesión firmada (Deezer, Qobuz,
// TIDAL, Amazon, Apple, SoundCloud, Pandora), obtiene la URL de
// challenge (getPendingVerificationUrl / triggerExtensionVerification)
// y la abre en el WebView compartido de ServicioVerificacion
// (mostrarVerificacion), completando el grant con Go. Cada fuente
// completa SU propio challenge (un grant no se reutiliza). El
// usuario continúa manualmente al terminar. Los sub-widgets viven
// en el part slide_verificacion_widgets.dart.
// Se conecta con: backend_go (URLs + completeSignedSessionGrant) +
// ServicioVerificacion (WebView) + setup_bloc (VerificacionCompletada).
// Parte del flujo: setup (paso 6: verificación de fuentes).
// ─────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';

import '../../../app/inyeccion.dart' as di;
import '../../../l10n/app_localizations.dart';
import '../../../shared/tema/colores_app.dart';
import '../../../shared/utilidades/responsive.dart';
import '../../../shared/widgets/boton_vidrio.dart';
import '../../../shared/widgets/contenedor_vidrio.dart';
import '../../../core/backend_go/contrato_backend.dart';
import '../../../core/servicios/servicio_verificacion.dart';
import '../bloc/setup_bloc.dart';
import '../bloc/setup_estado.dart';
import '../bloc/setup_evento.dart';

part 'slide_verificacion_widgets.dart';
part 'slide_verificacion_logica.dart';

final _log = Logger();

/// Estado de verificación de cada proveedor.
enum _EstadoProveedor { pendiente, verificando, verificado, fallo }

/// Slide de verificación de fuentes.
class SlideVerificacion extends StatefulWidget {
  final EstadoSetup state;
  final AppLocalizations loc;
  final Responsive r;
  final bool isDark;

  const SlideVerificacion({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.isDark,
  });

  @override
  State<SlideVerificacion> createState() => _SlideVerificacionState();
}

class _SlideVerificacionState extends State<SlideVerificacion> {
  static const _proveedores = [
    ('deezer', 'Deezer'),
    ('qobuz-web', 'Qobuz'),
    ('tidal-web', 'TIDAL'),
    ('amazon', 'Amazon'),
    ('apple-music', 'Apple'),
    ('soundcloud', 'SoundCloud'),
    ('pandora', 'Pandora'),
  ];

  final Map<String, _EstadoProveedor> _estados = {
    for (final p in _proveedores) p.$1: _EstadoProveedor.pendiente,
  };

  bool _verificacionIniciada = false;

  /// Wrapper público para que los parts puedan llamar setState.
  void _aplicar(VoidCallback fn) => setState(fn);

  @override
  Widget build(BuildContext context) {
    final onBg = widget.isDark ? Colors.white : Colors.black;
    final glowColor =
        widget.isDark ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;

    return Padding(
      padding: EdgeInsets.only(bottom: widget.r.bottomPadding),
      child: Column(
        children: [
          const Spacer(),
          _icono(this, onBg),
          SizedBox(height: widget.r.spacingS),
          Text(
            widget.loc.setup.verificationTitle,
            style: TextStyle(
              fontSize: widget.r.titleSize,
              fontWeight: FontWeight.bold,
              color: onBg,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: widget.r.spacingM),
          Expanded(
            child: SingleChildScrollView(
              child: _listaProveedores(this, onBg, glowColor),
            ),
          ),
          SizedBox(height: widget.r.spacingM),
          _acciones(this, onBg, glowColor),
          SizedBox(height: widget.r.spacingM),
        ],
      ),
    );
  }
}