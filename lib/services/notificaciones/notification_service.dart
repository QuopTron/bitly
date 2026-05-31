/// Servicio singleton de notificaciones locales.
/// Gestiona la inicialización de [FlutterLocalNotificationsPlugin], permisos
/// iOS, canales Android y el método seguro de mostrar notificaciones.
/// Las notificaciones de descarga están en [NotificationDownloadExt],
/// las de escaneo en [NotificationLibraryExt] y las de actualización
/// en [NotificationUpdateExt].
library;

export 'package:bitly/services/notificaciones/notification_constants.dart';
export 'package:bitly/services/notificaciones/notificacion_descarga.dart';
export 'package:bitly/services/notificaciones/notificacion_biblioteca.dart';
export 'package:bitly/services/notificaciones/notificacion_actualizacion.dart';

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:bitly/l10n/app_localizations.dart';
import 'package:bitly/services/notificaciones/notification_constants.dart';
import 'package:bitly/services/núcleo/base_service.dart';

class NotificationService extends BaseService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _notificationPermissionRequested = false;
  AppLocalizations? _l10n;

  AppLocalizations? get l10n => _l10n;

  void updateStrings(AppLocalizations l10n) { _l10n = l10n; }

  @override
  @override
  Future<void> onInitialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false);
    await _notifications.initialize(settings: const InitializationSettings(android: androidSettings, iOS: iosSettings));
    if (Platform.isAndroid) {
      final androidImpl = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.low,
        showBadge: false,
        playSound: false,
        enableVibration: false,
      ));
      await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
        libraryChannelId,
        libraryChannelName,
        description: libraryChannelDescription,
        importance: Importance.low,
        showBadge: false,
        playSound: false,
        enableVibration: false,
      ));
    }
  }

   Future<bool> ensureNotificationPermission() async {
    return safeExecute(() async {
      if (!Platform.isIOS) return true;
      final status = await Permission.notification.status;
      if (status.isGranted || status.isProvisional) return true;
      if (_notificationPermissionRequested || status.isPermanentlyDenied || status.isRestricted) return false;
      _notificationPermissionRequested = true;
      final requested = await Permission.notification.request();
      return requested.isGranted || requested.isProvisional;
    }, operationName: 'ensureNotificationPermission');
  }

  Future<void> showSafely({required int id, required String title, required String body, required NotificationDetails details}) async {
    await safeExecute(() async {
      if (!await ensureNotificationPermission()) return;
      try {
        await _notifications.show(id: id, title: title, body: body, notificationDetails: details);
      } on PlatformException catch (e) {
        if (Platform.isIOS && (e.code == 'Error 1' || (e.message?.contains('UNErrorDomain error 1') ?? false) || e.toString().contains('UNErrorDomain error 1'))) {
          debugPrint('iOS notifications not allowed; skipping local notification');
          return;
        }
        rethrow;
      }
    }, operationName: 'showSafely');
  }

  Future<void> cancelNotification(int id) async {
    await safeExecute(() => _notifications.cancel(id: id),
      operationName: 'cancelNotification');
  }

  @override
  @override
  Future<void> onDispose() async {
    // Clean up notification resources if needed
  }

  @override
  Future<ServiceHealth> onCheckHealth() async {
    if (!isInitialized) {
      return ServiceHealth.degraded('Notification service not initialized');
    }
    return ServiceHealth.healthy('Notification service healthy');
  }

  String get embeddingMetadataLabel => _l10n?.notifEmbeddingMetadata ?? 'Embedding metadata...';
}
