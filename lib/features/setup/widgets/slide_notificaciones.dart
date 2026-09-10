// ─────────────────────────────────────────────────────────────
// slide_notificaciones.dart — Paso de permisos de notificaciones
// del setup: solicita el permiso con permission_handler, muestra
// el estado (concedido/denegado) y permite continuar u omitir.
// Los sub-widgets viven en slide_notificaciones_widgets.dart.
// Se conecta con: setup_bloc (SiguientePaso) + permission_handler
// + shared (vidrio, botón, responsive) + l10n.
// Parte del flujo: setup (paso 9: notificaciones).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/tema/colores_app.dart';
import '../../../shared/utilidades/responsive.dart';
import '../../../shared/widgets/boton_vidrio.dart';
import '../../../shared/widgets/contenedor_vidrio.dart';
import '../bloc/setup_bloc.dart';
import '../bloc/setup_estado.dart';
import '../bloc/setup_evento.dart';

part 'slide_notificaciones_widgets.dart';

/// Slide de permiso de notificaciones.
class SlideNotificaciones extends StatefulWidget {
  final EstadoSetup state;
  final AppLocalizations loc;
  final Responsive r;
  final bool isDark;

  const SlideNotificaciones({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.isDark,
  });

  @override
  State<SlideNotificaciones> createState() => _SlideNotificacionesState();
}

class _SlideNotificacionesState extends State<SlideNotificaciones> {
  bool _notificacionHecha = false;
  bool _notificacionConcedida = false;
  bool _solicitando = false;

  bool get _todoHecho => _notificacionHecha;

  Future<void> _solicitarTodo() async {
    if (_solicitando) return;
    setState(() => _solicitando = true);

    if (!_notificacionHecha) {
      final n = await Permission.notification.request();
      if (mounted) {
        setState(() {
          _notificacionHecha = true;
          _notificacionConcedida = n.isGranted;
        });
      }
    }

    if (mounted) setState(() => _solicitando = false);
  }

  void _continuar() {
    if (widget.state.guardando) return;
    context.read<SetupBloc>().add(const SiguientePaso());
  }

  @override
  Widget build(BuildContext context) {
    final onBg = widget.isDark ? Colors.white : Colors.black;
    final glowColor =
        widget.isDark ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
    final guardando = widget.state.guardando;

    return Padding(
      padding: EdgeInsets.only(bottom: widget.r.bottomPadding),
      child: Column(
        children: [
          const Spacer(),
          SizedBox(height: widget.r.spacingXL),
          _icono(this, onBg),
          SizedBox(height: widget.r.spacingS),
          Text(
            widget.loc.setup.notificationTitle,
            style: TextStyle(
              fontSize: widget.r.titleSize,
              fontWeight: FontWeight.bold,
              color: onBg,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: widget.r.spacingM),
          _tarjetasPermiso(this, onBg, glowColor),
          const Spacer(),
          _acciones(this, onBg, glowColor, guardando),
          SizedBox(height: widget.r.spacingM),
        ],
      ),
    );
  }
}