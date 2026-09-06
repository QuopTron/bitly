import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/app_colors.dart';
import '../utils/responsive.dart';

class UpdateInfo {
  final String version;
  final String body;
  final String downloadUrl;
  final int? apkSize;

  const UpdateInfo({
    required this.version,
    required this.body,
    required this.downloadUrl,
    this.apkSize,
  });
}

class UpdateService {
  static const _releaseUrl =
      'https://api.github.com/repos/QuopTron/bitly/releases/latest';

  String _detectArch() {
    try {
      final abi = _getAndroidAbi();
      if (abi.contains('arm64') || abi.contains('aarch64')) return 'arm64';
      if (abi.contains('armv7') || abi.contains('armeabi-v7a')) return 'armv7';
      if (abi.contains('x86_64') || abi.contains('amd64')) return 'x86_64';
      if (abi.contains('x86') || abi.contains('i686')) return 'x86_64';
    } catch (_) {}
    return 'arm64';
  }

  String _getAndroidAbi() {
    try {
      final result = Process.runSync('getprop', ['ro.product.cpu.abi']);
      return result.stdout.toString().trim().toLowerCase();
    } catch (_) {
      return '';
    }
  }

  String _apkPatternForArch(String arch) {
    switch (arch) {
      case 'arm64':
        return 'app-arm64-v8a-release.apk';
      case 'armv7':
        return 'app-armeabi-v7a-release.apk';
      case 'x86_64':
        return 'app-x86_64-release.apk';
      default:
        return 'app-arm64-v8a-release.apk';
    }
  }

  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http.get(
        Uri.parse(_releaseUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );
      if (response.statusCode != 200) return null;

      final json = _parseJson(response.body);
      if (json == null) return null;

      final tag = json['tag_name'] as String? ?? '';
      final latestVersion = tag.replaceFirst('v', '').trim();
      if (latestVersion.isEmpty) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_isNewer(latestVersion, currentVersion) != true) return null;

      final body = json['body'] as String? ?? '';
      final assets = json['assets'] as List<dynamic>? ?? [];

      final arch = _detectArch();
      final targetApk = _apkPatternForArch(arch);

      String? downloadUrl;
      int? apkSize;
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name == targetApk) {
          downloadUrl = asset['browser_download_url'] as String?;
          apkSize = asset['size'] as int?;
          break;
        }
      }

      if (downloadUrl == null) {
        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (name.endsWith('.apk')) {
            downloadUrl = asset['browser_download_url'] as String?;
            apkSize = asset['size'] as int?;
            break;
          }
        }
      }

      if (downloadUrl == null) return null;

      return UpdateInfo(
        version: latestVersion,
        body: body,
        downloadUrl: downloadUrl,
        apkSize: apkSize,
      );
    } catch (_) {
      return null;
    }
  }

  dynamic _parseJson(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static bool? _isNewer(String newVersion, String currentVersion) {
    final newParts = newVersion.split('.').map(int.tryParse).toList();
    final curParts = currentVersion.split('.').map(int.tryParse).toList();

    if (newParts.any((p) => p == null) || curParts.any((p) => p == null)) {
      return null;
    }

    final maxLen = newParts.length > curParts.length
        ? newParts.length
        : curParts.length;

    for (var i = 0; i < maxLen; i++) {
      final n = i < newParts.length ? newParts[i]! : 0;
      final c = i < curParts.length ? curParts[i]! : 0;
      if (n > c) return true;
      if (n < c) return false;
    }
    return false;
  }
}

Future<void> showUpdateModal(BuildContext context, UpdateInfo info) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _UpdateSheet(info: info),
  );
}

class _UpdateSheet extends StatefulWidget {
  final UpdateInfo info;
  const _UpdateSheet({required this.info});

  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<_UpdateSheet> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  String _formatBytes(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _downloadAndInstall() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });

    try {
      final dir = await getTemporaryDirectory();
      final fileName = 'bitly_${widget.info.version}.apk';
      final file = File('${dir.path}/$fileName');

      final request = http.Request('GET', Uri.parse(widget.info.downloadUrl));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        setState(() => _error = 'Error ${response.statusCode}');
        return;
      }

      final contentLength = response.contentLength ?? 0;
      int received = 0;
      final sink = file.openWrite();

      await response.stream.listen((chunk) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          setState(() => _progress = received / contentLength);
        }
      }).asFuture();

      await sink.flush();
      await sink.close();

      // Open APK with system installer
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        setState(() => _error = 'No se pudo abrir el instalador: ${result.message}');
      } else {
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = AppColors.surface(isDark);
    final onBg = AppColors.onSurface(isDark);
    final muted = AppColors.onSurfaceMuted(isDark);
    final border = AppColors.border(isDark);

    final sizeStr = _formatBytes(widget.info.apkSize);
    final versionLabel = sizeStr.isNotEmpty
        ? 'v${widget.info.version}  •  $sizeStr'
        : 'v${widget.info.version}';

    return Container(
      margin: EdgeInsets.only(top: r.spacingXL * 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: EdgeInsets.only(top: r.spacingM),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: onBg.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              SizedBox(height: r.spacingXL),

              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _downloading
                      ? Icons.downloading_rounded
                      : Icons.system_update,
                  size: 28,
                  color: AppColors.success,
                ),
              ),

              SizedBox(height: r.spacingL),

              // Title
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
                child: Text(
                  _downloading
                      ? 'Descargando actualización...'
                      : 'Hay una nueva actualización',
                  style: TextStyle(
                    fontSize: r.titleSize,
                    fontWeight: FontWeight.bold,
                    color: onBg,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              SizedBox(height: r.spacingXS),

              // Version info
              Text(
                versionLabel,
                style: TextStyle(
                  fontSize: r.subtitleSize,
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),

              SizedBox(height: r.spacingM),

              // Current version
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final current = snapshot.data?.version ?? '...';
                  return Text(
                    'Versión actual: $current',
                    style: TextStyle(
                      fontSize: r.footerSize,
                      color: muted,
                    ),
                  );
                },
              ),

              SizedBox(height: r.spacingL),

              // Download progress
              if (_downloading)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _progress > 0 ? _progress : null,
                          minHeight: 8,
                          backgroundColor: onBg.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.success,
                          ),
                        ),
                      ),
                      SizedBox(height: r.spacingS),
                      Text(
                        _progress > 0
                            ? '${(_progress * 100).toStringAsFixed(0)}%'
                            : 'Preparando...',
                        style: TextStyle(
                          fontSize: r.footerSize,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),

              // Error message
              if (_error != null)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      fontSize: r.footerSize,
                      color: AppColors.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Release notes
              if (!_downloading && widget.info.body.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(r.spacingM),
                    decoration: BoxDecoration(
                      color: onBg.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: Text(
                      widget.info.body,
                      style: TextStyle(
                        fontSize: r.footerSize,
                        color: onBg.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

              SizedBox(height: r.spacingXL),

              // Download & Install button
              if (!_downloading)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _downloadAndInstall,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.download_rounded, size: 20),
                          SizedBox(width: r.spacingS),
                          Text(
                            'Descargar e instalar',
                            style: TextStyle(
                              fontSize: r.subtitleSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Dismiss button
              if (!_downloading)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    r.spacingXL, r.spacingS, r.spacingXL, r.spacingXL,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: muted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Ahora no',
                        style: TextStyle(
                          fontSize: r.footerSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),

              SizedBox(height: r.spacingM),
            ],
          ),
        ),
      ),
    );
  }
}
