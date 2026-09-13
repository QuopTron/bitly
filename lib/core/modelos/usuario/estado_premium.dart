// ─────────────────────────────────────────────────────────────
// estado_premium.dart — Estado premium del usuario (tier, vigencia
// y flag activo) tal como lo guarda la app.
// Se conecta con: PremiumCache (drift) + backend Go (syncPremiumStatus).
// Parte del flujo: premium gate (descargas) y Mi Espacio.
// ─────────────────────────────────────────────────────────────

class EstadoPremium {
  final String tier;
  final int premiumHasta;
  final bool activo;

  const EstadoPremium({
    required this.tier,
    required this.premiumHasta,
    required this.activo,
  });

  factory EstadoPremium.desdeJson(Map<String, dynamic> json) {
    return EstadoPremium(
      tier: json['tier'] as String? ?? 'free',
      premiumHasta: json['premiumUntil'] as int? ?? 0,
      activo: json['activo'] as bool? ?? false,
    );
  }

  bool get esPremium => tier != 'free' && activo;
}