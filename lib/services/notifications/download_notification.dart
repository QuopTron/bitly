/// Notificaciones de descarga y cola: progreso, finalización y resumen.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:bitly/services/notifications/notification_service.dart';

class NotificationDownload {
  static final NotificationService _svc = NotificationService();

  static Future<void> showProgress({required String trackName, required String artistName, required int progress, required int total}) async {
    if (!_svc.isInitialized) await _svc.initialize();
    final pct = total > 0 ? (progress * 100 ~/ total) : 0;
    await _svc.showSafely(
      id: downloadProgressId,
      title: _svc.l10n?.notifDownloadingTrack(trackName) ?? 'Downloading $trackName',
      body: '$artistName • $pct%',
      details: NotificationDetails(android: androidDownloadProgress(progress: pct), iOS: iosSilent),
    );
  }

  static Future<void> showFinalizing({required String trackName, required String artistName}) async {
    if (!_svc.isInitialized) await _svc.initialize();
    await _svc.showSafely(
      id: downloadProgressId,
      title: _svc.l10n?.notifFinalizingTrack(trackName) ?? 'Finalizing $trackName',
      body: '$artistName • ${_svc.embeddingMetadataLabel}',
      details: NotificationDetails(android: androidDownloadProgress(progress: 100), iOS: iosSilent),
    );
  }

  static Future<void> showComplete({required String trackName, required String artistName, int? completedCount, int? totalCount, bool alreadyInLibrary = false}) async {
    if (!_svc.isInitialized) await _svc.initialize();
    final title = alreadyInLibrary
        ? (completedCount != null && totalCount != null
            ? (_svc.l10n?.notifAlreadyInLibraryCount(completedCount, totalCount) ?? 'Already in Library ($completedCount/$totalCount)')
            : (_svc.l10n?.notifAlreadyInLibrary ?? 'Already in Library'))
        : (completedCount != null && totalCount != null
            ? (_svc.l10n?.notifDownloadCompleteCount(completedCount, totalCount) ?? 'Download Complete ($completedCount/$totalCount)')
            : (_svc.l10n?.notifDownloadComplete ?? 'Download Complete'));
    await _svc.showSafely(id: downloadProgressId, title: title, body: '$trackName - $artistName', details: NotificationDetails(android: androidDownloadAlert(), iOS: iosAlertNoSound));
  }

  static Future<void> showQueueComplete({required int completedCount, required int failedCount}) async {
    if (!_svc.isInitialized) await _svc.initialize();
    if (completedCount <= 0 && failedCount <= 0) return;
    final title = failedCount > 0
        ? (_svc.l10n?.notifDownloadsFinished(completedCount, failedCount) ?? 'Downloads Finished ($completedCount done, $failedCount failed)')
        : (_svc.l10n?.notifAllDownloadsComplete ?? 'All Downloads Complete');
    final body = failedCount > 0
        ? (_svc.l10n?.notifDownloadsFinishedBody(completedCount, failedCount) ?? '$completedCount downloaded, $failedCount failed')
        : (_svc.l10n?.notifTracksDownloadedSuccess(completedCount) ?? '$completedCount tracks downloaded successfully');
    await _svc.showSafely(id: downloadProgressId, title: title, body: body, details: NotificationDetails(android: androidDownloadAlertSound(), iOS: iosAlert));
  }

  static Future<void> showQueueCanceled({required int canceledCount}) async {
    if (!_svc.isInitialized) await _svc.initialize();
    if (canceledCount <= 0) return;
    await _svc.showSafely(
      id: downloadProgressId,
      title: _svc.l10n?.notifDownloadsCanceledTitle ?? 'Downloads canceled',
      body: _svc.l10n?.notifDownloadsCanceledBody(canceledCount) ?? '$canceledCount downloads canceled by user',
      details: NotificationDetails(android: androidDownloadAlert(), iOS: iosAlertNoSound),
    );
  }

  static Future<void> cancelDownloadNotification() async {
    await _svc.cancelNotification(downloadProgressId);
  }

  static String get embeddingMetadataLabel => _svc.embeddingMetadataLabel;
}
