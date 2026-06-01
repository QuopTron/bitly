import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/utils/logger.dart';
import 'package:bitly/providers/extension/extension_state.dart';
import 'package:bitly/providers/extension/extension_fallback.dart';

final _log = AppLogger('ExtensionProvider');

mixin ExtensionPriority on Notifier<ExtensionState>, ExtensionFallback {
  static const List<String> _builtInDownloadProviders = ['qobuz_kennyy', 'tidal_monochrome'];

  Future<void> loadProviderPriority() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('provider_priority');
      List<String> priority;
      if (savedJson != null) {
        final saved = tryDecodeStringListPreference(savedJson, 'provider_priority');
        if (saved != null) {
          priority = _sanitizeDownloadProviderPriority(saved);
        } else {
          await prefs.remove('provider_priority');
          priority = _sanitizeDownloadProviderPriority(await PlatformBridge.getProviderPriority());
        }
        await prefs.setString('provider_priority', jsonEncode(priority));
        await PlatformBridge.setProviderPriority(priority);
      } else {
        priority = _sanitizeDownloadProviderPriority(await PlatformBridge.getProviderPriority());
        await prefs.setString('provider_priority', jsonEncode(priority));
        await PlatformBridge.setProviderPriority(priority);
      }
      state = state.copyWith(providerPriority: priority);
    } catch (e) { _log.e('Failed to load provider priority: $e'); }
  }

  Future<void> loadMetadataProviderPriority() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('metadata_provider_priority');
      List<String> priority;
      if (savedJson != null) {
        final saved = tryDecodeStringListPreference(savedJson, 'metadata_provider_priority');
        if (saved != null) {
          priority = _sanitizeMetadataProviderPriority(_replaceRetiredBuiltInMetadataProviders(saved));
        } else {
          await prefs.remove('metadata_provider_priority');
          priority = _sanitizeMetadataProviderPriority(await PlatformBridge.getMetadataProviderPriority());
        }
        await prefs.setString('metadata_provider_priority', jsonEncode(priority));
        await PlatformBridge.setMetadataProviderPriority(priority);
      } else {
        priority = _sanitizeMetadataProviderPriority(await PlatformBridge.getMetadataProviderPriority());
        await prefs.setString('metadata_provider_priority', jsonEncode(priority));
        await PlatformBridge.setMetadataProviderPriority(priority);
      }
      state = state.copyWith(metadataProviderPriority: priority);
    } catch (e) { _log.e('Failed to load metadata provider priority: $e'); }
  }

  Future<void> setProviderPriority(List<String> priority) async {
    try {
      final sanitized = _sanitizeDownloadProviderPriority(priority);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('provider_priority', jsonEncode(sanitized));
      await PlatformBridge.setProviderPriority(sanitized);
      state = state.copyWith(providerPriority: sanitized);
    } catch (e) { _log.e('Failed to set provider priority: $e'); }
  }

  Future<void> setMetadataProviderPriority(List<String> priority) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sanitized = _sanitizeMetadataProviderPriority(_replaceRetiredBuiltInMetadataProviders(priority));
      await prefs.setString('metadata_provider_priority', jsonEncode(sanitized));
      await PlatformBridge.setMetadataProviderPriority(sanitized);
      state = state.copyWith(metadataProviderPriority: sanitized);
    } catch (e) { _log.e('Failed to set metadata provider priority: $e'); }
  }

  List<String> getAllDownloadProviders() {
    final extProviders = _distinctProviderIds(state.extensions.where((ext) => ext.enabled && ext.hasDownloadProvider).map((ext) => ext.id));
    for (final builtIn in _builtInDownloadProviders) { if (!extProviders.contains(builtIn)) extProviders.add(builtIn); }
    return extProviders;
  }

  List<String> getAllMetadataProviders() {
    final metaExts = state.extensions.where((ext) => ext.enabled && ext.hasMetadataProvider).toList();
    final primary = metaExts.where((ext) => ext.searchBehavior?.primary == true).map((ext) => ext.id);
    final other = metaExts.where((ext) => ext.searchBehavior?.primary != true).map((ext) => ext.id);
    final providers = _distinctProviderIds([...primary, ...other]);
    for (final builtIn in _builtInDownloadProviders) { if (!providers.contains(builtIn)) providers.add(builtIn); }
    return providers;
  }

  Future<void> reconcileDownloadProviderPriority() async {
    if (state.providerPriority.isEmpty) return;
    final sanitized = _sanitizeDownloadProviderPriority(state.providerPriority);
    if (stringListEquals(sanitized, state.providerPriority)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('provider_priority', jsonEncode(sanitized));
    await PlatformBridge.setProviderPriority(sanitized);
    state = state.copyWith(providerPriority: sanitized);
  }

  Future<void> reconcileMetadataProviderPriority() async {
    if (state.metadataProviderPriority.isEmpty) return;
    final replaced = _replaceRetiredBuiltInMetadataProviders(state.metadataProviderPriority);
    final sanitized = _sanitizeMetadataProviderPriority(replaced);
    if (stringListEquals(sanitized, state.metadataProviderPriority)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('metadata_provider_priority', jsonEncode(sanitized));
    await PlatformBridge.setMetadataProviderPriority(sanitized);
    state = state.copyWith(metadataProviderPriority: sanitized);
  }

  List<String> _sanitizeDownloadProviderPriority(List<String> input) {
    final allowed = getAllDownloadProviders().toSet();
    final preferredOrder = getAllDownloadProviders();
    final result = <String>[];
    for (final provider in input) { if (allowed.contains(provider) && !result.contains(provider)) result.add(provider); }
    for (final provider in preferredOrder) { if (!result.contains(provider)) result.add(provider); }
    return result;
  }

  List<String> _sanitizeMetadataProviderPriority(List<String> input) {
    final allowed = getAllMetadataProviders().toSet();
    final preferredOrder = getAllMetadataProviders();
    final result = <String>[];
    for (final provider in input) { if (allowed.contains(provider) && !result.contains(provider)) result.add(provider); }
    if (result.isEmpty && preferredOrder.isNotEmpty) return List<String>.from(preferredOrder);
    for (final provider in preferredOrder) { if (!result.contains(provider)) result.add(provider); }
    return result;
  }

  List<String> _replaceRetiredBuiltInMetadataProviders(List<String> input) {
    final result = <String>[];
    for (final provider in input) { final r = replacedBuiltInMetadataProviderFor(provider); final resolved = r ?? provider; if (!result.contains(resolved)) result.add(resolved); }
    return result;
  }

  List<String> _distinctProviderIds(Iterable<String> ids) {
    final seen = <String>{};
    final result = <String>[];
    for (final id in ids) { final normalized = id.trim(); if (normalized.isNotEmpty && seen.add(normalized)) result.add(normalized); }
    return result;
  }
}
