// ─────────────────────────────────────────────────────────────
// datos_setup.dart — Datos de configuración inicial del usuario
// (locale, modo, usuario, premium, trial, tema) persistidos en drift.
// Se conecta con: SettingsCache (drift) + backend Go (syncBackendConfig).
// Parte del flujo: setup (primera configuración) y arranque.
// ─────────────────────────────────────────────────────────────

class DatosSetup {
  final String locale;
  final String mode;
  final String username;
  final bool setupCompletado;
  final String? codigoPremium;
  final String? trialIniciadoEn;
  final String? trialExpiraEn;
  final bool trialUsado;
  final String? temaMode;

  const DatosSetup({
    required this.locale,
    required this.mode,
    this.username = '',
    this.setupCompletado = false,
    this.codigoPremium,
    this.trialIniciadoEn,
    this.trialExpiraEn,
    this.trialUsado = false,
    this.temaMode,
  });

  factory DatosSetup.desdeJson(Map<String, dynamic> json) {
    return DatosSetup(
      locale: json['locale'] as String? ?? 'es',
      mode: json['mode'] as String? ?? 'free',
      username: json['username'] as String? ?? '',
      setupCompletado: json['setup_completed'] as bool? ?? false,
      codigoPremium: json['premium_code'] as String?,
      trialIniciadoEn: json['trial_started_at'] as String?,
      trialExpiraEn: json['trial_expires_at'] as String?,
      trialUsado: json['trial_used'] as bool? ?? false,
      temaMode: json['theme_mode'] as String?,
    );
  }

  Map<String, dynamic> aJson() => {
    'locale': locale,
    'mode': mode,
    'username': username,
    'setup_completado': setupCompletado,
    if (codigoPremium != null) 'premium_code': codigoPremium,
    if (trialIniciadoEn != null) 'trial_started_at': trialIniciadoEn,
    if (trialExpiraEn != null) 'trial_expires_at': trialExpiraEn,
    'trial_used': trialUsado,
    if (temaMode != null) 'theme_mode': temaMode,
  };

  bool get trialExpirado {
    if (mode != 'free' || trialExpiraEn == null) return false;
    final expira = DateTime.tryParse(trialExpiraEn!);
    if (expira == null) return false;
    return DateTime.now().isAfter(expira);
  }
}