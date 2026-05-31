import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/services/statistics/stats_database.dart';

final statsProvider = Provider<StatsDatabase>((ref) {
  return StatsDatabase.instance;
});

final totalStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return StatsDatabase.instance.getTotalStats();
});

final topTracksProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return StatsDatabase.instance.getTopTracks();
});

final topAlbumsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return StatsDatabase.instance.getTopAlbums();
});

final topArtistsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return StatsDatabase.instance.getTopArtists();
});

final recentPlaysProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return StatsDatabase.instance.getRecentPlays();
});

final achievementProgressProvider = FutureProvider<Map<String, int>>((ref) async {
  return StatsDatabase.instance.getAchievementProgress();
});

final unlockedSecretsProvider = FutureProvider<Set<String>>((ref) async {
  return <String>{}; // StatsSecrets functionality removed
});
