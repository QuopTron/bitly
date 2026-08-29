import 'dart:convert';
import 'package:flutter/material.dart';

import '../utils/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../../backend/cache/settings_cache.dart';
import '../../../backend/rpc/backend_service.dart';
import '../../../backend/rpc/mixins/actions_mixin.dart';
import '../../../injection.dart';
import 'glass_container.dart';

/// Configures the ordered list of download providers used while falling back
/// during a download (best-first), mirroring SpotiFLAC's SetProviderPriority.
///
/// The user drags providers to choose which source is tried first and disables
/// the ones they never want used (e.g. providers that are rate-limited or
/// blocked for them). The chosen order is persisted and pushed to the Go
/// backend so album/playlist batches skip failing sources earlier.
class SettingsDownloadPrioritySection extends StatefulWidget {
  final Color onBg;
  final Color glowColor;

  const SettingsDownloadPrioritySection({
    super.key,
    required this.onBg,
    required this.glowColor,
  });

  @override
  State<SettingsDownloadPrioritySection> createState() =>
      _SettingsDownloadPrioritySectionState();
}

/// Canonical known download providers, best-first by default. Mirrors Go's
/// [preferredStreamOrder]. Only registered providers are used at runtime; Go
/// drops unknown/disabled ones when receiving this list.
const Map<String, String> kDownloadProviders = {
  'amazon': 'Amazon Music',
  'deezer': 'Deezer',
  'qobuz-web': 'Qobuz',
  'tidal-web': 'Tidal',
  'youtube': 'YouTube',
  'ytmusic-spotiflac': 'YouTube Music',
  'pandora': 'Pandora',
  'soundcloud': 'SoundCloud',
  'apple-music': 'Apple Music',
  'spotify-web': 'Spotify',
};

class _SettingsDownloadPrioritySectionState
    extends State<SettingsDownloadPrioritySection> {
  List<String> _order = [];
  final Set<String> _enabled = {};
  final BackendService _backend = sl<BackendService>();
  bool _loaded = false;
  Map<String, int> _cooldowns = {}; // provider -> remaining seconds

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cache = sl<SettingsCache>();
    final saved = await cache.getDownloadProviderPriority();
    // Load provider cooldown status
    try {
      final statusJson = await _backend.getProviderHealthStatus();
      final parsed = List<Map<String, dynamic>>.from(
        (jsonDecode(statusJson) as List).map((e) => Map<String, dynamic>.from(e)),
      );
      _cooldowns = {
        for (final s in parsed)
          if (s['cooled'] == true) s['name'] as String: s['seconds'] as int,
      };
    } catch (_) {}
    if (mounted) {
      setState(() {
        // Start from the canonical order, then reflect any saved order so the
        // list renders in the user's preferred sequence.
        _order = kDownloadProviders.keys.toList();
        if (saved.isNotEmpty) {
          _order = saved.where(kDownloadProviders.containsKey).toList();
        }
        // Enable every provider not explicitly dropped from a saved list.
        _enabled
          ..clear()
          ..addAll(_order);
        _loaded = true;
      });
    }
  }

  Future<void> _commit() async {
    final included = _order.where(_enabled.contains).toList();
    final cache = sl<SettingsCache>();
    await cache.saveDownloadProviderPriority(included);
    await (_backend as ActionsMixin).syncDownloadProviderPriority(included);
  }

  void _toggle(String id, bool value) {
    setState(() => value ? _enabled.add(id) : _enabled.remove(id));
    _commit();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final id = _order.removeAt(oldIndex);
      _order.insert(newIndex, id);
    });
    _commit();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final loc = AppLocalizations.of(context);
    final available = _order.length;

    return GlassContainer(
      borderRadius: 16,
      borderColor: widget.onBg.withValues(alpha: 0.08),
      bgColor: widget.onBg.withValues(alpha: 0.03),
      margin: EdgeInsets.symmetric(horizontal: r.spacingM),
      padding: EdgeInsets.all(r.spacingM),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.swap_vert, size: r.subtitleSize, color: widget.glowColor),
          SizedBox(width: r.spacingS),
          Expanded(
            child: Text(
              loc.setup.downloadProviderPriority,
              style: TextStyle(
                fontSize: r.subtitleSize,
                fontWeight: FontWeight.w600,
                color: widget.onBg,
              ),
            ),
          ),
        ]),
        SizedBox(height: 4),
        Text(
          loc.setup.downloadProviderPriorityDesc,
          style: TextStyle(
            fontSize: r.footerSize - 1,
            color: widget.onBg.withValues(alpha: 0.5),
          ),
        ),
        if (!_loaded)
          Padding(
            padding: EdgeInsets.only(top: r.spacingM),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.glowColor,
                ),
              ),
            ),
          )
        else if (available == 0)
          Padding(
            padding: EdgeInsets.only(top: r.spacingM),
            child: Text(
              loc.setup.downloadProviderPriorityEmpty,
              style: TextStyle(
                fontSize: r.footerSize,
                color: widget.onBg.withValues(alpha: 0.5),
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _order.length,
            onReorder: _onReorder,
            buildDefaultDragHandles: false,
            itemBuilder: (context, index) {
              final id = _order[index];
              final name = kDownloadProviders[id] ?? id;
              final enabled = _enabled.contains(id);
              final color =
                  enabled ? widget.onBg : widget.onBg.withValues(alpha: 0.4);
              return Padding(
                key: ValueKey(id),
                padding: EdgeInsets.symmetric(vertical: 3),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _toggle(id, !enabled),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: r.spacingS,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: widget.onBg.withValues(alpha: 0.1),
                        ),
                        color: enabled
                            ? widget.onBg.withValues(alpha: 0.04)
                            : Colors.transparent,
                      ),
                      child: Row(children: [
                        ReorderableDragStartListener(
                          index: index,
                          child: Icon(
                            Icons.drag_indicator,
                            size: r.subtitleSize,
                            color: widget.onBg.withValues(alpha: 0.4),
                          ),
                        ),
                        SizedBox(width: r.spacingS),
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: r.subtitleSize - 1,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                  ),
                                ),
                              ),
                              if (_cooldowns.containsKey(id)) ...[
                                SizedBox(width: r.spacingXS),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${_cooldowns[id]}s',
                                    style: TextStyle(
                                      fontSize: r.footerSize - 3,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Switch(
                          value: enabled,
                          activeTrackColor: widget.glowColor.withValues(alpha: 0.6),
                          activeThumbColor: widget.glowColor,
                          onChanged: (v) => _toggle(id, v),
                        ),
                      ]),
                    ),
                  ),
                ),
              );
            },
          ),
      ]),
    );
  }
}