// ─────────────────────────────────────────────────────────────
// update_modal.dart — Modal "Hay una nueva actualización": muestra
// versión, notas y tamaño, descarga el asset correcto y lo instala.
// En Android abre el APK con el instalador del sistema; en Windows
// lanza el instalador `.exe` descargado (mismo release de GitHub).
// La UI vive en el part update_sheet_ui.dart.
// Se conecta con: update_service (detección) + update_info (modelo).
// Parte del flujo: Ajustes → Versión → actualización.
// ─────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../shared/tema/colores_app.dart';
import '../../shared/utilidades/responsive.dart';
import 'update_info.dart';

// Re-exportado para que los llamadores sigan importando el modelo y el
// servicio desde este archivo (contrato previo).
export 'update_info.dart';
export 'update_service.dart';

part 'update_sheet_ui.dart';

/// Muestra el modal de actualización con los datos del release.
Future<void> showUpdateModal(BuildContext context, UpdateInfo info) {
  return showModalBottomSheet(
    context: context,
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
  double _progreso = 0;
  String? _error;

  @override
  Widget build(BuildContext context) => _construirHojaActualizacion(this, context);

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
      final nombre = esWindows
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

      await response.stream
          .listen((chunk) {
            sink.add(chunk);
            recibido += chunk.length;
            if (total > 0 && mounted) {
              setState(() => _progreso = recibido / total);
            }
          })
          .asFuture();

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
          setState(() =>
              _error = 'No se pudo abrir el instalador: ${resultado.message}');
        } else if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    }
  }
}
