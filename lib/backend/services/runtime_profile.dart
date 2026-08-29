import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════════════
// Runtime Profile — device capability detection for adaptive performance
// ═══════════════════════════════════════════════════════════════════════

enum PerformanceTier { low, standard, high }

class RuntimeProfile {
  final PerformanceTier tier;
  final int imageCacheMaximumSize;
  final int imageCacheMaximumSizeBytes;
  final bool disableOverscrollEffects;
  final bool enableBackdropBlur;

  const RuntimeProfile._({
    required this.tier,
    required this.imageCacheMaximumSize,
    required this.imageCacheMaximumSizeBytes,
    required this.disableOverscrollEffects,
    required this.enableBackdropBlur,
  });

  const RuntimeProfile.low()
      : this._(
          tier: PerformanceTier.low,
          imageCacheMaximumSize: 120,
          imageCacheMaximumSizeBytes: 24 << 20,
          disableOverscrollEffects: true,
          enableBackdropBlur: false,
        );

  const RuntimeProfile.standard()
      : this._(
          tier: PerformanceTier.standard,
          imageCacheMaximumSize: 240,
          imageCacheMaximumSizeBytes: 60 << 20,
          disableOverscrollEffects: false,
          enableBackdropBlur: false,
        );

  const RuntimeProfile.high()
      : this._(
          tier: PerformanceTier.high,
          imageCacheMaximumSize: 320,
          imageCacheMaximumSizeBytes: 80 << 20,
          disableOverscrollEffects: false,
          enableBackdropBlur: true,
        );

  static RuntimeProfile? fromTier(String tier) => switch (tier) {
        'low' => const RuntimeProfile.low(),
        'standard' => const RuntimeProfile.standard(),
        'high' => const RuntimeProfile.high(),
        _ => null,
      };

  String get tierKey => switch (tier) {
        PerformanceTier.low => 'low',
        PerformanceTier.standard => 'standard',
        PerformanceTier.high => 'high',
      };
}

const _runtimeProfileTierKey = 'runtime_profile_tier_v1';

/// Loads or creates the runtime profile for the current device.
Future<RuntimeProfile> loadRuntimeProfile(SharedPreferences prefs) async {
  final cachedTier = prefs.getString(_runtimeProfileTierKey);
  if (cachedTier != null) {
    final cached = RuntimeProfile.fromTier(cachedTier);
    if (cached != null) return cached;
  }

  const defaults = RuntimeProfile.standard();
  await prefs.setString(_runtimeProfileTierKey, defaults.tierKey);
  return defaults;
}

/// Saves the runtime profile tier to SharedPreferences.
Future<void> saveRuntimeProfile(SharedPreferences prefs, RuntimeProfile profile) async {
  await prefs.setString(_runtimeProfileTierKey, profile.tierKey);
}

/// Configures the image cache based on the runtime profile.
void configureImageCache(RuntimeProfile profile) {
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = profile.imageCacheMaximumSize;
  imageCache.maximumSizeBytes = profile.imageCacheMaximumSizeBytes;
}
