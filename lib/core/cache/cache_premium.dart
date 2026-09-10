// ─────────────────────────────────────────────────────────────
// cache_premium.dart — Caché local del estado premium (wrapper
// sobre PremiumDao): activación de código y lectura del estado.
// Se conecta con: base_datos (PremiumDao) + backend Go (sync).
// Parte del flujo: premium gate (descargas), arranque y setup.
// ─────────────────────────────────────────────────────────────

import 'package:logger/logger.dart';

import '../base_datos/app_database.dart';
import '../base_datos/daos/premium_dao.dart';
import '../modelos/estado_premium.dart';

final _log = Logger();

/// Caché local de suscripción premium — wrappers sobre [PremiumDao].
class CachePremium {
  final PremiumDao _dao;
  CachePremium(AppDatabase db) : _dao = PremiumDao(db);

  Future<void> activarPremium(String code) async {
    await _dao.setTier('premium', premiumUntil:
        DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/ 1000);
    _log.i('[CachePremium] Premium activado con código ${code.substring(0, code.length.clamp(0, 30))}');
  }

  Future<EstadoPremium> getEstadoPremium() async {
    final p = await _dao.getPremium();
    if (p == null) {
      _log.i('[CachePremium] Sin fila en DB → free (inactivo)');
      return const EstadoPremium(tier: 'free', premiumHasta: 0, activo: false);
    }
    final ahora = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final activo = p.tier != 'free' && (p.premiumUntil == null || ahora < p.premiumUntil!);
    _log.i('[CachePremium] tier=${p.tier} premiumHasta=${p.premiumUntil} ahora=$ahora activo=$activo');
    return EstadoPremium(tier: p.tier, premiumHasta: p.premiumUntil ?? 0, activo: activo);
  }
}