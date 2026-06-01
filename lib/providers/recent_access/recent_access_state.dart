import 'package:bitly/providers/recent_access/recent_access_service.dart';

class RecentAccessState {
  final List<RecentAccessItem> items;
  final Set<String> hiddenDownloadIds;
  final bool isLoaded;

  const RecentAccessState({
    this.items = const [],
    this.hiddenDownloadIds = const {},
    this.isLoaded = false,
  });

  RecentAccessState copyWith({
    List<RecentAccessItem>? items,
    Set<String>? hiddenDownloadIds,
    bool? isLoaded,
  }) {
    return RecentAccessState(
      items: items ?? this.items,
      hiddenDownloadIds: hiddenDownloadIds ?? this.hiddenDownloadIds,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}
