class SetupData {
  final String locale;
  final String mode;
  final String username;
  final bool setupCompleted;
  final String? premiumCode;
  final String? trialStartedAt;
  final String? trialExpiresAt;
  final bool trialUsed;
  final String? themeMode;

  const SetupData({
    required this.locale,
    required this.mode,
    this.username = '',
    this.setupCompleted = false,
    this.premiumCode,
    this.trialStartedAt,
    this.trialExpiresAt,
    this.trialUsed = false,
    this.themeMode,
  });

  factory SetupData.fromJson(Map<String, dynamic> json) {
    return SetupData(
      locale: json['locale'] as String? ?? 'es',
      mode: json['mode'] as String? ?? 'free',
      username: json['username'] as String? ?? '',
      setupCompleted: json['setup_completed'] as bool? ?? false,
      premiumCode: json['premium_code'] as String?,
      trialStartedAt: json['trial_started_at'] as String?,
      trialExpiresAt: json['trial_expires_at'] as String?,
      trialUsed: json['trial_used'] as bool? ?? false,
      themeMode: json['theme_mode'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'locale': locale,
    'mode': mode,
    'username': username,
    'setup_completed': setupCompleted,
    if (premiumCode != null) 'premium_code': premiumCode,
    if (trialStartedAt != null) 'trial_started_at': trialStartedAt,
    if (trialExpiresAt != null) 'trial_expires_at': trialExpiresAt,
    'trial_used': trialUsed,
    if (themeMode != null) 'theme_mode': themeMode,
  };

  bool get isTrialExpired {
    if (mode != 'free' || trialExpiresAt == null) return false;
    final expiresAt = DateTime.tryParse(trialExpiresAt!);
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt);
  }
}
