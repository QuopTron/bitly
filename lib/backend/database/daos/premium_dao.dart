import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/premium_table.dart';
import '../tables/secrets_table.dart';

part 'premium_dao.g.dart';

@DriftAccessor(tables: [UserPremium, QuotaUsage, UserDailyPlays, SecretCounters, SecretUnlocks])
class PremiumDao extends DatabaseAccessor<AppDatabase> with _$PremiumDaoMixin {
  PremiumDao(super.db);

  Future<UserPremiumData?> getPremium() =>
      (select(userPremium)..where((t) => t.id.equals('default'))).getSingleOrNull();

  Future<void> setTier(String tier, {int? premiumUntil}) =>
      into(userPremium).insert(UserPremiumCompanion(
        id: const Value('default'),
        tier: Value(tier),
        premiumUntil: Value(premiumUntil ?? 0),
        dailyPlayLimit: Value(tier == 'free' ? 50 : 999999),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ), mode: InsertMode.insertOrReplace);

  Future<int> getCounter(String key) async {
    final row = await (select(secretCounters)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value ?? 0;
  }

  Future<void> incrementCounter(String key) =>
      into(secretCounters).insert(SecretCountersCompanion(
        key: Value(key),
        value: const Value(1),
      ), mode: InsertMode.insertOrReplace);

  Future<void> unlockSecret(String key) =>
      into(secretUnlocks).insert(SecretUnlocksCompanion(
        key: Value(key),
        unlockedAt: Value(DateTime.now()),
      ), mode: InsertMode.insertOrIgnore);

  Future<bool> isSecretUnlocked(String key) =>
      (select(secretUnlocks)..where((t) => t.key.equals(key)))
          .getSingleOrNull()
          .then((r) => r != null);

  Future<List<String>> getUnlockedSecrets() =>
      select(secretUnlocks).get().then((r) => r.map((e) => e.key).toList());

  // ── User Daily Plays ────────────────────────────────────────────

  Future<int> getDailyPlayCount(String date) async {
    // date has no unique constraint, so legacy duplicate rows are possible.
    // Sum instead of .single/.getSingleOrNull to avoid "Too many elements".
    final rows = await (select(userDailyPlays)..where((t) => t.date.equals(date))).get();
    var total = 0;
    for (final r in rows) {
      final c = r.playCount;
      if (c != null) total += c;
    }
    return total;
  }

  Future<void> incrementDailyPlayCount(String date) async {
    final existing = await (select(userDailyPlays)..where((t) => t.date.equals(date))).get();
    if (existing.isEmpty) {
      await into(userDailyPlays).insert(UserDailyPlaysCompanion(
        date: Value(date),
        playCount: const Value(1),
      ));
      return;
    }
    // Update the existing row (first) so we never insert a duplicate for the
    // same date. New plays no longer create the rows that broke .single.
    await (update(userDailyPlays)..where((t) => t.date.equals(date))).write(
      UserDailyPlaysCompanion(playCount: Value(existing.first.playCount! + 1)),
    );
  }
}

