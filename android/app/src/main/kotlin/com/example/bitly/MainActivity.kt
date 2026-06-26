package com.example.bitly

import android.app.Activity
import android.content.Intent
import android.os.Build
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
    private val executor = Executors.newSingleThreadExecutor()
    private val handler = Handler(Looper.getMainLooper())

    private var safResult: MethodChannel.Result? = null
    private val SAF_PICKER_REQUEST_CODE = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        android.util.Log.i("NativeBridge", "FlutterEngine configured. Waiting for Flutter to initialize DB schema...")

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // ── Init ──────────────────────────────────────────────────
                "initGoBackend" -> {
                    val dbPath = call.argument<String>("db_path") ?: ""
                    val ytDlpPath = call.argument<String>("ytdlp_path") ?: ""
                    android.util.Log.i("NativeBridge", "Initializing Go backend: dbPath=$dbPath")
                    executor.execute {
                        try {
                            Gobackend.initBackend(dbPath)
                            if (ytDlpPath.isNotEmpty()) {
                                Gobackend.invokeRPC("setYtDlpPath", """{"path":"$ytDlpPath"}""")
                            }
                            try {
                                Gobackend.invokeRPC("ensureYtDlp", "")
                            } catch (e: Exception) {
                                android.util.Log.w("NativeBridge", "yt-dlp install skipped: ${e.message}")
                            }
                            handler.post { result.success("ok") }
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

                // ── File validation wrappers ──────────────────────────────
                "loadExtensionFromPath" -> {
                    val filePath = call.argument<String>("file_path") ?: ""
                    executor.execute {
                        try {
                            if (filePath.isEmpty()) {
                                handler.post { result.error("BACKEND_ERROR", "invalid file path", null) }
                                return@execute
                            }
                            val f = File(filePath)
                            if (!f.exists() || !f.isFile) {
                                handler.post { result.error("BACKEND_ERROR", "file not found: $filePath", null) }
                                return@execute
                            }
                            val res = Gobackend.invokeRPC("loadExtensionFromPath", """{"file_path":"$filePath"}""")
                            handler.post { result.success(res) }
                        } catch (e: Exception) {
                            handler.post { result.error("BACKEND_ERROR", e.message, null) }
                        }
                    }
                }
                "downloadStoreExtensionJSON" -> {
                    val extensionId = call.argument<String>("extension_id") ?: ""
                    val destDir = call.argument<String>("dest_dir") ?: ""
                    executor.execute {
                        try {
                            val path = Gobackend.invokeRPC("downloadStoreExtension", """{"extension_id":"$extensionId","dest_dir":"$destDir"}""")
                            android.util.Log.i("NativeBridge", "downloadStoreExtension: path=$path")
                            if (path.isNullOrEmpty() || path == "\"\"") {
                                handler.post { result.error("BACKEND_ERROR", "download returned empty path", null) }
                                return@execute
                            }
                            val cleanPath = path.trim('"')
                            val f = File(cleanPath)
                            if (!f.exists() || !f.isFile) {
                                handler.post { result.error("BACKEND_ERROR", "file not found: $cleanPath", null) }
                                return@execute
                            }
                            handler.post { result.success(cleanPath) }
                        } catch (e: Exception) {
                            handler.post { result.error("BACKEND_ERROR", e.message, null) }
                        }
                    }
                }
                "fetchAndSaveLyrics" -> {
                    val trackName = call.argument<String>("track_name") ?: ""
                    val artistName = call.argument<String>("artist_name") ?: ""
                    val spotifyID = call.argument<String>("spotify_id") ?: ""
                    val durationMs = (call.argument<Int>("duration_ms") ?: 0).toLong()
                    val outputPath = call.argument<String>("output_path") ?: ""
                    val audioFilePath = call.argument<String>("audio_file_path") ?: ""
                    executor.execute {
                        try {
                            val params = org.json.JSONObject()
                            params.put("track_name", trackName)
                            params.put("artist_name", artistName)
                            params.put("spotify_id", spotifyID)
                            params.put("duration_ms", durationMs)
                            params.put("output_path", outputPath)
                            params.put("audio_file_path", audioFilePath)
                            Gobackend.invokeRPC("fetchAndSaveLyrics", params.toString())
                            handler.post { result.success("ok") }
                        } catch (e: Exception) {
                            handler.post { result.error("BACKEND_ERROR", e.message, null) }
                        }
                    }
                }

                // ── Everything else: route through InvokeRPC ──────────────
                else -> genericRPC(call, result)
            }
        }
    }

    // ── Generic RPC dispatcher ────────────────────────────────────────────

    private fun genericRPC(call: MethodCall, result: MethodChannel.Result) {
        android.util.Log.i("NativeBridge", "genericRPC: method=" + call.method + " args=" + call.arguments?.toString())
        executor.execute {
            try {
                val paramsStr = when (val args = call.arguments) {
                    is Map<*, *> -> {
                        val map = args
                            .filterKeys { it is String }
                            .mapKeys { it.key as String }
                        if (map.isEmpty()) "" else org.json.JSONObject(map).toString()
                    }
                    is String -> if (args.isEmpty()) "" else """{"value":"$args"}"""
                    else -> ""
                }
                val res = Gobackend.invokeRPC(call.method, paramsStr)
                handler.post { result.success(res) }
            } catch (e: Exception) {
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
