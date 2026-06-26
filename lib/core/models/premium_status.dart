class PremiumStatus {
  final String tier;
  final int premiumUntil;
  final bool activo;

  const PremiumStatus({
    required this.tier,
    required this.premiumUntil,
    required this.activo,
  });

  factory PremiumStatus.fromJson(Map<String, dynamic> json) {
    return PremiumStatus(
      tier: json['tier'] as String? ?? 'free',
      premiumUntil: json['premiumUntil'] as int? ?? 0,
      activo: json['activo'] as bool? ?? false,
    );
  }

  bool get isPremium => tier != 'free' && activo;
}
