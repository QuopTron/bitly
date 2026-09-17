// ─────────────────────────────────────────────────────────────
// settings_storage_section.dart — Sección de almacenamiento de
// Ajustes: muestra la carpeta de descargas actual y permite
// cambiarla con el explorador. La elección en sí (permiso, picker,
// sync con Go y re-vinculado de archivos) vive en el servicio
// carpeta_descargas.dart, que también usa el aviso de descarga.
// La parte visual vive en settings_storage_section_build.dart.
// Se conecta con: servicio carpeta_descargas + cache_ajustes + l10n.
// Parte del flujo: Ajustes → Descargas → carpeta destino.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../app/inyeccion.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/cache/almacenes/cache_ajustes.dart';
import '../../../core/servicios/descargas/carpeta_descargas.dart';
import '../../../estado/descargas/cubit_descargas.dart';
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

  Future<void> _elegirCarpeta() async {
    if (_eligiendo) return;
    setState(() => _eligiendo = true);
    try {
      final ruta = await elegirCarpetaDescargas(
        tituloDialogo: widget.loc.setup.storageTitle,
      );
      if (ruta != null && mounted) {
        setState(() => _ruta = ruta);
        // Si la carpeta se había dado por perdida, con una ruta que vuelve a
        // ser escribible el aviso de descarga ya no aplica.
        sl<CubitDescargas>().confirmarCarpetaRestaurada();
        _aviso(this, widget.loc.setup.storageSelected);
      }
    } catch (e) {
      _aviso(this, 'Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _eligiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) => _seccionAlmacenamiento(this);
}
