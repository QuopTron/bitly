/// Selector de la variante APK adecuada según la arquitectura del dispositivo.
/// Examina los assets de una release de GitHub, filtra los APKs válidos
/// y selecciona el más compatible (arm64 > universal > arm32) basado
/// en las ABI soportadas por el dispositivo Android.
library;

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:bitly/services/updates/update_models.dart';
import 'package:bitly/utils/logger.dart';

final _log = AppLogger('ApkSelector');

class ApkSelector {
  static List<ApkAsset> collectApkAssets(List<dynamic> assets) {
    final ApkAssets = <ApkAsset>[];

    for (final asset in assets.whereType<Map<Object?, Object?>>()) {
      final assetMap = Map<String, dynamic>.from(asset);
      final name = (assetMap['name'] as String? ?? '').trim();
      final normalizedName = name.toLowerCase();
      if (!normalizedName.endsWith('.apk')) continue;

      final downloadUrl = assetMap['browser_download_url'] as String?;
      final uri = downloadUrl != null ? Uri.tryParse(downloadUrl) : null;
      if (uri == null || uri.scheme != 'https') {
        _log.w('Skipping non-HTTPS APK URL: $downloadUrl');
        continue;
      }

      final variant = _variantFromName(normalizedName);
      if (variant == null) {
        _log.w('Skipping APK with unknown variant: $name');
        continue;
      }

      ApkAssets.add(ApkAsset(name: name, url: uri.toString(), variant: variant));
    }

    return ApkAssets;
  }

  static Future<ApkAsset?> selectForDevice(List<ApkAsset> assets) async {
    if (assets.isEmpty) return null;

    ApkAsset? arm64Asset;
    ApkAsset? arm32Asset;
    ApkAsset? universalAsset;
    for (final asset in assets) {
      switch (asset.variant) {
        case ApkVariant.arm64:
          arm64Asset ??= asset;
        case ApkVariant.arm32:
          arm32Asset ??= asset;
        case ApkVariant.universal:
          universalAsset ??= asset;
      }
    }

    final supportedAbis = await _getSupportedAndroidAbis();
    final hasArm64 = supportedAbis.any(_isArm64Abi);
    final hasArm32 = supportedAbis.any(_isArm32Abi);

    if (hasArm64) return arm64Asset ?? universalAsset ?? arm32Asset;
    if (hasArm32) return arm32Asset ?? universalAsset;

    if (universalAsset != null) {
      _log.w('Could not match APK asset to supported ABIs ${supportedAbis.join(', ')}; falling back to universal APK.');
      return universalAsset;
    }

    _log.w('Could not match APK asset to supported ABIs ${supportedAbis.join(', ')}; no universal APK available.');
    return null;
  }

  static ApkVariant? _variantFromName(String name) {
    if (name.contains('universal')) return ApkVariant.universal;
    if (name.contains('arm64') || name.contains('arm64-v8a')) return ApkVariant.arm64;
    if (name.contains('arm32') || name.contains('armeabi') || name.contains('armv7') || name.contains('v7a')) {
      return ApkVariant.arm32;
    }
    return null;
  }

  static Future<List<String>> _getSupportedAndroidAbis() async {
    if (!Platform.isAndroid) return const [];

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return androidInfo.supportedAbis
          .map((abi) => abi.toLowerCase())
          .where((abi) => abi.isNotEmpty)
          .toSet()
          .toList();
    } catch (e) {
      _log.w('Failed to detect supported Android ABIs: $e');
      return const [];
    }
  }

  static bool _isArm64Abi(String abi) => abi.contains('arm64') || abi.contains('aarch64');
  static bool _isArm32Abi(String abi) => abi.contains('armeabi') || abi.contains('armv7') || abi.contains('arm');
}
