// ─────────────────────────────────────────────────────────────
// settings_cache_section.dart — Sección de caché de streaming en Ajustes: muestra el uso de
// disco, permite limpiar la caché y fijar el límite en MB.
// Se conecta con: backend_go (getStreamCacheStats/clearStreamCache) + UI.
// Parte del flujo: Ajustes → Rendimiento/Descargas (caché).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../../shared/utilidades/plataforma/responsive.dart';
import '../../../core/backend_go/nucleo/contrato_backend.dart';
import '../../../app/inyeccion.dart';
import '../../../shared/widgets/vidrio/contenedor_vidrio.dart';

import 'settings_cache_bloques.dart';

import 'settings_cache_selector.dart';

import 'settings_cache_stats.dart';

class SettingsCacheSection extends StatefulWidget {
  final Color onBg;
  final Color glowColor;

  const SettingsCacheSection({super.key, required this.onBg, required this.glowColor});

  @override
  State<SettingsCacheSection> createState() => _SettingsCacheSectionState();
}

class _SettingsCacheSectionState extends State<SettingsCacheSection> {
  Map<String, dynamic> _stats = <String, dynamic>{};
  bool _loading = true;
  bool _clearing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final stats = await sl<BackendService>().getStreamCacheStats();
      if (mounted) setState(() { _stats = stats; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
        title: Text('Limpiar caché', style: TextStyle(color: widget.onBg)),
        content: Text(
          'Se borrarán los archivos temporales de streaming.\n\n'
          '${fmtBytes(_stats['total_size_bytes'] as int? ?? 0)} serán liberados.',
          style: TextStyle(color: widget.onBg.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: widget.onBg.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Limpiar',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _clearing = true);
    try {
      await sl<BackendService>().clearStreamCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Caché de streaming limpiado'),
          duration: const Duration(seconds: 2),
        ));
      }
      await _loadStats();
    } catch (e) { debugPrint("[Feature] $e"); }
    if (mounted) setState(() => _clearing = false);
  }

  Future<void> _setMaxMb(int mb) async {
    setState(() => _saving = true);
    try {
      await sl<BackendService>().setStreamCacheMaxMb(mb);
      await _loadStats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$e'),
          duration: const Duration(seconds: 3),
        ));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final onBg = widget.onBg;
    final glowColor = widget.glowColor;

    return ContenedorVidrio(
      borderRadius: 16, borderColor: onBg.withValues(alpha: 0.08),
      bgColor: onBg.withValues(alpha: 0.03),
      margin: EdgeInsets.symmetric(horizontal: r.spacingM),
      padding: EdgeInsets.all(r.spacingM),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        cacheHeaderRow(
          r: r, onBg: onBg, glowColor: glowColor,
          loading: _loading, clearing: _clearing, onClear: _clearCache,
        ),
        SizedBox(height: r.spacingS),
        if (_loading) ...[
          SizedBox(height: r.spacingM),
          Center(child: Text('Cargando...',
            style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.4)))),
        ] else if (_stats.isEmpty) ...[
          SizedBox(height: r.spacingM),
          Center(child: Text('Caché no disponible',
            style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.4)))),
        ] else ...[
          cacheStatsBlock(
            context: context, r: r, onBg: onBg, glowColor: glowColor,
            stats: _stats, saving: _saving, onSet: _setMaxMb,
          ),
        ],
      ]),
    );
  }
}
