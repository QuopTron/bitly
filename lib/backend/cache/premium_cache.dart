import 'package:logger/logger.dart';
import '../database/app_database.dart';
import '../database/daos/premium_dao.dart';
import '../../frontend/shared/models/premium_status.dart';

final _log = Logger();

/// Premium subscription local cache — wrappers over [PremiumDao].
class PremiumCache {
  final PremiumDao _pm;
  PremiumCache(AppDatabase db) : _pm = PremiumDao(db);

  Future<void> activatePremium(String code) async {
    await _pm.setTier('premium', premiumUntil:
        DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/ 1000);
    _log.i('[PremiumCache] Premium activated with code ${code.substring(0, code.length.clamp(0, 30))}');
  }

  Future<PremiumStatus> getPremiumStatus() async {
    final p = await _pm.getPremium();
    if (p == null) {
      _log.i('[PremiumCache] No DB row → free (inactivo)');
      return const PremiumStatus(tier: 'free', premiumUntil: 0, activo: false);
    }
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final activo = p.tier != 'free' && (p.premiumUntil == null || now < p.premiumUntil!);
    _log.i('[PremiumCache] tier=${p.tier} premiumUntil=${p.premiumUntil} now=$now activo=$activo');
    return PremiumStatus(tier: p.tier, premiumUntil: p.premiumUntil ?? 0, activo: activo);
  }
}


