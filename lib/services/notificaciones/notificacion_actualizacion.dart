/// Notificaciones de actualización de la app: progreso, completado, fallo.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:bitly/constants/app_info.dart';
import 'package:bitly/services/notificaciones/notification_service.dart';

class NotificationUpdate {
  static final NotificationService _svc = NotificationService();

  static Future<void> showUpdateDownloadProgress({required String version, required int received, required int total}) async {
    if (!_svc.isInitialized) await _svc.initialize();
    final pct = total > 0 ? (received * 100 ~/ total) : 0;
    final receivedMB = (received / 1024 / 1024).toStringAsFixed(1);
    final totalMB = (total / 1024 / 1024).toStringAsFixed(1);
    await _svc.showSafely(
      id: updateDownloadId,
      title: _svc.l10n?.notifDownloadingUpdate(version) ?? 'Downloading ${AppInfo.appName} v$version',
      body: _svc.l10n?.notifUpdateProgress(receivedMB, totalMB, pct) ?? '$receivedMB / $totalMB MB • $pct%',
      details: NotificationDetails(android: androidDownloadProgress(progress: pct), iOS: iosSilent),
    );
  }

  static Future<void> showUpdateDownloadComplete({required String version}) async {
    if (!_svc.isInitialized) await _svc.initialize();
    await _svc.showSafely(
      id: updateDownloadId,
      title: _svc.l10n?.notifUpdateReady ?? 'Update Ready',
      body: _svc.l10n?.notifUpdateReadyBody(version) ?? '${AppInfo.appName} v$version downloaded. Tap to install.',
      details: NotificationDetails(android: androidDownloadAlertSound(), iOS: iosAlert),
    );
  }

  static Future<void> showUpdateDownloadFailed() async {
    if (!_svc.isInitialized) await _svc.initialize();
    await _svc.showSafely(
      id: updateDownloadId,
      title: _svc.l10n?.notifUpdateFailed ?? 'Update Failed',
      body: _svc.l10n?.notifUpdateFailedBody ?? 'Could not download update. Try again later.',
      details: NotificationDetails(android: androidDownloadAlert(), iOS: iosAlertNoSound),
    );
  }

  static Future<void> cancelUpdateNotification() async {
    await _svc.cancelNotification(updateDownloadId);
  }
}
