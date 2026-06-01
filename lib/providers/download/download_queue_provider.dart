import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitly/models/download_item.dart';
import 'package:bitly/models/settings/app_settings.dart';
import 'package:bitly/models/settings/settings_copy.dart';
import 'package:bitly/models/track.dart';
import 'package:bitly/providers/settings/settings_provider.dart';
import 'package:bitly/providers/extension/extension_provider.dart';
import 'package:bitly/providers/library/library_collections_provider.dart';
import 'package:bitly/providers/local_library/local_library_provider.dart';
import 'package:bitly/services/utilities/app_state/app_state_database.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/services/downloads/download_request_payload.dart';
import 'package:bitly/services/downloads/download_request_extension.dart';
import 'package:bitly/services/library/covers/downloaded_embedded_cover_resolver.dart';
import 'package:bitly/services/downloads/ffmpeg_service.dart';
import 'package:bitly/services/library/library_database.dart';
import 'package:bitly/services/notifications/notification_service.dart';
import 'package:bitly/services/notifications/download_notification.dart';
import 'package:bitly/services/history/history_database.dart';
import 'package:bitly/services/premium/premium_service.dart';
import 'package:bitly/utils/logger.dart' hide log;
import 'package:bitly/utils/file_access.dart';
import 'package:bitly/utils/string_utils.dart';
import 'package:bitly/utils/artist_utils.dart';
import 'package:bitly/utils/hard_delete_utils.dart';

export 'package:bitly/services/history/history_database.dart'
    show HistoryLookupRequest, HistoryBatchLookupRequest;

part 'queue_helpers_types.dart';
part 'download_history_notifier.dart';
part 'download_queue_notifier_core.dart';
part 'queue_notifier_extensions.dart';

final _log = AppLogger('DownloadQueue');
final _historyLog = AppLogger('DownloadHistory');

final _invalidFolderChars = RegExp(r'[<>:"/\\|?*]');
final _trimDotsAndSpacesRegex = RegExp(r'^[. ]+|[. ]+$');
final _trimUnderscoresAndSpacesRegex = RegExp(r'^[_ ]+|[_ ]+$');
final _multiWhitespaceRegex = RegExp(r'\s+');
final _multiUnderscoreRegex = RegExp(r'_+');