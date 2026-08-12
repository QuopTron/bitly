import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../../../backend/rpc/backend_service.dart';
import '../../../injection.dart';
import 'glass_container.dart';

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
          '${_fmtBytes(_stats['total_size_bytes'] as int? ?? 0)} serán liberados.',
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
    } catch (_) {}
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

    return GlassContainer(
      borderRadius: 16, borderColor: onBg.withValues(alpha: 0.08),
      bgColor: onBg.withValues(alpha: 0.03),
      margin: EdgeInsets.symmetric(horizontal: r.spacingM),
      padding: EdgeInsets.all(r.spacingM),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ─────────────────────────────────────────────────
        Row(children: [
          Icon(Icons.storage, color: glowColor, size: r.footerSize + 4),
          SizedBox(width: r.spacingS),
          Expanded(child: Text('Caché de streaming',
            style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w600, color: onBg))),
          if (_loading)
            SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: onBg.withValues(alpha: 0.3))),
          if (!_loading && _stats.isNotEmpty)
            GestureDetector(
              onTap: _clearing ? null : _clearCache,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: r.spacingS, vertical: 4),
                decoration: BoxDecoration(
                  color: _clearing
                      ? onBg.withValues(alpha: 0.05)
                      : Colors.redAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _clearing
                    ? SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: onBg.withValues(alpha: 0.4)))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.delete_outline, size: r.footerSize, color: Colors.redAccent),
                        SizedBox(width: 3),
                        Text('Limpiar',
                          style: TextStyle(fontSize: r.footerSize - 1, color: Colors.redAccent, fontWeight: FontWeight.w500)),
                      ]),
              ),
            ),
        ]),
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
          // ── Stats rows ───────────────────────────────────────────────
          _statRow(Icons.download_done,
              '${_fmtBytes(_stats['total_size_bytes'] as int? ?? 0)} / ${_stats['max_cache_mb'] ?? '?'} MB',
              'usados', onBg, r),
          SizedBox(height: r.spacingXS),
          _statRow(Icons.folder_open, '${_stats['file_count'] ?? 0} archivos',
              'en caché', onBg, r),
          SizedBox(height: r.spacingXS),
          _statRow(Icons.access_time,
              '${_stats['estimated_hours'] ?? 0} h',
              'de audio cacheados', onBg, r),
          SizedBox(height: r.spacingXS),
          _statRow(Icons.thumb_up_alt_outlined, '${_stats['hit_count'] ?? 0} hits',
              '• ${_stats['miss_count'] ?? 0} misses', onBg, r),
          SizedBox(height: r.spacingXS),
          _statRow(Icons.shield_outlined,
              '${_userLevelLabel(_stats['user_level'] as String? ?? 'free')} • máx ${_stats['level_limit_mb'] ?? 200} MB',
              'límite del plan', onBg, r),
          SizedBox(height: r.spacingM),

          // ── Size selector ─────────────────────────────────────────────
          Text('Límite de tamaño',
            style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.6))),
          SizedBox(height: r.spacingXS),
          _sizeSelector(r, onBg, glowColor),
          SizedBox(height: r.spacingXS),
          Row(children: [
            Icon(Icons.info_outline, size: r.footerSize - 1, color: onBg.withValues(alpha: 0.35)),
            SizedBox(width: 4),
            Expanded(child: Text(
              _stats['level_limit_mb'] != null
                  ? 'Tu plan permite hasta ${_stats['level_limit_mb']} MB (${_userLevelLabel(_stats['user_level'] as String? ?? 'free')})'
                  : '',
              style: TextStyle(fontSize: r.footerSize - 2, color: onBg.withValues(alpha: 0.35)))),
          ]),
        ],
      ]),
    );
  }

  Widget _statRow(IconData icon, String value, String label, Color onBg, Responsive r) {
    return Row(children: [
      Icon(icon, size: r.footerSize - 2, color: onBg.withValues(alpha: 0.5)),
      SizedBox(width: r.spacingS),
      Expanded(
        child: RichText(
          text: TextSpan(
            style: TextStyle(fontSize: r.footerSize - 1, color: onBg.withValues(alpha: 0.8)),
            children: [
              TextSpan(text: value, style: TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: '  •  $label', style: TextStyle(color: onBg.withValues(alpha: 0.4))),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _sizeSelector(Responsive r, Color onBg, Color glowColor) {
    final levelLimit = _stats['level_limit_mb'] as int? ?? 200;
    final currentMb = _stats['max_cache_mb'] as int? ?? 200;

    final options = _cacheSizeOptions(levelLimit);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ignore: deprecated_member_use
      DropdownButtonFormField<int>(
        key: ValueKey('cache_mb_$currentMb'),
        initialValue: currentMb,
        dropdownColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
        items: options.map((mb) {
          final isMax = mb >= levelLimit;
          final isCurrent = mb == currentMb;
          return DropdownMenuItem(value: mb, child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('$mb MB',
              style: TextStyle(
                fontSize: r.subtitleSize - 1,
                color: onBg,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.normal,
              )),
            if (isMax) ...[
              SizedBox(width: 6),
              Icon(Icons.star, size: r.footerSize - 2, color: glowColor.withValues(alpha: 0.7)),
              SizedBox(width: 3),
              Text('máx',
                style: TextStyle(fontSize: r.footerSize - 2, color: glowColor)),
            ],
          ]));
        }).toList(),
        onChanged: _saving ? null : (v) { if (v != null && v != currentMb) _setMaxMb(v); },
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: r.spacingS, vertical: r.spacingXS),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: onBg.withValues(alpha: 0.15))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: onBg.withValues(alpha: 0.15))),
        ),
      ),
    ]);
  }

  List<int> _cacheSizeOptions(int limit) {
    final base = [50, 100, 200, 500];
    if (limit <= 200) {
      return base.where((v) => v <= limit).toList();
    }
    return [...base, 1000, 1500, 2048, 3072, 4096].where((v) => v <= limit).toList();
  }

  String _userLevelLabel(String level) {
    switch (level) {
      case 'premium': return 'Premium';
      case 'lifetime': return 'Lifetime';
      default: return 'Free';
    }
  }

  String _fmtBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}


