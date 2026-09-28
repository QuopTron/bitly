# ── Reglas de R8 para el release ───────────────────────────────────────────
# Con `isMinifyEnabled = true` (ver build.gradle.kts) R8 renombra y tira todo lo
# que "no se usa". Lo que se usa por REFLEXIÓN o desde C no se ve en el código
# Java, así que hay que conservarlo a mano o la app queda clavada en el splash.
# Cada bloque dice QUÉ se rompe si se saca.

# ── JNI (lo más importante) ────────────────────────────────────────────────
# Los métodos `native` se buscan por NOMBRE y FIRMA desde las .so (el puente del
# backend Go, media_kit, ffmpeg-kit). Si R8 los renombra, la .so no encuentra su
# función y la app muere al inicializar.
-keepclasseswithmembernames class * { native <methods>; }

# Metadatos que la reflexión necesita para leer clases y anotaciones.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod

# ── Puentes propios ────────────────────────────────────────────────────────
# Backend Go (bitly.aar): el .aar llama a Java por reflexión.
-keep class gobackend.** { *; }
-dontwarn gobackend.**

# ── Player y conversión de audio ───────────────────────────────────────────
# media_kit (mpv) y ffmpeg-kit resuelven sus clases por JNI.
-keep class com.media_kit.** { *; }
-dontwarn com.media_kit.**
# Ojo con el nombre del paquete: esta app usa `ffmpeg_kit_flutter_new_audio`,
# el FORK, cuyo paquete es com.antonkarpenko.ffmpegkit (no com.arthenica, el
# original). Si se deja sólo el nombre viejo, las reglas no cubren nada y el
# que rompe es justo el camino que convierte/descifra audio.
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-dontwarn com.antonkarpenko.ffmpegkit.**
-keep class com.arthenica.ffmpegkit.** { *; }
-dontwarn com.arthenica.ffmpegkit.**

# ── Escáner de QR (ML Kit) ─────────────────────────────────────────────────
# mobile_scanner arma el pipeline de ML Kit por reflexión (Task API).
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.odml.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.odml.**

# Protocol Buffers: el parser de los modelos .tflite se genera por reflexión.
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# ── Servicios que se registran solos ───────────────────────────────────────
# audio_service publica un MediaBrowserService (Android lo instancia por nombre).
-keep class com.ryanheise.audioservice.** { *; }
-dontwarn com.ryanheise.audioservice.**

# WebView (verificación de Cloudflare).
-keep class io.flutter.plugins.webviewflutter.** { *; }
-dontwarn io.flutter.plugins.webviewflutter.**

# ── Flutter ────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
-keep class io.flutter.plugins.** { *; }

# ── Enganchado por nombre desde el manifest (no desde el código) ───────────
# Activities/Services/Providers declarados en AndroidManifest.xml se instancian
# por nombre: sin esto, achicar el APK borra la MainActivity.
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
