// ─────────────────────────────────────────────────────────────
// slide_gracias.dart — Paso final del setup: muestra "¡Gracias!"
// con countdown de 30s y botón para saltar (aparece a los 5s),
// navega a /home al terminar. Mientras guarda muestra un loader
// con el mensaje de completado. Los sub-widgets (icono, loader,
// countdown) viven en slide_gracias_widgets.dart.
// Se conecta con: go_router (/home) + setup_estado + shared
// (vidrio, botón, responsive, tema) + l10n.
// Parte del flujo: setup (paso 10: gracias → home).
// ─────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/tema/colores_app.dart';
import '../../../shared/utilidades/responsive.dart';
import '../../../shared/widgets/boton_vidrio.dart';
import '../../../shared/widgets/contenedor_vidrio.dart';
import '../bloc/setup_estado.dart';

part 'slide_gracias_widgets.dart';
part 'slide_gracias_cuerpo.dart';

/// Slide final de agradecimiento con countdown a Home.
class SlideGracias extends StatefulWidget {
  final EstadoSetup state;
  final AppLocalizations loc;
  final Responsive r;
  final bool isDark;

  const SlideGracias({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.isDark,
  });

  @override
  State<SlideGracias> createState() => _SlideGraciasState();
}

class _SlideGraciasState extends State<SlideGracias> {
  Timer? _timer;
  int _segundosRestantes = 30;
  bool _mostrarSaltar = false;
  bool _navegando = false;

  @override
  void initState() {
    super.initState();
    if (!widget.state.guardando) _iniciarTimer();
  }

  @override
  void didUpdateWidget(covariant SlideGracias oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.state.guardando && oldWidget.state.guardando && _timer == null) {
      _iniciarTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _iniciarTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _segundosRestantes--);
      if (_segundosRestantes == 25 && mounted) {
        setState(() => _mostrarSaltar = true);
      }
      if (_segundosRestantes <= 0 && mounted) _irAHome();
    });
  }

  void _irAHome() {
    if (_navegando) return;
    _navegando = true;
    _timer?.cancel();
    GoRouter.of(context).go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final onBg = widget.isDark ? Colors.white : Colors.black;
    final glowColor =
        widget.isDark ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;

    if (widget.state.guardando) {
      return _cuerpoGuardando(this, onBg, glowColor);
    }
    return _cuerpoPrincipal(this, onBg, glowColor);
  }
}