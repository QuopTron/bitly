// ---------------------------------------------------------------------------
// premium_dao.dart — DAO de premium: estado del usuario, cuota y reproducciones diarias. Se conecta con: app_database.dart + CachePremium. Parte del flujo: premium gate (descargas).
// ---------------------------------------------------------------------------

import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/premium_table.dart';

part 'premium_dao.g.dart';

@DriftAccessor(tables: [UserPremium, QuotaUsage, UserDailyPlays])
class PremiumDao extends DatabaseAccessor<AppDatabase> with _$PremiumDaoMixin {
  PremiumDao(super.db);

  Future<UserPremiumData?> getPremium() =>
      (select(userPremium)
        ..where((t) => t.id.equals('default'))).getSingleOrNull();

  Future<void> setTier(String tier, {int? premiumUntil}) =>
      into(userPremium).insert(
        UserPremiumCompanion(
          id: const Value('default'),
          tier: Value(tier),
          premiumUntil: Value(premiumUntil ?? 0),
          dailyPlayLimit: Value(tier == 'free' ? 50 : 999999),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
        mode: InsertMode.insertOrReplace,
      );

  // ── User Daily Plays ────────────────────────────────────────────

  Future<int> getDailyPlayCount(String date) async {
    // date has no unique constraint, so legacy duplicate rows are possible.
    // Sum instead of .single/.getSingleOrNull to avoid "Too many elements".
    final rows =
        await (select(userDailyPlays)..where((t) => t.date.equals(date))).get();
    var total = 0;
    for (final r in rows) {
      final c = r.playCount;
      if (c != null) total += c;
    }
    return total;
  }

  Future<void> incrementDailyPlayCount(String date) async {
    final existing =
        await (select(userDailyPlays)..where((t) => t.date.equals(date))).get();
    if (existing.isEmpty) {
      await into(userDailyPlays).insert(
        UserDailyPlaysCompanion(date: Value(date), playCount: const Value(1)),
      );
      return;
    }
    // Update the existing row (first) so we never insert a duplicate for the
    // same date. New plays no longer create the rows that broke .single.
    await (update(userDailyPlays)..where((t) => t.date.equals(date))).write(
      UserDailyPlaysCompanion(playCount: Value(existing.first.playCount! + 1)),
    );
  }
}
