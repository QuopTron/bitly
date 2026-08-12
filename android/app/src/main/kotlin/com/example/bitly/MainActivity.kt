package com.example.bitly

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import gobackend.Gobackend
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.bitly/backend"
    private val SESSION_CHANNEL = "com.bitly/session_grant"
    private val OAUTH_CHANNEL = "com.bitly/oauth_callback"
    private val executor = Executors.newSingleThreadExecutor()
    private val handler = Handler(Looper.getMainLooper())

    private var safResult: MethodChannel.Result? = null
    private val SAF_PICKER_REQUEST_CODE = 1001

    // Grant received from a spotiflac://session-grant deep link while Flutter
    // was not ready yet (cold start). Delivered once the engine is configured.
    private var pendingSessionGrant: String? = null

    // OAuth callback received from a spotiflac://callback deep link (e.g. the
    // future Spotify PKCE flow) before Flutter was ready (cold start).
    private var pendingOAuth: OAuthResult? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleDeepLinkIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleDeepLinkIntent(intent)
    }

    /**
     * Dispatches spotiflac:// deep links to the matching handler by host.
     *
     * - `session-grant` → signed-session (Cloudflare) verification grant
     * - `callback`     → extension OAuth (PKCE) callback, e.g. Spotify
     */
    private fun handleDeepLinkIntent(intent: Intent?) {
        if (intent == null) return
        val uri = intent.data ?: return
        if (!uri.scheme.equals("spotiflac", ignoreCase = true)) return
        when (uri.host?.lowercase()) {
            "session-grant" -> handleSessionGrant(intent, uri)
            "callback" -> handleOAuthCallback(intent, uri)
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // ── Init ──────────────────────────────────────────────────
                "initGoBackend" -> {
                    executor.execute {
                        try {
                            Gobackend.initBackend()
                            val state = Gobackend.initGlobalState()
                            android.util.Log.i("NativeBridge", "Go backend initialized: $state")
                            handler.post { result.success(state) }
                        } catch (e: Exception) {
                            android.util.Log.e("NativeBridge", "Failed to init Go backend: ${e.message}")
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
        android.util.Log.i("NativeBridge", "dispatchGoCall: method=${call.method}")
        executor.execute {
            try {
                val methodName = call.method

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

                if (goMethod != null) {
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

                    val res = goMethod.invoke(null, *converted)
                    handler.post { result.success(res?.toString() ?: "null") }
                } else {
                    handler.post { result.error("NOT_FOUND", "Go method $methodName not found", null) }
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
