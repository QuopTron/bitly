// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'premium_dao.dart';

// ignore_for_file: type=lint
mixin _$PremiumDaoMixin on DatabaseAccessor<AppDatabase> {
  $UserPremiumTable get userPremium => attachedDatabase.userPremium;
  $QuotaUsageTable get quotaUsage => attachedDatabase.quotaUsage;
  $UserDailyPlaysTable get userDailyPlays => attachedDatabase.userDailyPlays;
  PremiumDaoManager get managers => PremiumDaoManager(this);
}

class PremiumDaoManager {
  final _$PremiumDaoMixin _db;
  PremiumDaoManager(this._db);
  $$UserPremiumTableTableManager get userPremium =>
      $$UserPremiumTableTableManager(_db.attachedDatabase, _db.userPremium);
  $$QuotaUsageTableTableManager get quotaUsage =>
      $$QuotaUsageTableTableManager(_db.attachedDatabase, _db.quotaUsage);
  $$UserDailyPlaysTableTableManager get userDailyPlays =>
      $$UserDailyPlaysTableTableManager(
        _db.attachedDatabase,
        _db.userDailyPlays,
      );
}
