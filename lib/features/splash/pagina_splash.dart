// ─────────────────────────────────────────────────────────────
// pagina_splash.dart — Selector de la página de arranque: elige
// entre el layout MÓVIL (splash_movil.dart, diseño actual: logo
// centrado full-width) y el de ESCRITORIO (splash_escritorio.dart,
// panel de vidrio centrado con ancho máximo) según
// usarLayoutEscritorio. Aquí vive la lógica de arranque: animación
// de pulso del logo, chequeo del backend (SplashBloc) y navegación
// a /home o /setup según el setup completado.
// Se conecta con: deteccion_plataforma + splash_bloc + shared.
// Parte del flujo: arranque (ruta '/' → home o setup).
// ─────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../shared/utilidades/deteccion_plataforma.dart';
import '../../app/inyeccion.dart' as di;
import '../../core/cache/cache_ajustes.dart';
import 'bloc/splash_bloc.dart';
import 'bloc/splash_estado.dart';
import 'bloc/splash_evento.dart';
import 'splash_escritorio.dart';
import 'splash_movil.dart';

/// Página de splash: elige layout móvil/escritorio y orquesta el arranque.
class PaginaSplash extends StatefulWidget {
  const PaginaSplash({super.key});

  @override
  State<PaginaSplash> createState() => _PaginaSplashState();
}

class _PaginaSplashState extends State<PaginaSplash>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    context.read<SplashBloc>().add(const ChequearBackend());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onConectado() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    final cache = di.sl<CacheAjustes>();
    final data = await cache.cargarDatosSetup();
    if (!mounted) return;
    if (data != null && data.setupCompletado) {
      GoRouter.of(context).go('/home');
    } else {
      GoRouter.of(context).go('/setup');
    }
  }

  @override
  Widget build(BuildContext context) {
    final usarEscritorio = usarLayoutEscritorio(context);

    return Scaffold(
      body: BlocConsumer<SplashBloc, EstadoSplash>(
        listener: (context, state) {
          if (state.status == EstatusSplash.conectado) _onConectado();
        },
        builder: (context, state) {
          if (usarEscritorio) {
            return SplashEscritorio(
              estado: state,
              pulse: _pulse,
            );
          }
          return SplashMovil(
            estado: state,
            pulse: _pulse,
          );
        },
      ),
    );
  }
}

// Nota: SplashMovil y SplashEscritorio reciben el estado y la animación
// como parámetros; cada variante resuelve su propio responsive/colores,
// así el selector no conoce detalles de layout.