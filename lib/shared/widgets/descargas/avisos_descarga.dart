// ─────────────────────────────────────────────────────────────
// avisos_descarga.dart — Pega el aviso de descarga a la app.
//
// Por qué existe: el cubit ya calculaba motivos de fallo, gate del
// plan free, carpeta perdida, decrypt fallido y reinicio del backend,
// pero NINGUNA vista los leía. El usuario veía la canción en rojo sin
// explicación y no tenía forma de reintentar una canción suelta.
//
// Acá se escucha el cubit y se muestra UNA tarjeta chica ARRIBA
// (arriba porque abajo vive el miniplayer) con la acción que
// corresponde; al descartarla se confirma el aviso en el cubit para
// que no vuelva a aparecer. Qué aviso toca lo decide
// avisos_descarga_armado.dart, que también usa los imports de este
// archivo (colores/strings/carpeta).
//
// Sin bucles de animación ni polling: solo el stream del cubit.
// Se conecta con: cubit_descargas + tarjeta_aviso_descarga + l10n.
// Parte del flujo: descargas → avisos al usuario.
// ─────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/inyeccion.dart';
import '../../../estado/descargas/cubit_descargas.dart';
import '../../../core/cache/estado/estado_descarga.dart';
import '../../../core/servicios/descargas/carpeta_descargas.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/strings/strings_descargas.dart';
import '../../tema/colores_app.dart';
import 'tarjeta_aviso_descarga.dart';

part 'avisos_descarga_armado.dart';

/// Overlay global de avisos de descarga.
class AvisosDescarga extends StatefulWidget {
  const AvisosDescarga({super.key});

  @override
  State<AvisosDescarga> createState() => _AvisosDescargaState();
}

class _AvisosDescargaState extends State<AvisosDescarga> {
  late final CubitDescargas _cubit = sl<CubitDescargas>();
  StreamSubscription<EstadoCubitDescargas>? _sub;
  EstadoCubitDescargas _estado = const EstadoCubitDescargas();

  /// Cuántos avisos ya se descartaron (para re-animar al aparecer otro).
  int _generacion = 0;

  @override
  void initState() {
    super.initState();
    _estado = _cubit.state;
    _sub = _cubit.stream.listen((e) {
      if (mounted) setState(() => _estado = e);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Hace que el próximo aviso entre animado de nuevo.
  void _cerrar() => setState(() => _generacion++);

  @override
  Widget build(BuildContext context) {
    final aviso = _armarAviso(this);
    return Positioned.fill(
      child: IgnorePointer(
        // Solo la tarjeta recibe toques; el resto de la app queda usable.
        ignoring: aviso == null,
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, left: 12, right: 12),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.12),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: aviso == null
                    ? const SizedBox.shrink()
                    : KeyedSubtree(key: ValueKey(_generacion), child: aviso),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
