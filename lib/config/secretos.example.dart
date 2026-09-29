// ─────────────────────────────────────────────────────────────
// secretos.example.dart — TEMPLATE de credenciales para CI.
// Copia este archivo como secretos.dart y completa los valores
// reales. secretos.dart está en .gitignore, este template no.
// El workflow lo copia y reemplaza `tu_github_token_aqui` con el
// secret PREMIUM_GITHUB_TOKEN (Settings → Secrets).
// ⚠️ NUNCA poner valores reales acá (GitHub bloquea el push con
// protección de secretos) — solo placeholders.
// ─────────────────────────────────────────────────────────────

/// ⚠️ YA NO SE USA: dejar VACÍO.
///
/// Antes: token personal de GitHub con el que el backend Go leía y escribía
/// `codes.json` en el repo privado QuopTron/bitly_codes_premium. Como este valor
/// termina COMPILADO dentro del APK/exe —y los binarios se publican en un repo
/// público—, cualquiera lo sacaba con unzip + grep (y era un token clásico, con
/// acceso a TODOS los repos de la cuenta).
///
/// Ahora el registro de códigos lo hace tu Worker, que guarda la llave en su
/// propio entorno (secreto de Cloudflare) y nunca la manda a la app. Un valor
/// acá solo tiene sentido en builds de diagnóstico del dueño.
const String tokenGithub = '';

/// Google OAuth Client ID (tipo: Android) — usado en el flujo nativo de
/// Google Sign-In (Credential Manager) en Android.
const String oauthClienteIdAndroid =
    'tu_android_client_id_aqui.apps.googleusercontent.com';

/// Google OAuth Client ID (tipo: web) — serverClientId del flujo nativo.
const String oauthClienteIdPorDefecto =
    'tu_client_id_aqui.apps.googleusercontent.com';

/// Google OAuth Client Secret (corresponde al Web Client ID de arriba).
const String oauthClienteSecretoPorDefecto = 'GOCSPX-tu_secret_aqui';

/// Google OAuth Desktop Client ID (flujo de loopback en el navegador).
const String oauthClienteIdEscritorio =
    'tu_desktop_client_id_aqui.apps.googleusercontent.com';
const String oauthClienteSecretoEscritorio = 'GOCSPX-tu_desktop_secret_aqui';
