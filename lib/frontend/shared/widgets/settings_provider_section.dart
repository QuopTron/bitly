import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../../../backend/cache/settings_cache.dart';
import '../../../backend/rpc/backend_service.dart';
import '../../../backend/services/provider_credential_service.dart';
import '../../../backend/services/youtube_oauth_service.dart';
import '../../../injection.dart';
import '../models/provider_config.dart';
import 'glass_container.dart';

// ---------------------------------------------------------------------------
// Generic multi-provider credential settings section
// ---------------------------------------------------------------------------

/// Settings section for entering provider credentials.
///
/// Supports [ProviderConfig.all] via a provider dropdown. On save:
/// 1. Persists to [SettingsCache]
/// 2. Pushes to Go extension via [setExtensionSettings]
/// 3. Reinitializes extension so JS [initialize] stores via [credentials.store]
class SettingsProviderSection extends StatefulWidget {
  final Color onBg;
  final Color glowColor;

  const SettingsProviderSection({super.key, required this.onBg, required this.glowColor});

  @override
  State<SettingsProviderSection> createState() => _SettingsProviderSectionState();
}

class _SettingsProviderSectionState extends State<SettingsProviderSection> {
  ProviderConfig _selected = ProviderConfig.all.first;
  final _controllers = <String, TextEditingController>{};
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Ensure controllers exist for the given fields, populating from cache.
  Future<void> _load() async {
    final cache = sl<SettingsCache>();

    // Create controllers for all provider fields
    for (final provider in ProviderConfig.all) {
      for (final field in provider.fields) {
        final key = '${provider.id}_${field.key}';
        _controllers.putIfAbsent(key, () => TextEditingController());
      }
    }

    // Batch-load saved values from cache. The YouTube OAuth client ships
    // with baked-in defaults so "Conectar con YouTube" works out of the box;
    // they show here pre-filled and get persisted on Save like any field.
    final futures = <Future<void>>[];
    for (final entry in _controllers.entries) {
      futures.add(() async {
        final saved = await cache.getSetting(entry.key) ?? '';
        if (saved.isNotEmpty) {
          entry.value.text = saved;
          return;
        }
        // Pre-fill built-in OAuth client values for the YouTube provider.
        if (entry.key == 'ytmusic-spotiflac_oauthClientId') {
          entry.value.text = YoutubeOauthService.defaultClientId;
        } else if (entry.key == 'ytmusic-spotiflac_oauthClientSecret') {
          entry.value.text = YoutubeOauthService.defaultClientSecret;
        }
      }());
    }
    await Future.wait(futures);

    if (mounted) setState(() => _loaded = true);
  }

