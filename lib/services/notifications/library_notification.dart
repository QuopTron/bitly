/// Notificaciones de escaneo de biblioteca local: progreso, completo, fallo.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:bitly/services/notifications/notification_service.dart';

class NotificationLibrary {
  static final NotificationService _svc = NotificationService();

  static Future<void> showScanProgress({required double progress, required int scannedFiles, required int totalFiles, String? currentFile}) async {
    if (!_svc.isInitialized) await _svc.initialize();
    final pct = progress.clamp(0.0, 100.0).round();
    final body = totalFiles > 0
        ? (_svc.l10n?.notifLibraryScanProgressWithTotal(scannedFiles, totalFiles, pct) ?? '$scannedFiles/$totalFiles files • $pct%')
        : (_svc.l10n?.notifLibraryScanProgressNoTotal(scannedFiles, pct) ?? '$scannedFiles files scanned • $pct%');
    final fullBody = (currentFile != null && currentFile.isNotEmpty) ? '$body\n$currentFile' : body;
    await _svc.showSafely(
      id: libraryScanId,
      title: _svc.l10n?.notifScanningLibrary ?? 'Scanning local library',
      body: fullBody,
      details: NotificationDetails(android: androidScanProgress(progress: pct), iOS: iosSilent),
    );
  }

  static Future<void> showScanComplete({required int totalTracks, int excludedDownloadedCount = 0, int errorCount = 0}) async {
    if (!_svc.isInitialized) await _svc.initialize();
    final extras = <String>[];
    if (excludedDownloadedCount > 0) extras.add(_svc.l10n?.notifLibraryScanExcluded(excludedDownloadedCount) ?? '$excludedDownloadedCount excluded');
    if (errorCount > 0) extras.add(_svc.l10n?.notifLibraryScanErrors(errorCount) ?? '$errorCount errors');
    final suffix = extras.isEmpty ? '' : ' (${extras.join(', ')})';
    await _svc.showSafely(
      id: libraryScanId,
      title: _svc.l10n?.notifLibraryScanComplete ?? 'Library scan complete',
      body: '${_svc.l10n?.notifLibraryScanCompleteBody(totalTracks) ?? '$totalTracks tracks indexed'}$suffix',
      details: NotificationDetails(android: androidScanAlert(), iOS: iosAlertNoSound),
    );
  }

  static Future<void> showScanFailed(String message) async {
    if (!_svc.isInitialized) await _svc.initialize();
    await _svc.showSafely(
      id: libraryScanId,
      title: _svc.l10n?.notifLibraryScanFailed ?? 'Library scan failed',
      body: message,
      details: NotificationDetails(android: androidScanAlert(), iOS: iosAlertNoSound),
    );
  }

  static Future<void> showScanCancelled() async {
    if (!_svc.isInitialized) await _svc.initialize();
    await _svc.showSafely(
      id: libraryScanId,
      title: _svc.l10n?.notifLibraryScanCancelled ?? 'Library scan cancelled',
      body: _svc.l10n?.notifLibraryScanStopped ?? 'Scan stopped before completion.',
      details: NotificationDetails(android: androidScanAlert(), iOS: iosAlertNoSound),
    );
  }

  static Future<void> cancelLibraryScanNotification() async {
    await _svc.cancelNotification(libraryScanId);
  }
}
