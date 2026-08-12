import 'package:drift/drift.dart';

class UserPremium extends Table {
  TextColumn get id => text().customConstraint("NOT NULL DEFAULT 'default'")();
  TextColumn get tier => text().customConstraint("NOT NULL DEFAULT 'free' CHECK(tier IN ('free', 'premium', 'lifetime'))")();
  IntColumn get premiumUntil => integer().nullable()();
  IntColumn get dailyPlayLimit => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_quota_status', columns: {#status})
@TableIndex(name: 'idx_quota_user', columns: {#userId})
class QuotaUsage extends Table {
  TextColumn get userId => text()();
  TextColumn get trackId => text()();
  RealColumn get durationMinutes => real()();
  TextColumn get status => text().customConstraint("NOT NULL DEFAULT 'reserved'")();
  DateTimeColumn get downloadedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {userId, trackId, downloadedAt};
}

@TableIndex(name: 'idx_daily_plays_date', columns: {#date})
class UserDailyPlays extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text()();
  IntColumn get playCount => integer().nullable()();
}