  void _selectProvider(ProviderConfig? p) {
    if (p != null && mounted) setState(() => _selected = p);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Collect values only for the selected provider
      final settings = <String, String>{};
      for (final field in _selected.fields) {
        final value = _controllers['${_selected.id}_${field.key}']?.text.trim() ?? '';
        if (value.isNotEmpty) settings[field.key] = value;
      }

      debugPrint('[ProviderSettings] Saving ${_selected.id}: ${jsonEncode(settings)}');

      await ProviderCredentialService(
        sl<BackendService>(),
        sl<SettingsCache>(),
      ).saveAndReinitialize(_selected.id, settings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selected.displayName} credentials saved'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[ProviderSettings] Save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save ${_selected.displayName} credentials: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    if (!_loaded) return const SizedBox.shrink();

    return GlassContainer(
      borderRadius: 16,
      borderColor: widget.onBg.withValues(alpha: 0.08),
      bgColor: widget.onBg.withValues(alpha: 0.03),
      margin: EdgeInsets.symmetric(horizontal: r.spacingM),
      padding: EdgeInsets.all(r.spacingM),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Icon(Icons.vpn_key, color: widget.glowColor, size: r.subtitleSize),
          SizedBox(width: r.spacingS),
          Text('Provider Credentials',
            style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w600, color: widget.onBg)),
        ]),
        SizedBox(height: r.spacingM),

        // Provider selector dropdown
        DropdownButtonFormField<ProviderConfig>(
          initialValue: _selected,
          dropdownColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1A1A1A)
              : const Color(0xFFF5F5F5),
          items: ProviderConfig.all.map((p) {
            return DropdownMenuItem(
              value: p,
              child: Row(children: [
                Icon(p.icon, size: r.subtitleSize - 2, color: widget.onBg),
                SizedBox(width: r.spacingXS),
                Text(p.displayName, style: TextStyle(color: widget.onBg)),
              ]),
            );
          }).toList(),
          onChanged: _selectProvider,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: r.spacingS, vertical: r.spacingXS),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: widget.onBg.withValues(alpha: 0.15)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: widget.onBg.withValues(alpha: 0.15)),
            ),
          ),
        ),

        SizedBox(height: r.spacingM),

        // Dynamic fields for the selected provider
        if (_selected.hasCredentialFields) ...[
          ..._selected.fields.map((field) => _buildField(r, field)),
          SizedBox(height: r.spacingM + 4),
        ] else
          Padding(
            padding: EdgeInsets.only(bottom: r.spacingM),
            child: Row(children: [
              Icon(Icons.check_circle_outline,
                size: r.footerSize + 2,
                color: widget.glowColor.withValues(alpha: 0.7)),
              SizedBox(width: r.spacingS),
              Expanded(
                child: Text(
                  'No credentials required — uses built-in session auth.',
                  style: TextStyle(
                    fontSize: r.footerSize,
                    color: widget.onBg.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ]),
          ),

        // Extension actions (SpotiFLAC "button" settings): one-tap side
        // effects like clearing caches / restarting sessions.
        if (_selected.actions.isNotEmpty) ...[
          if (!_selected.hasCredentialFields) SizedBox(height: r.spacingS),
          ..._selected.actions.map((a) => Padding(
                padding: EdgeInsets.only(bottom: r.spacingS),
                child: _buildAction(r, a),
              )),
          SizedBox(height: r.spacingS),
        ],

        // Save button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save, size: 18),
            label: Text(_saving ? 'Saving...' : 'Save & Reinitialize'),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.glowColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: r.spacingS),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ),

      ]),
    );
  }

  Widget _buildAction(Responsive r, ProviderAction action) {
    return OutlinedButton.icon(
      onPressed: () => _runAction(action),
      icon: Icon(action.icon, size: r.subtitleSize - 2, color: widget.glowColor),
      label: Text(action.label,
        style: TextStyle(
          fontSize: r.footerSize,
          color: widget.onBg.withValues(alpha: 0.75),
          fontWeight: FontWeight.w500,
        )),
      style: OutlinedButton.styleFrom(
        foregroundColor: widget.glowColor,
        side: BorderSide(color: widget.glowColor.withValues(alpha: 0.35)),
        padding: EdgeInsets.symmetric(vertical: r.spacingXS + 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: widget.glowColor.withValues(alpha: 0.06),
      ),
    );
  }

  /// Confirms (when needed) and runs an extension action, then reports the
  /// JS result via a snackbar so failures are visible.
  Future<void> _runAction(ProviderAction action) async {
    final backend = sl<BackendService>();
    // An action that fails is still shown as "not ok" (no silent swallow).
    void report(Map<String, dynamic> res) {
      if (!mounted) return;
      final err = res['error'] as String?;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err != null
            ? '${_selected.displayName}: $err'
            : '${_selected.displayName}: ${action.label} ✓'),
        backgroundColor: err != null ? Colors.redAccent : null,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
    }

    if (action.confirmMessage != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(action.label),
          content: Text(action.confirmMessage!),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ejecutar'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    if (!mounted) return;

    // ── YouTube OAuth actions run in Dart (browser flow + token storage),
    // not as JS extension exports.
    if (_selected.id == 'ytmusic-spotiflac') {
      if (action.action == 'youtubeOauthConnect') {
        final msg = await YoutubeOauthService().connect();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg),
            backgroundColor: msg.startsWith('Sesión de YouTube conectada')
                ? null
                : Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ));
        }
        return;
      }
      if (action.action == 'youtubeOauthLogout') {
        final msg = await YoutubeOauthService().logout();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ));
        }
        return;
      }
    }

    final res = await backend.invokeExtensionAction(_selected.id, action.action);
    report(res);
  }

  Widget _buildField(Responsive r, ProviderField field) {
    return Padding(
      padding: EdgeInsets.only(bottom: r.spacingM),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(field.label,
          style: TextStyle(fontSize: r.footerSize, color: widget.onBg.withValues(alpha: 0.6))),
        SizedBox(height: r.spacingXS),
        TextField(
          controller: _controllers['${_selected.id}_${field.key}'],
          obscureText: !field.multiline,
          maxLines: field.multiline ? 3 : 1,
          style: TextStyle(color: widget.onBg, fontSize: r.subtitleSize - 1),
          decoration: InputDecoration(
            hintText: field.hint,
            hintStyle: TextStyle(color: widget.onBg.withValues(alpha: 0.25)),
            filled: true,
            fillColor: widget.onBg.withValues(alpha: 0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: widget.onBg.withValues(alpha: 0.15)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: widget.onBg.withValues(alpha: 0.15)),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: r.spacingS,
              vertical: field.multiline ? r.spacingS : r.spacingXS + 4,
            ),
          ),
        ),
      ]),
    );
  }
}

