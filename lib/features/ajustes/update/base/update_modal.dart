// ─────────────────────────────────────────────────────────────
// update_modal.dart — Modal "Hay una nueva actualización": muestra
// versión, notas y tamaño, descarga el asset correcto y lo instala.
// En Android abre el APK con el instalador del sistema; en Windows
// lanza el instalador `.exe` descargado (mismo release de GitHub).
// La UI vive en el part update_sheet_ui.dart.
// Se conecta con: update_service (detección) + update_info (modelo).
// Parte del flujo: Ajustes → Versión → actualización.
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/plataforma/actualizacion/actualizacion_servicio.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/tema/colores_app.dart';
import '../../../../shared/utilidades/modales/mostrar_modal.dart';
import '../../../../shared/utilidades/plataforma/pantalla/insets_sistema.dart';
import '../../../../shared/utilidades/plataforma/responsive.dart';
import 'update_info.dart';

// Re-exportado para que los llamadores sigan importando el modelo y el
// servicio desde este archivo (contrato previo).
export 'update_info.dart';
export 'update_service.dart';

part '../hoja/update_sheet_bloques.dart';
part '../hoja/update_sheet_acciones.dart';

part '../hoja/update_sheet_ui.dart';

/// Muestra el modal de actualización con los datos del release.
/// `sobreHoja`: se abre desde Ajustes (o desde su aviso) y tapa la hoja de
/// abajo en vez de dejarla asomar por detrás.
Future<void> showUpdateModal(BuildContext context, UpdateInfo info) {
  return mostrarHoja<void>(
    context: context,
    sobreHoja: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _HojaActualizacion(info: info),
  );
}

class _HojaActualizacion extends StatefulWidget {
  final UpdateInfo info;
  const _HojaActualizacion({required this.info});

  @override
  State<_HojaActualizacion> createState() => _EstadoHojaActualizacion();
}

class _EstadoHojaActualizacion extends State<_HojaActualizacion> {
  bool _descargando = false;

  /// La versión YA está bajada y en disco: el botón pasa a "Instalar".
  bool _descargada = false;
  double _progreso = 0;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // En Android la descarga la hace un servicio en segundo plano: al abrir la
    // hoja hay que averiguar si esa versión ya está bajada (para no pedirla de
    // nuevo) o si hay una descarga corriendo (para retomar su progreso).
    if (ActualizacionServicio.soportado) _preparar();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Mira el disco y el servicio antes de mostrar nada. Así la hoja nunca
  /// miente: o dice "ya la tenés", o retoma el progreso real.
  Future<void> _preparar() async {
    try {
      final ya = await ActualizacionServicio.yaDescargada(widget.info.version);
      if (!mounted) return;
      if (ya != null) {
        setState(() => _descargada = true);
        return;
      }
      final p = await ActualizacionServicio.estado();
      if (!mounted) return;
      if (p.estado == EstadoDescargaActualizacion.descargando &&
          p.version == widget.info.version) {
        setState(() {
          _descargando = true;
          _progreso = p.tieneTotal ? p.progreso / 100 : 0;
        });
        _seguirEstado();
      }
    } catch (e) {
      debugPrint('[Actualizacion] preparar: $e');
    }
  }

  /// Sigue el avance del servicio mientras la hoja está abierta.
  void _seguirEstado() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) async {
      final p = await ActualizacionServicio.estado();
      if (!mounted || p.version != widget.info.version) return;
      switch (p.estado) {
        case EstadoDescargaActualizacion.descargando:
          setState(() {
            _descargando = true;
            _progreso = p.tieneTotal ? p.progreso / 100 : 0;
          });
        case EstadoDescargaActualizacion.listo:
          _pararTimer();
          setState(() {
            _descargando = false;
            _descargada = true;
            _progreso = 1;
          });
        case EstadoDescargaActualizacion.error:
          _pararTimer();
          setState(() {
            _descargando = false;
            _progreso = 0;
            _error = p.error ?? 'Error al descargar';
          });
        case EstadoDescargaActualizacion.cancelado:
        case EstadoDescargaActualizacion.inactivo:
          _pararTimer();
          setState(() {
            _descargando = false;
            _progreso = 0;
          });
      }
    });
  }

  void _pararTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Android: deja el APK bajando en segundo plano, con su notificación.
  Future<void> _descargarEnFondo() async {
    if (_descargando) return;
    setState(() {
      _descargando = true;
      _progreso = 0;
      _error = null;
    });
    // Los textos de la notificación viajan desde acá: la dibuja Android.
    await ActualizacionServicio.enviarTextos(AppLocalizations.of(context));
    await ActualizacionServicio.descargar(
      url: widget.info.downloadUrl,
      version: widget.info.version,
      nombreAsset: widget.info.nombreAsset ?? '',
    );
    _seguirEstado();
  }

  /// Abre el instalador del sistema con lo ya bajado.
  Future<void> _instalarLoBajado() async {
    final ok = await ActualizacionServicio.instalar(widget.info.version);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = 'No se pudo abrir el instalador');
    }
  }

  /// Corta la descarga en curso (y borra lo a medias).
  Future<void> _cancelarDescarga() async {
    await ActualizacionServicio.cancelar();
    _pararTimer();
    if (!mounted) return;
    setState(() {
      _descargando = false;
      _progreso = 0;
    });
  }

  @override
  Widget build(BuildContext context) =>
      _construirHojaActualizacion(this, context);

  /// Formatea bytes a una etiqueta legible (KB/MB).
  String _formatearBytes(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Descarga el asset del release y lo instala/lanza según la plataforma.
  Future<void> _descargarEInstalar() async {
    if (_descargando) return;
    setState(() {
      _descargando = true;
      _progreso = 0;
      _error = null;
    });

    try {
      final dir = await getTemporaryDirectory();
      final esWindows = Platform.isWindows;
      final nombre =
          esWindows
              ? 'Bitly-Setup-${widget.info.version}.exe'
              : 'bitly_${widget.info.version}.apk';
      final archivo = File('${dir.path}${Platform.pathSeparator}$nombre');
      if (await archivo.exists()) await archivo.delete();

      final request = http.Request('GET', Uri.parse(widget.info.downloadUrl));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        setState(() => _error = 'Error ${response.statusCode}');
        return;
      }

      final total = response.contentLength ?? 0;
      var recibido = 0;
      final sink = archivo.openWrite();

      await response.stream.listen((chunk) {
        sink.add(chunk);
        recibido += chunk.length;
        if (total > 0 && mounted) {
          setState(() => _progreso = recibido / total);
        }
      }).asFuture();

      await sink.flush();
      await sink.close();

      if (esWindows) {
        // Windows: lanzar el instalador y dejar que él actualice. Se lanza
        // detached para que siga vivo aunque la app se cierre.
        await Process.start(
          archivo.path,
          const [],
          mode: ProcessStartMode.detached,
        );
        if (mounted) Navigator.of(context).pop();
      } else {
        // Android: abrir el APK con el instalador del sistema.
        final resultado = await OpenFilex.open(archivo.path);
        if (resultado.type != ResultType.done) {
          setState(
            () =>
                _error = 'No se pudo abrir el instalador: ${resultado.message}',
          );
        } else if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      debugPrint('[EstadoHojaActualizacion] $e');
      setState(() => _error = 'Error: $e');
    }
  }
}
