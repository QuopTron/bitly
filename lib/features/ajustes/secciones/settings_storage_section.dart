// ─────────────────────────────────────────────────────────────
// settings_storage_section.dart — Sección de almacenamiento de
// Ajustes: muestra la carpeta de descargas actual y permite
// cambiarla con el explorador; guarda la ruta en caché, la
// sincroniza con Go y pide el permiso de almacenamiento (Android).
// La parte visual vive en settings_storage_section_build.dart.
// Se conecta con: cache_ajustes + backend_go + permission_handler
// + file_picker + l10n.
// Parte del flujo: Ajustes → Descargas → carpeta destino.
// ─────────────────────────────────────────────────────────────

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/inyeccion.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/cache/almacenes/cache_ajustes.dart';
import '../../../core/cache/almacenes/cache_biblioteca.dart';
import '../../../core/cache/almacenes/cache_descargas.dart';
import '../../../core/backend_go/nucleo/contrato_backend.dart';
import '../../../shared/utilidades/plataforma/deteccion_plataforma.dart';
import '../../../shared/utilidades/plataforma/responsive.dart';
import '../../../shared/widgets/vidrio/contenedor_vidrio.dart';

part 'settings_storage_section_build.dart';

/// Tarjeta de carpeta de descargas: muestra la ruta actual y abre el
/// explorador para cambiarla.
class SettingsStorageSection extends StatefulWidget {
  final Color onBg;
  final Color glowColor;
  final AppLocalizations loc;

  const SettingsStorageSection({
    super.key,
    required this.onBg,
    required this.glowColor,
    required this.loc,
  });

  @override
  State<SettingsStorageSection> createState() => _SettingsStorageSectionState();
}

class _SettingsStorageSectionState extends State<SettingsStorageSection> {
  String? _ruta;
  bool _eligiendo = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final ruta = await sl<CacheAjustes>().getRutaDescargas();
    if (mounted) setState(() => _ruta = ruta);
  }

  /// Pide permiso de almacenamiento/leer-audio en Android. No bloquea:
  /// si se niega, la carpeta por defecto de la app sigue funcionando.
  Future<void> _solicitarPermiso() async {
    if (esEscritorio()) return;
    try {
      final storage = await Permission.storage.status;
      if (!storage.isGranted && !storage.isLimited) {
        await Permission.storage.request();
      }
      final audio = await Permission.audio.status;
      if (!audio.isGranted && !audio.isLimited) {
        await Permission.audio.request();
      }
    } catch (e) {
      debugPrint("[StoragePermission] $e");
    }
  }

  Future<void> _elegirCarpeta() async {
    if (_eligiendo) return;
    setState(() => _eligiendo = true);
    await _solicitarPermiso();
    try {
      final result = await FilePicker.getDirectoryPath(
        dialogTitle: widget.loc.setup.storageTitle,
      );
      if (result != null && result.isNotEmpty) {
        await sl<CacheAjustes>().guardarRutaDescargas(result);
        try {
          await sl<BackendService>().syncDownloadDir(result);
        } catch (e) {
          debugPrint("[Storage] syncDownloadDir: $e");
        }
        // La carpeta cambió: las filas de descargas que apuntaban a la
        // ubicación vieja se re-vinculan con los archivos de la nueva, así la
        // biblioteca sigue reproduciendo lo ya bajado sin re-descargarlo.
        await _reubicarDescargas(result);
        if (mounted) setState(() => _ruta = result);
        _aviso(this, widget.loc.setup.storageSelected);
      }
    } catch (e) {
      _aviso(this, 'Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _eligiendo = false);
    }
  }

  /// Re-vincula el historial con los archivos de [carpeta] y, si cambió algo,
  /// invalida la biblioteca para que la UI relea las rutas nuevas.
  Future<void> _reubicarDescargas(String carpeta) async {
    try {
      final movidos = await sl<CacheDescargas>().reubicarArchivosEnCarpeta(
        carpeta,
      );
      if (movidos > 0) await sl<CacheBiblioteca>().invalidarTodo();
    } catch (e) {
      debugPrint("[Storage] relink: $e");
    }
  }

  @override
  Widget build(BuildContext context) => _seccionAlmacenamiento(this);
}
