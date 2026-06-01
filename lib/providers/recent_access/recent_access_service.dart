import 'dart:async';
import 'dart:convert';
import 'package:bitly/services/utilities/app_state/recent_access.dart';

const _maxRecentItems = 20;

enum RecentAccessType { artist, album, track, playlist }

class RecentAccessItem {
  final String id;
  final String name;
  final String? subtitle;
  final String? imageUrl;
  final RecentAccessType type;
  final DateTime accessedAt;
  final String? providerId;

  const RecentAccessItem({
    required this.id,
    required this.name,
    this.subtitle,
    this.imageUrl,
    required this.type,
    required this.accessedAt,
    this.providerId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'subtitle': subtitle,
    'imageUrl': imageUrl,
    'type': type.name,
    'accessedAt': accessedAt.toIso8601String(),
    'providerId': providerId,
  };

  factory RecentAccessItem.fromJson(Map<String, dynamic> json) {
    return RecentAccessItem(
      id: json['id'] as String,
      name: json['name'] as String,
      subtitle: json['subtitle'] as String?,
      imageUrl: json['imageUrl'] as String?,
      type: RecentAccessType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => RecentAccessType.track,
      ),
      accessedAt: DateTime.parse(json['accessedAt'] as String),
      providerId: json['providerId'] as String?,
    );
  }

  String get uniqueKey => '${type.name}:${providerId ?? 'default'}:$id';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentAccessItem &&
          runtimeType == other.runtimeType &&
          uniqueKey == other.uniqueKey;

  @override
  int get hashCode => uniqueKey.hashCode;
}

class RecentAccessService {
  final AppStateRecentAccess _appStateDb = AppStateRecentAccess.instance;

  Future<List<RecentAccessItem>> loadHistory() async {
    final rows = await _appStateDb.getRecentAccessRows(limit: _maxRecentItems);
    final items = <RecentAccessItem>[];
    for (final row in rows) {
      final itemJson = row['item_json'] as String?;
      if (itemJson == null || itemJson.isEmpty) continue;
      try {
        final decoded = jsonDecode(itemJson);
        if (decoded is! Map) continue;
        items.add(
          RecentAccessItem.fromJson(Map<String, dynamic>.from(decoded)),
        );
      } catch (_) {
        continue;
      }
    }
    return items;
  }

  Future<Set<String>> loadHiddenDownloadIds() async {
    return Set<String>.from(
      await _appStateDb.getHiddenRecentDownloadIds(),
    );
  }

  Future<void> saveAccess(RecentAccessItem item) async {
    await _appStateDb.upsertRecentAccessRow(
      uniqueKey: item.uniqueKey,
      itemJson: jsonEncode(item.toJson()),
      accessedAt: item.accessedAt.toIso8601String(),
    );
  }

  Future<void> deleteAccess(String uniqueKey) async {
    await _appStateDb.deleteRecentAccessRow(uniqueKey);
  }

  Future<void> hideDownload(String downloadId) async {
    await _appStateDb.addHiddenRecentDownloadId(downloadId);
  }

  bool isDownloadHidden(String downloadId, Set<String> hiddenIds) {
    return hiddenIds.contains(downloadId);
  }

  Future<void> clearHistory() async {
    await _appStateDb.clearRecentAccessRows();
  }

  Future<void> clearHiddenDownloads() async {
    await _appStateDb.clearHiddenRecentDownloadIds();
  }
}