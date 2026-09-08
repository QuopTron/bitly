// ⚠️ SECRETS TEMPLATE
// Copia este archivo como secrets.dart y completa los valores reales.
// secrets.dart está en .gitignore, secrets.example.dart no.

/// GitHub personal access token used by the Go backend (internal/premium)
/// to validate premium codes against the QuopTron/bitly_codes_premium
/// repository. Se envía al backend al iniciar (setPremiumGithubToken).
const String githubToken = 'tu_github_token_aqui';

/// Google OAuth Client ID (type: Android) — used by the native Google
/// Sign-In (Credential Manager) flow on Android.
const String androidOAuthClientId = 'tu_android_client_id_aqui.apps.googleusercontent.com';

/// Google OAuth Client ID (type: web).
/// Used as `serverClientId` for the native Google Sign-In (Credential
/// Manager) flow on Android.
const String defaultOAuthClientId = 'tu_client_id_aqui.apps.googleusercontent.com';

/// Google OAuth Client Secret (corresponds to the Web Client ID above).
const String defaultOAuthClientSecret = 'GOCSPX-tu_secret_aqui';

/// Google OAuth Desktop Client ID (for browser loopback flow).
/// Desktop clients auto-allow http://127.0.0.1 redirects.
const String desktopOAuthClientId = 'tu_desktop_client_id_aqui.apps.googleusercontent.com';
const String desktopOAuthClientSecret = 'GOCSPX-tu_desktop_secret_aqui';
