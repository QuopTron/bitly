// ─────────────────────────────────────────────────────────────
// secretos.example.dart — TEMPLATE de credenciales para CI.
// Copia este archivo como secretos.dart y completa los valores
// reales. secretos.dart está en .gitignore, este template no.
// El workflow lo copia y reemplaza `tu_github_token_aqui` con el
// secret PREMIUM_GITHUB_TOKEN (Settings → Secrets).
// ⚠️ NUNCA poner valores reales acá (GitHub bloquea el push con
// protección de secretos) — solo placeholders.
// ─────────────────────────────────────────────────────────────

/// Token personal de GitHub usado por el backend Go (internal/premium)
/// para validar códigos premium contra el repo QuopTron/bitly_codes_premium.
const String tokenGithub = 'tu_github_token_aqui';

/// Google OAuth Client ID (tipo: Android) — usado en el flujo nativo de
/// Google Sign-In (Credential Manager) en Android.
const String oauthClienteIdAndroid = 'tu_android_client_id_aqui.apps.googleusercontent.com';

/// Google OAuth Client ID (tipo: web) — serverClientId del flujo nativo.
const String oauthClienteIdPorDefecto = 'tu_client_id_aqui.apps.googleusercontent.com';

/// Google OAuth Client Secret (corresponde al Web Client ID de arriba).
const String oauthClienteSecretoPorDefecto = 'GOCSPX-tu_secret_aqui';

/// Google OAuth Desktop Client ID (flujo de loopback en el navegador).
const String oauthClienteIdEscritorio = 'tu_desktop_client_id_aqui.apps.googleusercontent.com';
const String oauthClienteSecretoEscritorio = 'GOCSPX-tu_desktop_secret_aqui';