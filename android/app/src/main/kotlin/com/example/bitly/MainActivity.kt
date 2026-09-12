package com.example.bitly

import android.app.Activity
import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import gobackend.Gobackend
import java.io.File
import java.util.concurrent.Executors

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.bitly/backend"
    private val SESSION_CHANNEL = "com.bitly/session_grant"
    private val OAUTH_CHANNEL = "com.bitly/oauth_callback"
    // Enlaces de música: texto compartido desde Spotify/YouTube (ACTION_SEND)
    // y deep links bitly://open?url=... con el enlace completo de la fuente.
    private val SHARE_CHANNEL = "com.bitly/share_intent"
    private val DEEPLINK_CHANNEL = "com.bitly/deep_link"
    // Plataforma: si corremos en TV lo decide el SISTEMA (uiMode + leanback),
    // no el ancho en píxeles — una TV de 720p reporta poco ancho y un proxy
    // por tamaño la confundiría con un celular.
    private val PLATAFORMA_CHANNEL = "com.bitly/plataforma"
    // Go calls run on a pool (NOT a single thread): if one Go call gets stuck
    // in a JS call that never returns, the rest of the app must keep working.
    // Each call also has a hard timeout (see dispatchGoCall) so the Dart side
    // always gets a response instead of hanging forever.
    //
    // El tamaño se ADAPTA a los núcleos del equipo (4-8): en telefonos de 8
    // nucleos, un pool fijo de 4 serializaba busquedas/descargas/resolucion de
    // streams detras de 4 llamadas lentas y el resto de la app parecia colgada.
    // El tope de 8 mantiene el uso de RAM acotado (cada llamada de Go puede
    // abrir un motor JS de extension).
    private val executor = Executors.newFixedThreadPool(
        Runtime.getRuntime().availableProcessors().coerceIn(4, 8),
    )
    // Dedicated watcher thread: waits on the Go-call Future with a timeout so
    // a stuck call never consumes a pool thread as a waiter.
    private val callWatcher = Executors.newSingleThreadExecutor()
    // Hard per-call timeout for Go RPCs. Legit fallback downloads can take
    // ~30-40s, so this is a safety net, not the normal path.
    private val callTimeoutSeconds = 45L
    private val handler = Handler(Looper.getMainLooper())

    private var safResult: MethodChannel.Result? = null
    private val SAF_PICKER_REQUEST_CODE = 1001

    // Go backend init guard: initBackend + initGlobalState are NOT re-entrant.
    // The splash's auto-retry can fire a second initGoBackend while the first
    // is still loading (cold start loads the Go runtime + every extension JS
    // engine, which takes tens of seconds), and concurrent calls into Go init
    // can throw or deadlock — making every retry fail and showing "Backend no
    // responde" even though a single sequential init would have succeeded.
    // A shared CompletableFuture serializes init: the first caller runs it,
    // every concurrent/retry caller awaits the SAME future (never re-entering
    // Go init), and the result is cached for the process lifetime.
    private val goBackendInitLock = Any()
    private var goBackendInitFuture: java.util.concurrent.CompletableFuture<String?>? = null

    // Grant received from a spotiflac://session-grant deep link while Flutter
    // was not ready yet (cold start). Delivered once the engine is configured.
    private var pendingSessionGrant: String? = null

    // OAuth callback received from a spotiflac://callback deep link (e.g. the
    // future Spotify PKCE flow) before Flutter was ready (cold start).
    private var pendingOAuth: OAuthResult? = null

    // Texto/enlace que llegó por share intent o deep link antes de que Flutter
    // estuviera listo (arranque en frío con "Compartir a Bitly").
    private var pendingSharedText: String? = null
    private var pendingDeepLink: String? = null
    // true después de configureFlutterEngine: distingue el evento en frío (lo
    // entrega Dart pidiendo el pendiente) del que llega con la app abierta.
    private var flutterReady = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleDeepLinkIntent(intent)
        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleDeepLinkIntent(intent)
        handleShareIntent(intent)
    }

    /**
     * Captures "Compartir → Bitly" (ACTION_SEND de texto) y entrega el texto a
     * Flutter por el canal de share intent. De ahí sale el enlace de música
     * que el backend Go resuelve (Spotify, YouTube, Deezer...).
     */
    private fun handleShareIntent(intent: Intent?) {
        if (intent == null) return
        if (intent.action != Intent.ACTION_SEND) return
        val texto = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return
        if (texto.isEmpty()) return
        intent.removeExtra(Intent.EXTRA_TEXT)
        pendingSharedText = texto
        // Con la app ya abierta se entrega en el momento; en frío queda
        // pendiente y Dart lo pide con getInitialSharedText (así no se entrega
        // dos veces).
        if (flutterReady) forwardSharedText(texto)
    }

    /**
     * Enlaces de música abiertos por deep link (bitly://open?url=https://...).
     * Se entregan a Flutter para resolverlos y reproducirlos.
     */
    private fun handleOpenDeepLink(intent: Intent, uri: android.net.Uri) {
        val enlace = uri.getQueryParameter("url") ?: ""
        if (enlace.isEmpty()) return
        intent.data = null
        pendingDeepLink = enlace
        if (flutterReady) forwardDeepLink(enlace)
    }

    /**
     * Dispatches deep links to the matching handler by scheme/host.
     *
     * - `spotiflac://session-grant` → signed-session (Cloudflare) grant
     * - `spotiflac://callback`     → extension OAuth (PKCE) callback
     * - `bitly://open?url=...`     → enlace de música compartido
     */
    private fun handleDeepLinkIntent(intent: Intent?) {
        if (intent == null) return
        val uri = intent.data ?: return
        when {
            uri.scheme.equals("spotiflac", ignoreCase = true) -> when (uri.host?.lowercase()) {
                "session-grant" -> handleSessionGrant(intent, uri)
                "callback" -> handleOAuthCallback(intent, uri)
            }
            uri.scheme.equals("bitly", ignoreCase = true) &&
                uri.host.equals("open", ignoreCase = true) -> handleOpenDeepLink(intent, uri)
        }
    }

    /**
     * Captures the signed-session grant from the Cloudflare challenge callback
     * (spotiflac://session-grant?cb_version=v2grant&grant=gr_...) and delivers it
     * to Flutter via the session-grant MethodChannel.
     */
    private fun handleSessionGrant(intent: Intent, uri: android.net.Uri) {
        val grant = uri.getQueryParameter("grant") ?: uri.getQueryParameter("code") ?: ""
        if (grant.isEmpty()) return
        intent.data = null
        pendingSessionGrant = grant
        forwardSessionGrant(grant)
    }

    /**
     * Captures an extension OAuth (PKCE) callback
     * (spotiflac://callback?code=...&state=... or ?error=...&state=...) and
     * delivers it to Flutter via the OAuth MethodChannel.
     */
    private fun handleOAuthCallback(intent: Intent, uri: android.net.Uri) {
        val result = OAuthResult(
            code = uri.getQueryParameter("code") ?: "",
            state = uri.getQueryParameter("state") ?: "",
            error = uri.getQueryParameter("error") ?: "",
        )
        if (result.code.isEmpty() && result.error.isEmpty()) return
        intent.data = null
        pendingOAuth = result
        forwardOAuthCallback(result)
    }

    /** OAuth PKCE callback payload captured from the spotiflac://callback deep link. */
    private data class OAuthResult(
        val code: String,
        val state: String,
        val error: String,
    )

    private fun forwardSessionGrant(grant: String) {
        try {
            val engine = flutterEngine
            if (engine != null) {
                MethodChannel(engine.dartExecutor.binaryMessenger, SESSION_CHANNEL)
                    .invokeMethod("onSessionGrant", grant, null)
                android.util.Log.i("NativeBridge", "Session grant forwarded to Flutter")
            }
        } catch (e: Exception) {
            android.util.Log.e("NativeBridge", "forwardSessionGrant error: ${e.message}")
        }
    }

    private fun forwardSharedText(texto: String) {
        try {
            val engine = flutterEngine
            if (engine != null) {
                MethodChannel(engine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
                    .invokeMethod("onSharedText", texto, null)
                android.util.Log.i("NativeBridge", "Shared text forwarded to Flutter")
            }
        } catch (e: Exception) {
            android.util.Log.e("NativeBridge", "forwardSharedText error: ${e.message}")
        }
    }

    private fun forwardDeepLink(enlace: String) {
        try {
            val engine = flutterEngine
            if (engine != null) {
                MethodChannel(engine.dartExecutor.binaryMessenger, DEEPLINK_CHANNEL)
                    .invokeMethod("onDeepLink", enlace, null)
                android.util.Log.i("NativeBridge", "Deep link forwarded to Flutter")
            }
        } catch (e: Exception) {
            android.util.Log.e("NativeBridge", "forwardDeepLink error: ${e.message}")
        }
    }

    private fun forwardOAuthCallback(result: OAuthResult) {
        try {
            val engine = flutterEngine
            if (engine != null) {
                val payload = hashMapOf(
                    "code" to result.code,
                    "state" to result.state,
                    "error" to result.error,
                )
                MethodChannel(engine.dartExecutor.binaryMessenger, OAUTH_CHANNEL)
                    .invokeMethod("onOAuthCallback", payload, null)
                android.util.Log.i("NativeBridge", "OAuth callback forwarded to Flutter")
            }
        } catch (e: Exception) {
            android.util.Log.e("NativeBridge", "forwardOAuthCallback error: ${e.message}")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        android.util.Log.i("NativeBridge", "FlutterEngine configured.")

        // Deliver a grant that arrived before Flutter was ready (cold start).
        pendingSessionGrant?.let {
            handler.postDelayed({ forwardSessionGrant(it); pendingSessionGrant = null }, 500)
        }
        pendingOAuth?.let {
            handler.postDelayed({ forwardOAuthCallback(it); pendingOAuth = null }, 500)
        }

        // Share intent: Flutter pregunta al arrancar si había un texto pendiente
        // (app abierta en frío con "Compartir a Bitly"). Se entrega una sola vez.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialSharedText" -> {
                        val texto = pendingSharedText ?: ""
                        pendingSharedText = null
                        result.success(texto)
                    }
                    else -> result.notImplemented()
                }
            }

        // Deep link: mismo contrato para el enlace inicial (bitly://open?url=...).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEEPLINK_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialDeepLink" -> {
                        val enlace = pendingDeepLink ?: ""
                        pendingDeepLink = null
                        result.success(enlace)
                    }
                    else -> result.notImplemented()
                }
            }

        // A partir de acá, los intents que lleguen se entregan al vuelo.
        // Plataforma: responde si el sistema es un televisor. Dart lo consulta
        // una sola vez al arrancar (lib/shared/utilidades/deteccion_tv.dart) para
        // elegir el layout de escritorio en TV.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLATAFORMA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "esTv" -> result.success(esTelevisor())
                    else -> result.notImplemented()
                }
            }

        flutterReady = true

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // ── Init ──────────────────────────────────────────────────
                "initGoBackend" -> {
                    executor.execute {
                        val future: java.util.concurrent.CompletableFuture<String?>
                        synchronized(goBackendInitLock) {
                            if (goBackendInitFuture == null) {
                                val f = java.util.concurrent.CompletableFuture<String?>()
                                goBackendInitFuture = f
                                // Kick the actual init on a separate pool thread
                                // so the first caller does not hold the executor
                                // thread blocked on its own future.
                                executor.execute {
                                    try {
                                        // Point the Go backend at the app's
                                        // writable dirs BEFORE init: on Android
                                        // os.UserConfigDir() is unusable, so
                                        // without BITLY_BIN_DIR set here yt-dlp
                                        // is never installed and the native
                                        // youtube provider silently fails every
                                        // stream resolution.
                                        val appDataDir =
                                            call.argument<String>("app_data_dir") ?: ""
                                        if (appDataDir.isNotEmpty()) {
                                            try {
                                                Gobackend.setAppDataDir(appDataDir)
                                            } catch (e: Exception) {
                                                android.util.Log.w(
                                                    "NativeBridge",
                                                    "setAppDataDir failed: ${e.message}",
                                                )
                                            }
                                        }
                                        Gobackend.initBackend()
                                        val s = Gobackend.initGlobalState()
                                        android.util.Log.i("NativeBridge", "Go backend initialized: $s")
                                        f.complete(s)
                                    } catch (e: Exception) {
                                        android.util.Log.e("NativeBridge", "Failed to init Go backend: ${e.message}")
                                        // Clear the cached future so a retry can
                                        // re-run init from scratch (a transient
                                        // cold-start failure must not poison
                                        // every later attempt).
                                        synchronized(goBackendInitLock) {
                                            if (goBackendInitFuture === f) {
                                                goBackendInitFuture = null
                                            }
                                        }
                                        f.completeExceptionally(e)
                                    }
                                }
                            }
                            future = goBackendInitFuture!!
                        }
                        try {
                            val state = future.get(120, java.util.concurrent.TimeUnit.SECONDS)
                            handler.post { result.success(state ?: "ok") }
                        } catch (e: java.util.concurrent.TimeoutException) {
                            handler.post { result.error("INIT_ERROR", "Go init timed out", null) }
                        } catch (e: Exception) {
                            handler.post { result.error("INIT_ERROR", e.message, null) }
                        }
                    }
                }

                // ── Native Android ────────────────────────────────────────
                "pickSafTree" -> pickSafTreeNative(result)
                "exitApp" -> {
                    android.os.Process.killProcess(android.os.Process.myPid())
                    result.success("ok")
                }

                // ── YouTube (native service, not Go) ──────────────────────
                "searchYouTubeVideo" -> {
                    val trackName = call.argument<String>("track_name") ?: ""
                    val artistName = call.argument<String>("artist_name") ?: ""
                    searchYouTubeVideo(trackName, artistName, result)
                }
                "downloadYouTubeVideo" -> {
                    val trackName = call.argument<String>("track_name") ?: ""
                    val artistName = call.argument<String>("artist_name") ?: ""
                    val outputPath = call.argument<String>("output_path") ?: ""
                    downloadYouTubeVideo(trackName, artistName, outputPath, result)
                }

                // ── iOS-only stubs ────────────────────────────────────────
                "startAccessingIosBookmark", "stopAccessingIosBookmark", "createIosBookmarkFromPath" ->
                    result.success("not_supported_on_android")

                // ── Stubs for methods without Go RPC equivalent ───────────
                "bootstrapEssentialExtensions" -> result.success("[]")
                "startDownloadService", "stopDownloadService" -> result.success("ok")

                // ── Everything else: dispatch via Go backend flat API ──────
                else -> dispatchGoCall(call, result)
            }
        }
    }

    // ── Dispatch Go calls via reflection to flat exports.* functions ─────

    private fun dispatchGoCall(call: MethodCall, result: MethodChannel.Result) {
        val methodName = call.method
        android.util.Log.i("NativeBridge", "dispatchGoCall: method=$methodName")
        executor.execute {
            try {
                // Build argument list from call.arguments
                val args = when (val a = call.arguments) {
                    is List<*> -> a.map { it?.toString() ?: "" }.toTypedArray()
                    is String -> if (a.isEmpty()) emptyArray<String>() else arrayOf(a)
                    is Map<*, *> -> {
                        val json = org.json.JSONObject(
                            a.filterKeys { it is String }
                                .mapKeys { it.key as String }
                        ).toString()
                        arrayOf(json)
                    }
                    else -> emptyArray<String>()
                }

                // Find the Go backend method by name via reflection.
                // gomobile converts Go's PascalCase to Java camelCase,
                // so the Flutter method name (also camelCase) maps directly.
                val methods = Gobackend::class.java.methods
                val goMethod = methods.find { it.name == methodName }

                if (goMethod == null) {
                    handler.post { result.error("NOT_FOUND", "Go method $methodName not found", null) }
                    return@execute
                }

                val paramTypes = goMethod.parameterTypes
                val numParams = paramTypes.size
                val converted = if (numParams > 0) {
                    Array<Any?>(numParams) { i ->
                        val arg = args.getOrElse(i) { "" }
                        val pt = paramTypes[i]
                        when {
                            pt == Long::class.javaPrimitiveType || pt == Long::class.java ->
                                arg.toLongOrNull() ?: 0L
                            pt == Int::class.javaPrimitiveType || pt == Int::class.java ->
                                arg.toIntOrNull() ?: 0
                            pt == Boolean::class.javaPrimitiveType || pt == Boolean::class.java ->
                                arg.toBooleanStrictOrNull() ?: false
                            pt == Double::class.javaPrimitiveType || pt == Double::class.java ->
                                arg.toDoubleOrNull() ?: 0.0
                            pt.isArray && pt.componentType == Byte::class.javaPrimitiveType ->
                                arg.encodeToByteArray()
                            else -> arg // String
                        }
                    }
                } else {
                    emptyArray<Any?>()
                }

                // Run the Go call on the pool with a hard timeout. If it never
                // returns (a JS call stuck inside the extension runtime), the
                // watcher answers Dart with an error after callTimeoutSeconds
                // — the player shows the error instead of spinning at 00:00 —
                // and dumps goroutine stacks so the stuck call is diagnosable.
                // The abandoned task stays on its pool worker (Go's per-call
                // guards release it eventually); other calls keep flowing on
                // the remaining pool threads.
                val future = executor.submit<String> {
                    (goMethod.invoke(null, *converted)?.toString()) ?: "null"
                }
                callWatcher.execute {
                    try {
                        val res = future.get(callTimeoutSeconds, java.util.concurrent.TimeUnit.SECONDS)
                        handler.post { result.success(res) }
                    } catch (e: java.util.concurrent.TimeoutException) {
                        android.util.Log.e(
                            "NativeBridge",
                            "dispatchGoCall TIMEOUT: $methodName > ${callTimeoutSeconds}s"
                        )
                        try {
                            Gobackend.dumpGoroutines("")
                        } catch (t: Throwable) {
                            android.util.Log.e("NativeBridge", "dumpGoroutines failed: ${t.message}")
                        }
                        handler.post {
                            result.error("CALL_TIMEOUT", "Go call $methodName timed out after ${callTimeoutSeconds}s", null)
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("NativeBridge", "dispatchGoCall error: ${e.message}")
                        handler.post { result.error("BACKEND_ERROR", e.message, null) }
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e("NativeBridge", "dispatchGoCall error: ${e.message}")
                handler.post { result.error("BACKEND_ERROR", e.message, null) }
            }
        }
    }

    // ── YouTube helpers ───────────────────────────────────────────────────

    private fun searchYouTubeVideo(trackName: String, artistName: String, result: MethodChannel.Result) {
        executor.execute {
            try {
                val url = YouTubeService.searchYouTubeVideo(trackName, artistName)
                handler.post {
                    if (url != null) result.success(url)
                    else result.error("YOUTUBE_ERROR", "No video found", null)
                }
            } catch (e: Exception) {
                handler.post { result.error("YOUTUBE_ERROR", e.message, null) }
            }
        }
    }

    private fun downloadYouTubeVideo(trackName: String, artistName: String, outputPath: String, result: MethodChannel.Result) {
        executor.execute {
            try {
                val filePath = YouTubeService.downloadYouTubeVideo(trackName, artistName, outputPath)
                handler.post {
                    if (filePath != null) result.success(filePath)
                    else result.error("YOUTUBE_ERROR", "Download failed", null)
                }
            } catch (e: Exception) {
                handler.post { result.error("YOUTUBE_ERROR", e.message, null) }
            }
        }
    }

    // ── SAF Tree Picker ───────────────────────────────────────────────────

    // ── Plataforma ────────────────────────────────────────────────────────

    /**
     * True en Android TV / Google TV / Fire TV.
     *
     * Se combinan uiMode (UI_MODE_TYPE_TELEVISION) con la feature de leanback:
     * los sticks de Amazon y algunos boxes reportan solo una de las dos.
     */
    private fun esTelevisor(): Boolean {
        return try {
            val uiMode = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
            val porUiMode =
                uiMode.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
            val porLeanback =
                packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
            porUiMode || porLeanback
        } catch (e: Exception) {
            false
        }
    }

    private fun pickSafTreeNative(result: MethodChannel.Result) {
        safResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                putExtra(Intent.EXTRA_TITLE, "Seleccionar carpeta para Bitly")
            }
        }
        startActivityForResult(intent, SAF_PICKER_REQUEST_CODE)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SAF_PICKER_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val treeUri = data.data
                if (treeUri != null) {
                    contentResolver.takePersistableUriPermission(
                        treeUri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    )
                    val displayName = getTreeDisplayName(treeUri)
                    val resultMap = hashMapOf(
                        "tree_uri" to treeUri.toString(),
                        "display_name" to displayName
                    )
                    safResult?.success(resultMap)
                } else {
                    safResult?.error("SAF_ERROR", "No tree URI returned", null)
                }
            } else {
                safResult?.success(null)
            }
            safResult = null
        }
    }

    private fun getTreeDisplayName(treeUri: android.net.Uri): String {
        return try {
            val documentUri = android.provider.DocumentsContract.buildDocumentUriUsingTree(
                treeUri,
                android.provider.DocumentsContract.getTreeDocumentId(treeUri)
            )
            val cursor = contentResolver.query(
                documentUri,
                arrayOf(android.provider.DocumentsContract.Document.COLUMN_DISPLAY_NAME),
                null, null, null
            )
            cursor?.use {
                if (it.moveToFirst()) {
                    val nameIndex = it.getColumnIndexOrThrow(android.provider.DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                    it.getString(nameIndex)
                } else "Unknown"
            } ?: "Unknown"
        } catch (_: Exception) { "Unknown" }
    }
}
