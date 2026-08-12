import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../models/performance_profile.dart';
import '../../../backend/cache/settings_cache.dart';
import '../../../backend/rpc/backend_service.dart';
import '../../../backend/rpc/mixins/actions_mixin.dart';
import '../../../injection.dart';
import 'glass_container.dart';

/// Selector de perfil de rendimiento (Bajo / Medio / Alto).
/// Al cambiar, persiste el perfil, ajusta la calidad de audio por defecto
/// y sincroniza concurrencia/buffer con el backend Go.
class SettingsPerformanceSection extends StatefulWidget {
  final Color onBg;
  final Color glowColor;

  const SettingsPerformanceSection({super.key, required this.onBg, required this.glowColor});

  @override
  State<SettingsPerformanceSection> createState() => _SettingsPerformanceSectionState();
}

class _SettingsPerformanceSectionState extends State<SettingsPerformanceSection> {
  PerfLevel _level = PerfLevel.medium;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lvl = await sl<SettingsCache>().getPerfLevel();
    if (mounted) setState(() => _level = lvl);
  }

  Future<void> _apply(PerfLevel level) async {
    final profile = PerformanceProfile.forLevel(level);
    setState(() => _level = level);
    final settingsCache = sl<SettingsCache>();
    await settingsCache.savePerfLevel(level);

    // Reflect the active profile app-wide (lists, effects, covers).
    sl<ValueNotifier<PerformanceProfile>>().value = profile;

    // Sync default audio quality with the profile.
    final ds = await settingsCache.getDownloadSettings();
    await settingsCache.saveDownloadSettings(
      ds.copyWith(audioQuality: profile.audioQuality),
    );

    // Push concurrency / buffer to the Go backend.
    await (sl<BackendService>() as ActionsMixin).syncBackendConfig(
      mode: profile.level.key,
      streamCacheMaxMb: profile.streamCacheMaxMb,
      downloadConcurrency: profile.downloadConcurrency,
      streamChunkSize: profile.streamChunkSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final loc = AppLocalizations.of(context);
    final profiles = [
      (PerfLevel.low, loc.setup.perfLow, loc.setup.perfLowDesc, Icons.battery_1_bar),
      (PerfLevel.medium, loc.setup.perfMedium, loc.setup.perfMediumDesc, Icons.balance),
      (PerfLevel.high, loc.setup.perfHigh, loc.setup.perfHighDesc, Icons.rocket_launch),
    ];

    return GlassContainer(
      borderRadius: 16, borderColor: widget.onBg.withValues(alpha: 0.08),
      bgColor: widget.onBg.withValues(alpha: 0.03),
      margin: EdgeInsets.symmetric(horizontal: r.spacingM),
      padding: EdgeInsets.all(r.spacingM),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(loc.setup.performanceProfile,
          style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w600, color: widget.onBg)),
        SizedBox(height: r.spacingM),
        ...profiles.map((p) => Padding(
          padding: EdgeInsets.only(bottom: r.spacingS),
          child: _option(p.$1, p.$2, p.$3, p.$4, r),
        )),
      ]),
    );
  }

  Widget _option(PerfLevel level, String label, String desc, IconData icon, Responsive r) {
    final selected = _level == level;
    final color = selected ? widget.glowColor : widget.onBg.withValues(alpha: 0.5);
    return InkWell(
      key: ValueKey('perf_${level.key}'),
      onTap: () => _apply(level),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.all(r.spacingS),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? widget.glowColor.withValues(alpha: 0.6) : widget.onBg.withValues(alpha: 0.1)),
          color: selected ? widget.glowColor.withValues(alpha: 0.1) : Colors.transparent,
        ),
        child: Row(children: [
          Icon(icon, size: r.subtitleSize, color: color),
          SizedBox(width: r.spacingS),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: r.subtitleSize - 1, fontWeight: FontWeight.w600, color: widget.onBg)),
            SizedBox(height: 2),
            Text(desc, style: TextStyle(fontSize: r.footerSize - 2, color: widget.onBg.withValues(alpha: 0.5))),
          ])),
          if (selected) Icon(Icons.check_circle, size: r.subtitleSize, color: widget.glowColor),
        ]),
      ),
    );
  }
}
