// ─────────────────────────────────────────────────────────────
// slide_carpeta_almacenamiento.dart — Paso de carpeta de descargas
// del setup: elige entre la carpeta por defecto (Documentos/Bitly)
// o una personalizada con el picker; guarda la ruta (guardarRutaDescargas
// + syncDownloadDir a Go) y avanza. Los helpers de ruta viven en el
// part slide_carpeta_almacenamiento_helpers.dart.
// Se conecta con: setup_bloc (SiguientePaso) + cache_ajustes +
// backend_go (syncDownloadDir) + shared (vidrio, botón) + l10n.
// Parte del flujo: setup (paso 8: carpeta de descargas).
// ─────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/inyeccion.dart' as di;
import '../../../l10n/app_localizations.dart';
import '../../../shared/tema/colores_app.dart';
import '../../../shared/utilidades/responsive.dart';
import '../../../shared/widgets/boton_vidrio.dart';
import '../../../shared/widgets/contenedor_vidrio.dart';
import '../../../core/backend_go/contrato_backend.dart';
import '../../../core/cache/cache_ajustes.dart';
import '../bloc/setup_bloc.dart';
import '../bloc/setup_estado.dart';
import '../bloc/setup_evento.dart';
import 'tarjeta_opcion_carpeta.dart';
import 'vista_previa_carpeta.dart';

part 'slide_carpeta_almacenamiento_helpers.dart';
part 'slide_carpeta_almacenamiento_ruta.dart';

/// Slide de selección de carpeta de descargas.
class SlideCarpetaAlmacenamiento extends StatefulWidget {
  final EstadoSetup state;
  final AppLocalizations loc;
  final Responsive r;
  final bool isDark;

  const SlideCarpetaAlmacenamiento({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.isDark,
  });

  @override
  State<SlideCarpetaAlmacenamiento> createState() =>
      _SlideCarpetaAlmacenamientoState();
}

class _SlideCarpetaAlmacenamientoState extends State<SlideCarpetaAlmacenamiento> {
  String? _rutaSeleccionada;
  bool _usandoPorDefecto = false;
  bool _eligiendo = false;

  /// Wrapper público para que los parts puedan llamar setState.
  void _aplicar(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _iniciarPorDefecto();
  }

  Future<void> _iniciarPorDefecto() async {
    final ruta = await rutaCarpetaPorDefecto();
    if (ruta != null && mounted) {
      setState(() {
        _rutaSeleccionada = ruta;
        _usandoPorDefecto = true;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final onBg = widget.isDark ? Colors.white : Colors.black;
    final glowColor =
        widget.isDark ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
    final guardando = widget.state.guardando;
    final loc = widget.loc;
    final r = widget.r;

    return Padding(
      key: const ValueKey('storageFolder'),
      padding: EdgeInsets.only(bottom: r.bottomPadding),
      child: Column(
        children: [
          SizedBox(height: r.spacingM),
          _encabezado(this, onBg, loc, r),
          SizedBox(height: r.spacingM),
          Expanded(
            child: ContenedorVidrio(
              borderRadius: 16,
              borderColor: glowColor.withValues(alpha: 0.15),
              bgColor: onBg.withValues(alpha: 0.02),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: r.spacingL),
                  VistaPreviaCarpeta(
                    tieneRuta: _rutaSeleccionada != null,
                    usandoPorDefecto: _usandoPorDefecto,
                    eligiendo: _eligiendo,
                    rutaMostrada: _usandoPorDefecto
                        ? loc.setup.storageDefaultPath
                        : (_rutaSeleccionada ?? ''),
                    etiquetaSeleccionada: loc.setup.storageSelected,
                    etiquetaSinCarpeta: loc.setup.noFolder,
                    onBg: onBg,
                    glowColor: glowColor,
                  ),
                  SizedBox(height: r.spacingL),
                  _tarjetasOpcion(this, onBg, glowColor, loc, r),
                  const Spacer(),
                  _botonContinuar(this, onBg, glowColor, guardando, loc, r),
                  SizedBox(height: r.spacingL),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}