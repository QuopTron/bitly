/// Constantes y constructores de detalles para notificaciones locales.
/// Define los IDs de notificación, canales Android y métodos helper
/// para crear [AndroidNotificationDetails] y [DarwinNotificationDetails].
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const int downloadProgressId = 1;
const int updateDownloadId = 2;
const int libraryScanId = 3;
const String channelId = 'download_progress';
const String channelName = 'Download Progress';
const String channelDescription = 'Shows download progress for tracks';
const String libraryChannelId = 'library_scan';
const String libraryChannelName = 'Library Scan';
const String libraryChannelDescription = 'Shows local library scan progress';

AndroidNotificationDetails androidDownloadProgress({int progress = 0, bool ongoing = true}) {
  return AndroidNotificationDetails(channelId, channelName,
    channelDescription: channelDescription, importance: Importance.low,
    priority: Priority.low, showProgress: true, maxProgress: 100,
    progress: progress, ongoing: ongoing, autoCancel: !ongoing,
    playSound: false, enableVibration: false, onlyAlertOnce: true,
    icon: '@mipmap/ic_launcher');
}

AndroidNotificationDetails androidDownloadAlert() {
  return const AndroidNotificationDetails(channelId, channelName,
    channelDescription: channelDescription,
    importance: Importance.defaultImportance, priority: Priority.defaultPriority,
    autoCancel: true, playSound: false, icon: '@mipmap/ic_launcher');
}

AndroidNotificationDetails androidDownloadAlertSound() {
  return const AndroidNotificationDetails(channelId, channelName,
    channelDescription: channelDescription,
    importance: Importance.defaultImportance, priority: Priority.defaultPriority,
    autoCancel: true, playSound: true, icon: '@mipmap/ic_launcher');
}

AndroidNotificationDetails androidScanProgress({int progress = 0}) {
  return AndroidNotificationDetails(libraryChannelId, libraryChannelName,
    channelDescription: libraryChannelDescription, importance: Importance.low,
    priority: Priority.low, showProgress: true, maxProgress: 100,
    progress: progress, ongoing: true, autoCancel: false,
    playSound: false, enableVibration: false, onlyAlertOnce: true,
    icon: '@mipmap/ic_launcher');
}

AndroidNotificationDetails androidScanAlert() {
  return const AndroidNotificationDetails(libraryChannelId, libraryChannelName,
    channelDescription: libraryChannelDescription,
    importance: Importance.defaultImportance, priority: Priority.defaultPriority,
    autoCancel: true, playSound: false, icon: '@mipmap/ic_launcher');
}

const iosSilent = DarwinNotificationDetails(presentAlert: false, presentBadge: false, presentSound: false);
const iosAlert = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
const iosAlertNoSound = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: false);
