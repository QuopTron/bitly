package com.example.bitly

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import gobackend.Gobackend
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.zarz.Bitly/backend"
    private val executor = Executors.newSingleThreadExecutor()
    private val handler = Handler(Looper.getMainLooper())

    private var safResult: MethodChannel.Result? = null
    private val SAF_PICKER_REQUEST_CODE = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // IMPORTANT: Do NOT initialize Go backend here!
        // Flutter's MasterDatabase must create the schema FIRST, then we initialize Go backend.
        // The Go backend will be initialized from Flutter (main.dart) after the database is ready.
        android.util.Log.i("NativeBridge", "FlutterEngine configured. Waiting for Flutter to initialize DB schema...")

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // --- Backend Initialization (must be called AFTER Flutter creates DB schema) ---
                "initGoBackend" -> {
                    val dbPath = call.argument<String>("db_path") ?: ""
                    val ytDlpPath = call.argument<String>("ytdlp_path") ?: ""

                    android.util.Log.i("NativeBridge", "Initializing Go backend: dbPath=$dbPath, ytDlpPath=$ytDlpPath")

                    executor.execute {
                        try {
                            // Set yt-dlp path for Go backend
                            Gobackend.setCustomYtDlpPath(ytDlpPath)

                            // Initialize Go backend with existing DB (schema already created by Flutter)
                            Gobackend.initMasterDatabaseJSON(dbPath)
                            android.util.Log.i("NativeBridge", "Go backend database initialized")

                            // Ensure yt-dlp binary is available
                            Gobackend.ensureYtDlp()
                            android.util.Log.i("NativeBridge", "yt-dlp ensured")

                            handler.post { result.success("ok") }
                        } catch (e: Exception) {
                            android.util.Log.e("NativeBridge", "Failed to init Go backend: ${e.message}")
                            handler.post { result.error("INIT_ERROR", e.message, null) }
                        }
                    }
                }

                // --- Database & Settings ---
                "InitMasterDatabaseJSON" -> {
                    val path = call.arguments as? String ?: ""
                    executeJsonMethod({ Gobackend.initMasterDatabaseJSON(path); "ok" }, result)
                }
                "loadAppSettings" -> executeJsonMethod({ Gobackend.loadAppSettings() }, result)
                "saveAppSettings" -> {
                    val settingsJson = call.argument<String>("value") ?: ""
                    executeJsonMethod({ Gobackend.saveAppSettings(settingsJson); "ok" }, result)
                }

                // --- Extensions Store & Manager ---
                "initExtensionSystem" -> {
                    val extensionsDir = call.argument<String>("extensions_dir") ?: ""
                    val dataDir = call.argument<String>("data_dir") ?: ""
                    android.util.Log.i("NativeBridge", "initExtensionSystem: extensionsDir=$extensionsDir dataDir=$dataDir")
                    executeJsonMethod({ Gobackend.initExtensionSystem(extensionsDir, dataDir); "ok" }, result)
                }
                "getInstalledExtensions" -> {
                    executeJsonMethod({ Gobackend.getInstalledExtensions() }, result)
                }
                "initExtensionStore" -> {
                    val cacheDir = call.argument<String>("cache_dir") ?: ""
                    executeJsonMethod({ Gobackend.initExtensionStoreJSON(cacheDir); "ok" }, result)
                }
                "getStoreExtensionsJSON" -> {
                    val forceRefresh = call.argument<Boolean>("force_refresh") ?: false
                    executeJsonMethod({ Gobackend.getStoreExtensionsJSON(forceRefresh) }, result)
                }
                "setDownloadFallbackExtensionIdsJSON" -> {
                    val jsonStr = call.argument<String>("extension_ids") ?: ""
                    executeJsonMethod({ Gobackend.setDownloadFallbackExtensionIdsJSON(jsonStr); "ok" }, result)
                }
                "setStoreRegistryURLJSON" -> {
                    val registryUrl = call.argument<String>("registry_url") ?: ""
                    executeJsonMethod({ Gobackend.setStoreRegistryURLJSON(registryUrl); "ok" }, result)
                }
                "getStoreRegistryURLJSON" -> {
                    executeJsonMethod({ Gobackend.getStoreRegistryURLJSON() }, result)
                }
                "clearStoreRegistryURLJSON" -> {
                    executeJsonMethod({ Gobackend.clearStoreRegistryURLJSON(); "ok" }, result)
                }

                // --- Playback Control ---
                "playbackPlayTrack" -> {
                    val trackJson = call.argument<String>("track_json") ?: ""
                    executeJsonMethod({ Gobackend.playbackPlayTrack(trackJson) }, result)
                }
                "playbackPause" -> {
                    executeJsonMethod({ Gobackend.playbackPause() }, result)
                }
                "playbackResume" -> {
                    executeJsonMethod({ Gobackend.playbackResume() }, result)
                }
                "playbackStop" -> {
                    executeJsonMethod({ Gobackend.playbackStop() }, result)
                }
                "playbackNext" -> {
                    executeJsonMethod({ Gobackend.playbackNext() }, result)
                }
                "playbackPrevious" -> {
                    executeJsonMethod({ Gobackend.playbackPrevious() }, result)
                }
                "playbackSeek" -> {
                    val positionMs = (call.argument<Int>("position_ms") ?: 0).toLong()
                    executeJsonMethod({ Gobackend.playbackSeek(positionMs) }, result)
                }
                "playbackSetQueue" -> {
                    val queueJson = call.argument<String>("queue_json") ?: ""
                    executeJsonMethod({ Gobackend.playbackSetQueue(queueJson) }, result)
                }
                "playbackAddToQueue" -> {
                    val trackJson = call.argument<String>("track_json") ?: ""
                    executeJsonMethod({ Gobackend.playbackAddToQueue(trackJson) }, result)
                }
                "playbackSetShuffle" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    executeJsonMethod({ Gobackend.playbackSetShuffle(enabled) }, result)
                }
                "playbackSetRepeat" -> {
                    val mode = call.argument<String>("mode") ?: "none"
                    executeJsonMethod({ Gobackend.playbackSetRepeat(mode) }, result)
                }
                "playbackTrackCompleted" -> {
                    executeJsonMethod({ Gobackend.playbackTrackCompleted() }, result)
                }
                "playbackGetState" -> {
                    executeJsonMethod({ Gobackend.playbackGetState() }, result)
                }
                "playbackGetHistory" -> {
                    val limit = (call.argument<Int>("limit") ?: 50).toLong()
                    executeJsonMethod({ Gobackend.playbackGetHistory(limit) }, result)
                }
                "playbackGetQueue" -> {
                    executeJsonMethod({ Gobackend.playbackGetQueue() }, result)
                }

                // SAF Operations - These don't exist in Go backend, must use native Android
                // (No Go functions for SAF - all handled natively in Kotlin)

                // Post Processing - These don't exist with these names in Go
                // (Go has RunPostProcessingJSON and RunPostProcessingV2JSON, not the versions without JSON suffix)

                // iOS Bookmark - No-op on Android
                "createIosBookmarkFromPath" -> {
                    result.success("not_supported_on_android")
                }
                "startAccessingIosBookmark" -> {
                    result.success("not_supported_on_android")
                }
                "stopAccessingIosBookmark" -> {
                    result.success("not_supported_on_android")
                }

                // Misc - exitApp doesn't exist in Go, handle natively
                "exitApp" -> {
                    executeJsonMethod({ android.os.Process.killProcess(android.os.Process.myPid()); "ok" }, result)
                }

                // getProviderMetadata - Different signature in Go (needs 3 params)
                "getProviderMetadata" -> {
                    val providerId = call.argument<String>("provider_id") ?: ""
                    val resourceType = call.argument<String>("resource_type") ?: ""
                    val resourceId = call.argument<String>("resource_id") ?: ""
                    executeJsonMethod({ Gobackend.getProviderMetadataJSON(providerId, resourceType, resourceId) }, result)
                }

                "downloadStoreExtensionJSON" -> {
                    val extensionId = call.argument<String>("extension_id") ?: ""
                    val destDir = call.argument<String>("dest_dir") ?: ""
                    // Run download and validate file existence before returning
                    executor.execute {
                        try {
                            val path = Gobackend.downloadStoreExtensionJSON(extensionId, destDir)
                            android.util.Log.i("NativeBridge", "downloadStoreExtensionJSON: downloaded to=$path")
                            if (path == null || path.isEmpty()) {
                                handler.post { result.error("BACKEND_ERROR", "download returned empty path", null) }
                                return@execute
                            }
                            val f = java.io.File(path)
                            if (!f.exists() || !f.isFile) {
                                // Log parent dir contents for debugging
                                try {
                                    val parent = f.parentFile
                                    if (parent != null && parent.exists() && parent.isDirectory) {
                                        val children = parent.listFiles()
                                        val names = children?.map { it.name + (if (it.isDirectory) "/" else "") }?.joinToString(", ") ?: "(none)"
                                        android.util.Log.w("NativeBridge", "downloaded file not found: $path. Parent dir (${parent.path}) contents: $names")
                                    } else {
                                        android.util.Log.w("NativeBridge", "downloaded file not found: $path. Parent dir not available")
                                    }
                                } catch (e2: Exception) {
                                    android.util.Log.e("NativeBridge", "Error listing parent dir for $path: ${e2.message}")
                                }
                                handler.post { result.error("BACKEND_ERROR", "downloaded file not found: $path", null) }
                                return@execute
                            }
                            handler.post { result.success(path) }
                        } catch (e: Exception) {
                            handler.post { result.error("BACKEND_ERROR", e.message, null) }
                        }
                    }
                }
                "searchStoreExtensionsJSON" -> {
                    val query = call.argument<String>("query") ?: ""
                    val category = call.argument<String>("category") ?: ""
                    executeJsonMethod({ Gobackend.searchStoreExtensionsJSON(query, category) }, result)
                }
                "getStoreCategoriesJSON" -> {
                    executeJsonMethod({ Gobackend.getStoreCategoriesJSON() }, result)
                }
                "clearStoreCacheJSON" -> {
                    executeJsonMethod({ Gobackend.clearStoreCacheJSON(); "ok" }, result)
                }
                "cancelExtensionRequestJSON" -> {
                    val requestId = call.argument<String>("request_id") ?: ""
                    executeJsonMethod({ Gobackend.cancelExtensionRequestJSON(requestId); "ok" }, result)
                }
                "loadExtensionFromPath" -> {
                    val filePath = call.argument<String>("file_path") ?: ""
                    android.util.Log.i("NativeBridge", "loadExtensionFromPath: filePath=$filePath")
                    // Validate file existence before calling Go backend
                    executor.execute {
                        try {
                            if (filePath.isEmpty()) {
                                handler.post { result.error("BACKEND_ERROR", "invalid file path", null) }
                                return@execute
                            }
                            val f = java.io.File(filePath)
                            if (!f.exists() || !f.isFile) {
                                // Log parent dir contents for debugging
                                try {
                                    val parent = f.parentFile
                                    if (parent != null && parent.exists() && parent.isDirectory) {
                                        val children = parent.listFiles()
                                        val names = children?.map { it.name + (if (it.isDirectory) "/" else "") }?.joinToString(", ") ?: "(none)"
                                        android.util.Log.w("NativeBridge", "loadExtensionFromPath: file not found: $filePath. Parent dir (${parent.path}) contents: $names")
                                    } else {
                                        android.util.Log.w("NativeBridge", "loadExtensionFromPath: file not found: $filePath. Parent dir not available")
                                    }
                                } catch (e2: Exception) {
                                    android.util.Log.e("NativeBridge", "Error listing parent dir for $filePath: ${e2.message}")
                                }
                                handler.post { result.error("BACKEND_ERROR", "invalid file path", null) }
                                return@execute
                            }
                            val res = Gobackend.loadExtensionFromPath(filePath)
                            handler.post { result.success(res) }
                        } catch (e: Exception) {
                            handler.post { result.error("BACKEND_ERROR", e.message, null) }
                        }
                    }
                }
                "loadExtensionsFromDir" -> {
                    val dirPath = call.argument<String>("dir_path") ?: ""
                    android.util.Log.i("NativeBridge", "loadExtensionsFromDir: dirPath=$dirPath")
                    executeJsonMethod({ Gobackend.loadExtensionsFromDir(dirPath) }, result)
                }
                "invokeExtensionAction" -> {
                    val extensionId = call.argument<String>("extension_id") ?: ""
                    val action = call.argument<String>("action") ?: ""
                    executeJsonMethod({ Gobackend.invokeExtensionActionJSON(extensionId, action) }, result)
                }
                "setExtensionEnabled" -> {
                    val extensionId = call.argument<String>("extension_id") ?: ""
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    android.util.Log.d("NativeBridge", "setExtensionEnabled: extensionId=$extensionId enabled=$enabled")
                    executeJsonMethod({ Gobackend.setExtensionEnabledByID(extensionId, enabled); "ok" }, result)
                }
                // removeExtension, upgradeExtension - handled differently in Go
                "checkExtensionUpgrade" -> {
                    val filePath = call.argument<String>("file_path") ?: ""
                    executeJsonMethod({ Gobackend.checkExtensionUpgradeFromPath(filePath) }, result)
                }
                "getExtensionPendingAuth" -> {
                    val extensionId = call.argument<String>("extension_id") ?: ""
                    executeJsonMethod({ Gobackend.getExtensionPendingAuthJSON(extensionId) }, result)
                }
                "setExtensionAuthCode" -> {
                    val extensionId = call.argument<String>("extension_id") ?: ""
                    val code = call.argument<String>("code") ?: ""
                    Gobackend.setExtensionAuthCodeByID(extensionId, code)
                    result.success("ok")
                }
                "setExtensionTokens" -> {
                    val extensionId = call.argument<String>("extension_id") ?: ""
                    val accessToken = call.argument<String>("access_token") ?: ""
                    val refreshToken = call.argument<String>("refresh_token") ?: ""
                    val expiresIn = (call.argument<Int>("expires_in") ?: 0).toLong()
                    Gobackend.setExtensionTokensByID(extensionId, accessToken, refreshToken, expiresIn)
                    result.success("ok")
                }
                "isExtensionAuthenticated" -> {
                    val extensionId = call.argument<String>("extension_id") ?: ""
                    val isAuthenticated = Gobackend.isExtensionAuthenticatedByID(extensionId)
                    result.success(if (isAuthenticated) "true" else "false")
                }
                "clearExtensionPendingAuth" -> {
                    val extensionId = call.argument<String>("extension_id") ?: ""
                    Gobackend.clearExtensionPendingAuthByID(extensionId)
                    result.success("ok")
                }

                // --- Search & YouTube ---
                "searchTracksWithMetadataProviders" -> {
                    val query = call.argument<String>("query") ?: ""
                    val limit = (call.argument<Int>("limit") ?: 20).toLong()
                    val includeExtensions = call.argument<Boolean>("include_extensions") ?: true
                    executeJsonMethod({ Gobackend.searchTracksWithMetadataProvidersJSON(query, limit, includeExtensions) }, result)
                }
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
                "downloadByStrategy" -> {
                    val requestJson = call.arguments as? String ?: ""
                    executeJsonMethod({ Gobackend.downloadByStrategy(requestJson) }, result)
                }

                // --- History & Collections ---
                "getDownloadHistory" -> {
                    val limit = (call.argument<Int>("limit") ?: 100).toLong()
                    val offset = (call.argument<Int>("offset") ?: 0).toLong()
                    executeJsonMethod({ Gobackend.getDownloadHistory(limit, offset) }, result)
                }
                "getDownloadHistoryCount" -> {
                    executeJsonMethod({ Gobackend.getDownloadHistoryCount().toString() }, result)
                }
                "getDownloadEntryBySpotifyID" -> {
                    val spotifyId = call.argument<String>("request") ?: ""
                    executeJsonMethod({ Gobackend.getDownloadEntryBySpotifyID(spotifyId) }, result)
                }
                "getDownloadEntryByISRC" -> {
                    val isrc = call.argument<String>("request") ?: ""
                    executeJsonMethod({ Gobackend.getDownloadEntryByISRC(isrc) }, result)
                }
                "findDownloadEntryByTrackAndArtist" -> {
                    val trackName = call.argument<String>("track_name") ?: ""
                    val artistName = call.argument<String>("artist_name") ?: ""
                    executeJsonMethod({ Gobackend.findDownloadEntryByTrackAndArtist(trackName, artistName) }, result)
                }
                "getDownloadHistoryFilePaths" -> {
                    executeJsonMethod({ Gobackend.getDownloadHistoryFilePaths() }, result)
                }
                "getDownloadHistoryGroupedCounts" -> {
                    executeJsonMethod({ Gobackend.getDownloadHistoryGroupedCounts() }, result)
                }
                "existingDownloadTrackKeys" -> {
                    val requestJson = call.argument<String>("request") ?: ""
                    executeJsonMethod({ Gobackend.existingDownloadTrackKeys(requestJson) }, result)
                }
                "getDownloadAlbumTracks" -> {
                    val album = call.argument<String>("album") ?: ""
                    val artist = call.argument<String>("artist") ?: ""
                    executeJsonMethod({ Gobackend.getDownloadAlbumTracks(album, artist) }, result)
                }
                "getDownloadArtistTracks" -> {
                    val artist = call.argument<String>("artist") ?: ""
                    executeJsonMethod({ Gobackend.getDownloadArtistTracks(artist) }, result)
                }
                "upsertDownloadEntry" -> {
                    val requestJson = call.argument<String>("request") ?: ""
                    executeJsonMethod({ Gobackend.upsertDownloadEntryJSON(requestJson); "ok" }, result)
                }
                "updateDownloadFilePath" -> {
                    val id = call.argument<String>("id") ?: ""
                    val filePath = call.argument<String>("file_path") ?: ""
                    executor.execute {
                        try {
                            Gobackend.updateDownloadFilePath(id, filePath)
                            handler.post { result.success("ok") }
                        } catch (e: Exception) {
                            handler.post { result.error("BACKEND_ERROR", e.message, null) }
                        }
                    }
                }
                "getAllCollections" -> {
                    executeJsonMethod({ Gobackend.getAllCollections() }, result)
                }
                "getDownloadEntryByID" -> {
                    val id = call.argument<String>("id") ?: ""
                    executeJsonMethod({ Gobackend.getDownloadEntryByID(id) }, result)
                }
                "deleteDownloadEntriesByIDs" -> {
                    val requestJson = call.argument<String>("request") ?: ""
                    executeJsonMethod({ Gobackend.deleteDownloadEntriesByIDsJSON(requestJson); "ok" }, result)
                }
                "deleteDownloadEntriesByTrackMatch" -> {
                    val trackName = call.argument<String>("track_name") ?: ""
                    val artistName = call.argument<String>("artist_name") ?: ""
                    executeJsonMethod({ Gobackend.deleteDownloadEntriesByTrackMatch(trackName, artistName); "ok" }, result)
                }
                "clearDownloadHistory" -> {
                    executeJsonMethod({ Gobackend.clearDownloadHistory(); "ok" }, result)
                }
                "updateDownloadAudioMetadata" -> {
                    val requestJson = call.argument<String>("request") ?: ""
                    executeJsonMethod({ Gobackend.updateDownloadAudioMetadataJSON(requestJson); "ok" }, result)
                }
                "getPendingDownloadQueueRows" -> {
                    executeJsonMethod({ Gobackend.getPendingDownloadQueueRowsJSON() }, result)
                }

                // --- Lyrics & Sync ---
                "setLyricsProvidersJSON" -> {
                    val jsonStr = call.argument<String>("providers_json") ?: ""
                    executeJsonMethod({ Gobackend.setLyricsProvidersJSON(jsonStr); "ok" }, result)
                }
                "getLyricsProvidersJSON" -> {
                    executeJsonMethod({ Gobackend.getLyricsProvidersJSON() }, result)
                }
                "getAvailableLyricsProvidersJSON" -> {
                    executeJsonMethod({ Gobackend.getAvailableLyricsProvidersJSON() }, result)
                }
                "setLyricsFetchOptionsJSON" -> {
                    val jsonStr = call.arguments as? String ?: ""
                    executeJsonMethod({ Gobackend.setLyricsFetchOptionsJSON(jsonStr); "ok" }, result)
                }
                "getLyricsFetchOptionsJSON" -> {
                    executeJsonMethod({ Gobackend.getLyricsFetchOptionsJSON() }, result)
                }
                "setNetworkCompatibilityOptions" -> {
                    val allowHttp = call.argument<Boolean>("allow_http") ?: false
                    val insecureTls = call.argument<Boolean>("insecure_tls") ?: false
                    // Nota: Si el backend espera un JSON, usamos JSON. Si no, pasamos booleanos.
                    executeJsonMethod({ Gobackend.setNetworkCompatibilityOptions(allowHttp, insecureTls); "ok" }, result)
                }
                "setProviderPriorityJSON" -> {
                    val jsonStr = call.argument<String>("priority") ?: ""
                    executeJsonMethod({ Gobackend.setProviderPriorityJSON(jsonStr); "ok" }, result)
                }
                "getProviderPriorityJSON" -> {
                    executeJsonMethod({ Gobackend.getProviderPriorityJSON() }, result)
                }
                "setMetadataProviderPriorityJSON" -> {
                    val jsonStr = call.argument<String>("priority") ?: ""
                    executeJsonMethod({ Gobackend.setMetadataProviderPriorityJSON(jsonStr); "ok" }, result)
                }
                "getMetadataProviderPriorityJSON" -> {
                    executeJsonMethod({ Gobackend.getMetadataProviderPriorityJSON() }, result)
                }
                "getExtensionSettingsJSON" -> {
                    val extensionId = call.argument<String>("extension_id") ?: ""
                    executeJsonMethod({ Gobackend.getExtensionSettingsJSON(extensionId) }, result)
                }
                "setExtensionSettingsJSON" -> {
                    val extensionId = call.argument<String>("extension_id") ?: ""
                    val settingsJson = call.argument<String>("settings") ?: ""
                    executeJsonMethod({ Gobackend.setExtensionSettingsJSON(extensionId, settingsJson); "ok" }, result)
                }

                // --- Collections & Favorites ---
                "upsertCollection" -> {
                    val jsonStr = call.arguments as? String ?: ""
                    executeJsonMethod({ Gobackend.upsertCollection(jsonStr); "ok" }, result)
                }
                "deleteCollection" -> {
                    val id = call.arguments as? String ?: ""
                    executeJsonMethod({ Gobackend.deleteCollection(id); "ok" }, result)
                }
                "addToCollection" -> {
                    val collectionId = call.argument<String>("collection_id") ?: ""
                    val itemId = call.argument<String>("item_id") ?: ""
                    val addedAt = call.argument<String>("added_at") ?: ""
                    val itemJson = call.argument<String>("item_json") ?: ""
                    executeJsonMethod({ Gobackend.addToCollection(collectionId, itemId, addedAt, itemJson); "ok" }, result)
                }
                "removeFromCollection" -> {
                    val collectionId = call.argument<String>("collection_id") ?: ""
                    val itemId = call.argument<String>("item_id") ?: ""
                    executeJsonMethod({ Gobackend.removeFromCollection(collectionId, itemId); "ok" }, result)
                }
                "upsertFavorite" -> {
                    val jsonStr = call.arguments as? String ?: ""
                    executeJsonMethod({ Gobackend.upsertFavorite(jsonStr); "ok" }, result)
                }
                "deleteFavorite" -> {
                    val itemId = call.arguments as? String ?: ""
                    executeJsonMethod({ Gobackend.deleteFavorite(itemId); "ok" }, result)
                }
                "getAllFavorites" -> {
                    val type = call.argument<String>("type") ?: ""
                    executeJsonMethod({ Gobackend.getAllFavorites(type) }, result)
                }
                "getAllCollectionItems" -> {
                    executeJsonMethod({ Gobackend.getAllCollectionItems() }, result)
                }
                "getCollectionItemIDsByItemID" -> {
                    val itemId = call.argument<String>("item_id") ?: ""
                    executeJsonMethod({ Gobackend.getCollectionItemIDsByItemID(itemId) }, result)
                }

                // --- Download Queue ---
                "saveDownloadQueue" -> {
                    val jsonStr = call.argument<String>("items") ?: ""
                    executeJsonMethod({ Gobackend.saveDownloadQueue(jsonStr); "ok" }, result)
                }
                "loadDownloadQueue" -> {
                    executeJsonMethod({ Gobackend.loadDownloadQueue() }, result)
                }
                "getPendingDownloadQueueRows" -> {
                    executeJsonMethod({ Gobackend.getPendingDownloadQueueRowsJSON() }, result)
                }
                "replacePendingDownloadQueueRows" -> {
                    val jsonStr = call.argument<String>("rows") ?: ""
                    executeJsonMethod({ Gobackend.replacePendingDownloadQueueRows(jsonStr); "ok" }, result)
                }

                // --- Stats & History ---
                "logPlay" -> {
                    val trackId = call.argument<String>("track_id") ?: ""
                    val trackName = call.argument<String>("track_name") ?: ""
                    val artistName = call.argument<String>("artist_name") ?: ""
                    val albumName = call.argument<String>("album_name") ?: ""
                    val playedAt = call.argument<String>("played_at") ?: ""
                    val durationMs = (call.argument<Int>("duration_ms") ?: 0).toLong()
                    val percentage = (call.argument<Int>("percentage") ?: 0).toLong()
                    executeJsonMethod({ Gobackend.logPlay(trackId, trackName, artistName, albumName, playedAt, durationMs, percentage); "ok" }, result)
                }
                "getTotalStats" -> {
                    executeJsonMethod({ Gobackend.getTotalStats() }, result)
                }
                "clearAllStats" -> {
                    executeJsonMethod({ Gobackend.clearAllStats(); "ok" }, result)
                }
                "resetDatabase" -> {
                    executeJsonMethod({ Gobackend.resetDatabase(); "ok" }, result)
                }
                "getSecretCounter" -> {
                    val key = call.argument<String>("key") ?: ""
                    executeJsonMethod({ Gobackend.getSecretCounter(key).toString() }, result)
                }
                "incrementNightPlays" -> {
                    executeJsonMethod({ Gobackend.incrementNightPlays(); "ok" }, result)
                }
                "updateAlbumStreak" -> {
                    val streak = call.argument<Int>("streak") ?: 0
                    executeJsonMethod({ Gobackend.updateAlbumStreak(streak.toLong()); "ok" }, result)
                }
                "isSecretUnlocked" -> {
                    val key = call.argument<String>("key") ?: ""
                    executeJsonMethod({ if (Gobackend.isSecretUnlocked(key)) "true" else "false" }, result)
                }
                "unlockSecret" -> {
                    val key = call.argument<String>("key") ?: ""
                    executeJsonMethod({ Gobackend.unlockSecret(key); "ok" }, result)
                }
                "getUnlockedSecrets" -> {
                    executeJsonMethod({ Gobackend.getUnlockedSecrets() }, result)
                }
                "getTopTracks" -> {
                    val limit = (call.argument<Int>("limit") ?: 50).toLong()
                    executeJsonMethod({ Gobackend.getTopTracks(limit) }, result)
                }
                "getTopAlbums" -> {
                    val limit = (call.argument<Int>("limit") ?: 50).toLong()
                    executeJsonMethod({ Gobackend.getTopAlbums(limit) }, result)
                }
                "getTopArtists" -> {
                    val limit = (call.argument<Int>("limit") ?: 50).toLong()
                    executeJsonMethod({ Gobackend.getTopArtists(limit) }, result)
                }

                // --- Recent Access ---
                "upsertRecentAccessRow" -> {
                    val key = call.argument<String>("key") ?: ""
                    val itemJson = call.argument<String>("item_json") ?: ""
                    val accessedAt = call.argument<String>("accessed_at") ?: ""
                    executeJsonMethod({ Gobackend.upsertRecentAccessRow(key, itemJson, accessedAt); "ok" }, result)
                }
                "getRecentAccessRows" -> {
                    val limit = (call.argument<Int>("limit") ?: 50).toLong()
                    executeJsonMethod({ Gobackend.getRecentAccessRows(limit) }, result)
                }
                "deleteRecentAccessRow" -> {
                    val key = call.argument<String>("key") ?: ""
                    executeJsonMethod({ Gobackend.deleteRecentAccessRow(key); "ok" }, result)
                }
                "clearRecentAccessRows" -> {
                    executeJsonMethod({ Gobackend.clearRecentAccessRows(); "ok" }, result)
                }
                "getHiddenRecentDownloadIds" -> {
                    executeJsonMethod({ Gobackend.getHiddenRecentDownloadIds() }, result)
                }
                "addHiddenRecentDownloadId" -> {
                    val downloadId = call.argument<String>("download_id") ?: ""
                    executeJsonMethod({ Gobackend.addHiddenRecentDownloadId(downloadId); "ok" }, result)
                }
                "clearHiddenRecentDownloadIds" -> {
                    executeJsonMethod({ Gobackend.clearHiddenRecentDownloadIds(); "ok" }, result)
                }

                // --- Local Library ---
                "getLocalLibraryPage" -> {
                    val limit = (call.argument<Int>("limit") ?: 50).toLong()
                    val offset = (call.argument<Int>("offset") ?: 0).toLong()
                    val searchQuery = call.argument<String>("searchQuery") ?: call.argument<String>("search_query") ?: ""
                    val sortMode = call.argument<String>("sortMode") ?: call.argument<String>("sort_mode") ?: "name"
                    executeJsonMethod({ Gobackend.getLocalLibraryPage(limit, offset, searchQuery, sortMode) }, result)
                }
                "getLocalLibraryCount" -> {
                    val searchQuery = call.argument<String>("searchQuery") ?: call.argument<String>("search_query") ?: ""
                    executeJsonMethod({ Gobackend.getLocalLibraryCount(searchQuery).toString() }, result)
                }
                "getLocalLibraryAlbumGroups" -> {
                    val limit = (call.argument<Int>("limit") ?: 50).toLong()
                    val offset = (call.argument<Int>("offset") ?: 0).toLong()
                    val searchQuery = call.argument<String>("searchQuery") ?: call.argument<String>("search_query") ?: ""
                    executeJsonMethod({ Gobackend.getLocalLibraryAlbumGroups(limit, offset, searchQuery) }, result)
                }
                "getLocalLibraryAlbumGroupCount" -> {
                    val searchQuery = call.argument<String>("searchQuery") ?: call.argument<String>("search_query") ?: ""
                    executeJsonMethod({ Gobackend.getLocalLibraryAlbumGroupCount(searchQuery).toString() }, result)
                }
                "getLocalLibrarySingleTrackCount" -> {
                    val searchQuery = call.argument<String>("searchQuery") ?: call.argument<String>("search_query") ?: ""
                    executeJsonMethod({ Gobackend.getLocalLibrarySingleTrackCount(searchQuery).toString() }, result)
                }
                "getLocalLibraryArtistTracks" -> {
                    val artist = call.argument<String>("artist") ?: ""
                    executeJsonMethod({ Gobackend.getLocalLibraryArtistTracks(artist) }, result)
                }
                "getLocalLibraryAlbumTracks" -> {
                    val album = call.argument<String>("album") ?: ""
                    val artist = call.argument<String>("artist") ?: ""
                    executeJsonMethod({ Gobackend.getLocalLibraryAlbumTracks(album, artist) }, result)
                }
                "getLocalLibraryEntriesWithPathsPage" -> {
                    val limit = (call.argument<Int>("limit") ?: 100000).toLong()
                    val offset = (call.argument<Int>("offset") ?: 0).toLong()
                    executeJsonMethod({ Gobackend.getLocalLibraryEntriesWithPathsPage(limit, offset) }, result)
                }
                "getLocalLibraryCoverPaths" -> {
                    executeJsonMethod({ Gobackend.getLocalLibraryCoverPaths() }, result)
                }
                "getLocalLibraryEntryByID" -> {
                    val id = call.argument<String>("id") ?: ""
                    executeJsonMethod({ Gobackend.getLocalLibraryEntryByID(id) }, result)
                }
                "getLocalLibraryEntryByIsrc" -> {
                    val isrc = call.argument<String>("isrc") ?: ""
                    executeJsonMethod({ Gobackend.getLocalLibraryEntryByIsrc(isrc) }, result)
                }
                "getLocalLibraryEntryByISRC" -> {
                    val isrc = call.argument<String>("request") ?: ""
                    executeJsonMethod({ Gobackend.getLocalLibraryEntryByIsrc(isrc) }, result)
                }
                "findLocalLibraryEntryByTrackAndArtist" -> {
                    val trackName = call.argument<String>("track_name") ?: ""
                    val artistName = call.argument<String>("artist_name") ?: ""
                    executeJsonMethod({ Gobackend.findLocalLibraryEntryByTrackAndArtist(trackName, artistName) }, result)
                }
                "updateLocalLibraryFileModTimes" -> {
                    val entriesJson = call.argument<String>("entries") ?: ""
                    executeJsonMethod({ Gobackend.updateLocalLibraryFileModTimes(entriesJson); "ok" }, result)
                }
                "updateLocalLibraryAudioMetadata" -> {
                    val requestJson = call.argument<String>("request") ?: ""
                    executeJsonMethod({ Gobackend.updateLocalLibraryAudioMetadata(requestJson); "ok" }, result)
                }
                "deleteLocalLibraryEntriesByPaths" -> {
                    val requestJson = call.argument<String>("request") ?: ""
                    executeJsonMethod({ Gobackend.deleteLocalLibraryEntriesByPathsJSON(requestJson); "ok" }, result)
                }
                "upsertLocalLibraryEntry" -> {
                    val requestJson = call.argument<String>("request") ?: ""
                    executeJsonMethod({ Gobackend.upsertLocalLibraryEntryJSON(requestJson); "ok" }, result)
                }
                "deleteLocalLibraryEntryByID" -> {
                    val id = call.argument<String>("id") ?: ""
                    executeJsonMethod({ Gobackend.deleteLocalLibraryEntryByID(id); "ok" }, result)
                }
                "clearLocalLibrary" -> {
                    executeJsonMethod({ Gobackend.clearLocalLibrary(); "ok" }, result)
                }
                "cleanupLocalLibraryMissingFiles" -> {
                    val requestJson = call.argument<String>("request") ?: "[]"
                    executeJsonMethod({ Gobackend.cleanupLocalLibraryMissingFiles(requestJson).toString() }, result)
                }
                "replaceLocalLibraryConvertedItem" -> {
                    val requestJson = call.argument<String>("request") ?: ""
                    executeJsonMethod({ Gobackend.replaceLocalLibraryConvertedItem(requestJson); "ok" }, result)
                }

                // --- Download Management ---
                "initItemProgress" -> {
                    val itemId = call.argument<String>("item_id") ?: ""
                    executeJsonMethod({ Gobackend.initItemProgress(itemId); "ok" }, result)
                }
                "finishItemProgress" -> {
                    val itemId = call.argument<String>("item_id") ?: ""
                    executeJsonMethod({ Gobackend.finishItemProgress(itemId); "ok" }, result)
                }
                "clearItemProgress" -> {
                    val itemId = call.argument<String>("item_id") ?: ""
                    executeJsonMethod({ Gobackend.clearItemProgress(itemId); "ok" }, result)
                }
                "cancelDownload" -> {
                    val itemId = call.argument<String>("item_id") ?: ""
                    executeJsonMethod({ Gobackend.cancelDownload(itemId); "ok" }, result)
                }
                "setDownloadDirectory" -> {
                    val path = call.argument<String>("path") ?: ""
                    executeJsonMethod({ Gobackend.setDownloadDirectory(path); "ok" }, result)
                }
                "getDownloadProgress" -> {
                    executeJsonMethod({ Gobackend.getDownloadProgress() }, result)
                }
                "getAllDownloadProgress" -> {
                    executeJsonMethod({ Gobackend.getAllDownloadProgress() }, result)
                }
                "buildFilename" -> {
                    val trackJson = call.argument<String>("track_json") ?: ""
                    val format = call.argument<String>("format") ?: ""
                    executeJsonMethod({ Gobackend.buildFilename(trackJson, format) }, result)
                }
                "sanitizeFilename" -> {
                    val filename = call.arguments as? String ?: ""
                    executeJsonMethod({ Gobackend.sanitizeFilename(filename) }, result)
                }
                "checkDuplicate" -> {
                    val trackJson = call.argument<String>("track_json") ?: ""
                    val directory = call.argument<String>("directory") ?: ""
                    executeJsonMethod({ Gobackend.checkDuplicate(trackJson, directory) }, result)
                }
                // Native Download Worker functions - don't exist in Go backend
                // (Download handling is done via different mechanism)

                "getAllPendingFFmpegCommands" -> {
                    executeJsonMethod({ Gobackend.getAllPendingFFmpegCommandsJSON() }, result)
                }
                "getPendingFFmpegCommand" -> {
                    val commandId = call.arguments as? String ?: ""
                    executeJsonMethod({ Gobackend.getPendingFFmpegCommandJSON(commandId) }, result)
                }
                "setFFmpegCommandResult" -> {
                    val commandId = call.argument<String>("command_id") ?: ""
                    val success = call.argument<Boolean>("success") ?: false
                    val output = call.argument<String>("output") ?: ""
                    val errorMsg = call.argument<String>("error_msg") ?: ""
                    Gobackend.setFFmpegCommandResultByID(commandId, success, output, errorMsg)
                    result.success("ok")
                }

                // Download Service functions - don't exist in Go backend

                // --- Audio & Metadata ---
                "readAudioMetadata" -> {
                    val filePath = call.arguments as? String ?: ""
                    executeJsonMethod({ Gobackend.readAudioMetadata(filePath) }, result)
                }
                "readFileMetadata" -> {
                    val filePath = call.argument<String>("file_path") ?: ""
                    executeJsonMethod({ Gobackend.readFileMetadata(filePath) }, result)
                }
                // editFileMetadata, reEnrichFile, rewriteSplitArtistTags - different signatures or don't exist

                // Audio metadata & cover functions - have different signatures in Go (return errors, not strings)
                // extractCoverToFile, downloadCoverToFile return errors not strings
                // fetchLyrics, getLyricsLRC, etc. require many parameters (spotifyID, trackName, artistName, durationMs, etc.)
                // These should be called with proper JSON wrappers from Dart

                // convertSpotifyToDeezer - different signature in Go (needs resourceType, spotifyID)

                // Library scan cancel/progress - use JSON versions
                "cancelLibraryScan" -> {
                    Gobackend.cancelLibraryScan()
                    result.success("ok")
                }
                "getLibraryScanProgress" -> {
                    executeJsonMethod({ Gobackend.getLibraryScanProgress() }, result)
                }

                // --- Library Scan ---
                "scanLibraryFolder" -> {
                    val folderPath = call.argument<String>("folder_path") ?: ""
                    executeJsonMethod({ Gobackend.scanLibraryFolder(folderPath) }, result)
                }
                "scanLibraryFolderIncremental" -> {
                    val folderPath = call.argument<String>("folder_path") ?: ""
                    val existingFilesJson = call.argument<String>("existing_files") ?: "{}"
                    executeJsonMethod({ Gobackend.scanLibraryFolderIncremental(folderPath, existingFilesJson) }, result)
                }
                "scanLibraryFolderIncrementalFromSnapshot" -> {
                    val folderPath = call.argument<String>("folder_path") ?: ""
                    val snapshotJson = call.argument<String>("snapshot") ?: ""
                    executeJsonMethod({ Gobackend.scanLibraryFolderIncrementalFromSnapshot(folderPath, snapshotJson) }, result)
                }
                "cancelLibraryScan" -> {
                    Gobackend.cancelLibraryScan()
                    result.success("ok")
                }
                "getLibraryScanProgress" -> {
                    executeJsonMethod({ Gobackend.getLibraryScanProgress() }, result)
                }
                "setLibraryCoverCacheDir" -> {
                    val cacheDir = call.arguments as? String ?: ""
                    Gobackend.setLibraryCoverCacheDirJSON(cacheDir)
                    result.success("ok")
                }

                // preWarmTrackCache, clearTrackCache, getTrackCacheSize - different signatures in Go (need JSON params)

                // --- Logging ---
                "setLoggingEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    Gobackend.setLoggingEnabled(enabled)
                    result.success("ok")
                }
                "getLogCount" -> {
                    executeJsonMethod({ Gobackend.getLogCount().toString() }, result)
                }
                "clearLogs" -> {
                    executeJsonMethod({ Gobackend.clearLogs(); "ok" }, result)
                }

                // --- Extension Helpers ---
                // Extension Helper functions - most have different signatures in Go (need JSON suffix)
                // checkExtensionHealth -> checkExtensionHealthJSON
                "checkExtensionHealth" -> {
                    val extensionId = call.argument<String>("extension_id") ?: ""
                    executeJsonMethod({ Gobackend.checkExtensionHealthJSON(extensionId) }, result)
                }

                "cleanupExtensions" -> {
                    Gobackend.cleanupExtensions()
                    result.success("ok")
                }
                "cleanupConnections" -> {
                    Gobackend.cleanupConnections()
                    result.success("ok")
                }

                // getExtensionBrowseCategories, getExtensionHomeFeed - need extension_id parameter
                "getExtensionBrowseCategories" -> {
                    val extensionId = call.argument<String>("extension_id") ?: ""
                    executeJsonMethod({ Gobackend.getExtensionBrowseCategoriesJSON(extensionId) }, result)
                }
                "getExtensionHomeFeed" -> {
                    val extensionId = call.argument<String>("extension_id") ?: ""
                    executeJsonMethod({ Gobackend.getExtensionHomeFeedJSON(extensionId) }, result)
                }

                // customSearchWithExtension - different signature in Go
                "customSearchWithExtension" -> {
                    val extensionId = call.argument<String>("extension_id") ?: ""
                    val query = call.argument<String>("query") ?: ""
                    val paramsJson = call.argument<String>("params") ?: "{}"
                    executeJsonMethod({ Gobackend.customSearchWithExtensionJSON(extensionId, query, paramsJson) }, result)
                }

                // searchTracksWithExtensions - different signature in Go
                "handleURLWithExtension" -> {
                    val url = call.argument<String>("url") ?: ""
                    executeJsonMethod({ Gobackend.handleURLWithExtensionJSON(url) }, result)
                }
                "findURLHandler" -> {
                    val url = call.arguments as? String ?: ""
                    executeJsonMethod({ Gobackend.findURLHandlerJSON(url) }, result)
                }
                "getURLHandlers" -> {
                    executeJsonMethod({ Gobackend.getURLHandlersJSON() }, result)
                }
                "getSearchProviders" -> {
                    executeJsonMethod({ Gobackend.getSearchProvidersJSON() }, result)
                }

                // --- SAF & Storage Utils ---
                "pickSafTree" -> {
                    // Launch native Android SAF folder picker
                    pickSafTreeNative(result)
                }
                "ensureYtDlp" -> {
                    executeJsonMethod({ Gobackend.ensureYtDlpJSON() }, result)
                }
                "checkAvailability" -> {
                    val spotifyId = call.argument<String>("spotify_id") ?: ""
                    val isrc = call.argument<String>("isrc") ?: ""
                    executeJsonMethod({ Gobackend.checkAvailability(spotifyId, isrc) }, result)
                }
                "bootstrapEssentialExtensions" -> {
                    android.util.Log.i("NativeBridge", "Starting bootstrap of essential extensions...")
                    executeJsonMethod({
                        val bootstrapResult = Gobackend.bootstrapEssentialExtensions()
                        android.util.Log.i("NativeBridge", "Bootstrap result: $bootstrapResult")
                        bootstrapResult
                    }, result)
                }
                // --- Lyrics Fetch Methods ---
                "getLyricsLRC" -> {
                    val spotifyID = call.argument<String>("spotify_id") ?: ""
                    val trackName = call.argument<String>("track_name") ?: ""
                    val artistName = call.argument<String>("artist_name") ?: ""
                    val filePath = call.argument<String>("file_path") ?: ""
                    val durationMs = call.argument<Int>("duration_ms")?.toLong() ?: 0L
                    executeJsonMethod({ Gobackend.getLyricsLRC(spotifyID, trackName, artistName, filePath, durationMs) }, result)
                }
                "getLyricsLRCWithSource" -> {
                    val spotifyID = call.argument<String>("spotify_id") ?: ""
                    val trackName = call.argument<String>("track_name") ?: ""
                    val artistName = call.argument<String>("artist_name") ?: ""
                    val filePath = call.argument<String>("file_path") ?: ""
                    val durationMs = call.argument<Int>("duration_ms")?.toLong() ?: 0L
                    executeJsonMethod({ Gobackend.getLyricsLRCWithSource(spotifyID, trackName, artistName, filePath, durationMs) }, result)
                }
                "getTranslatedLyricsLRC" -> {
                    val spotifyID = call.argument<String>("spotify_id") ?: ""
                    val trackName = call.argument<String>("track_name") ?: ""
                    val artistName = call.argument<String>("artist_name") ?: ""
                    val durationMs = call.argument<Int>("duration_ms")?.toLong() ?: 0L
                    val language = call.argument<String>("language") ?: ""
                    executeJsonMethod({ Gobackend.getTranslatedLyricsLRC(spotifyID, trackName, artistName, durationMs, language) }, result)
                }
                "setTranslationLanguageJSON" -> {
                    val language = call.argument<String>("language") ?: "es"
                    executeJsonMethod({ Gobackend.setTranslationLanguageJSON(language); "ok" }, result)
                }
                "getTranslationLanguageJSON" -> {
                    executeJsonMethod({ Gobackend.getTranslationLanguageJSON() }, result)
                }
                "fetchLyrics" -> {
                    val spotifyID = call.argument<String>("spotify_id") ?: ""
                    val trackName = call.argument<String>("track_name") ?: ""
                    val artistName = call.argument<String>("artist_name") ?: ""
                    val durationMs = call.argument<Int>("duration_ms")?.toLong() ?: 0L
                    executeJsonMethod({ Gobackend.fetchLyrics(spotifyID, trackName, artistName, durationMs) }, result)
                }
                "embedLyricsToFile" -> {
                    val filePath = call.argument<String>("file_path") ?: ""
                    val lyrics = call.argument<String>("lyrics") ?: ""
                    executeJsonMethod({ Gobackend.embedLyricsToFile(filePath, lyrics) }, result)
                }
                "fetchAndSaveLyrics" -> {
                    val trackName = call.argument<String>("track_name") ?: ""
                    val artistName = call.argument<String>("artist_name") ?: ""
                    val spotifyID = call.argument<String>("spotify_id") ?: ""
                    val durationMs = call.argument<Int>("duration_ms")?.toLong() ?: 0L
                    val outputPath = call.argument<String>("output_path") ?: ""
                    val audioFilePath = call.argument<String>("audio_file_path") ?: ""
                    executor.execute {
                        try {
                            Gobackend.fetchAndSaveLyrics(trackName, artistName, spotifyID, durationMs, outputPath, audioFilePath)
                            handler.post { result.success("ok") }
                        } catch (e: Exception) {
                            handler.post { result.error("BACKEND_ERROR", e.message, null) }
                        }
                    }
                }
                "getDeezerExtendedMetadata" -> {
                    val trackId = call.argument<String>("track_id") ?: ""
                    executeJsonMethod({ Gobackend.getDeezerExtendedMetadata(trackId) }, result)
                }
                "startDownloadService" -> {
                    android.util.Log.i("NativeBridge", "startDownloadService called (stub)")
                    result.success("ok")
                }
                "stopDownloadService" -> {
                    android.util.Log.i("NativeBridge", "stopDownloadService called (stub)")
                    result.success("ok")
                }

                // --- Methods missing from Android bridge (added for parity) ---
                "clearTrackCache" -> {
                    Gobackend.clearTrackCache()
                    result.success("ok")
                }
                "convertSpotifyToDeezer" -> {
                    val resourceType = call.argument<String>("resource_type") ?: ""
                    val spotifyId = call.argument<String>("spotify_id") ?: ""
                    executeJsonMethod({ Gobackend.convertSpotifyToDeezer(resourceType, spotifyId) }, result)
                }
                "downloadCoverToFile" -> {
                    val coverUrl = call.argument<String>("cover_url") ?: ""
                    val outputPath = call.argument<String>("output_path") ?: ""
                    val maxQuality = call.argument<Boolean>("max_quality") ?: false
                    executeJsonMethod({ Gobackend.downloadCoverToFile(coverUrl, outputPath, maxQuality); "ok" }, result)
                }
                "editFileMetadata" -> {
                    val filePath = call.argument<String>("file_path") ?: ""
                    val metadataJson = call.argument<String>("metadata_json") ?: ""
                    executeJsonMethod({ Gobackend.editFileMetadata(filePath, metadataJson) }, result)
                }
                "extractCoverToFile" -> {
                    val audioPath = call.argument<String>("audio_path") ?: ""
                    val outputPath = call.argument<String>("output_path") ?: ""
                    executeJsonMethod({ Gobackend.extractCoverToFile(audioPath, outputPath); "ok" }, result)
                }
                "getAllPendingAuthRequests" -> {
                    executeJsonMethod({ Gobackend.getAllPendingAuthRequestsJSON() }, result)
                }
                "getDeezerRelatedArtists" -> {
                    val artistId = call.argument<String>("artist_id") ?: ""
                    val limit = (call.argument<Int>("limit") ?: 20).toLong()
                    executeJsonMethod({ Gobackend.getDeezerRelatedArtists(artistId, limit) }, result)
                }
                "getPostProcessingProviders" -> {
                    executeJsonMethod({ Gobackend.getPostProcessingProvidersJSON() }, result)
                }
                "getTrackCacheSize" -> {
                    executeJsonMethod({ Gobackend.getTrackCacheSize().toString() }, result)
                }
                "playbackClearQueue" -> {
                    executeJsonMethod({ Gobackend.playbackClearQueue() }, result)
                }
                "playbackRemoveFromQueue" -> {
                    val index = call.argument<Int>("index") ?: 0
                    executeJsonMethod({ Gobackend.playbackRemoveFromQueue(index.toLong()) }, result)
                }
                "playbackUpdatePosition" -> {
                    val positionMs = (call.argument<Int>("position_ms") ?: 0).toLong()
                    Gobackend.playbackUpdatePosition(positionMs)
                    result.success("ok")
                }
                "preWarmTrackCache" -> {
                    val tracksJson = call.argument<String>("tracks") ?: ""
                    executeJsonMethod({ Gobackend.preWarmTrackCacheJSON(tracksJson) }, result)
                }
                "reEnrichFile" -> {
                    val requestJson = call.argument<String>("request_json") ?: ""
                    executeJsonMethod({ Gobackend.reEnrichFile(requestJson) }, result)
                }
                "removeExtension" -> {
                    val extensionId = call.argument<String>("extension_id") ?: ""
                    executeJsonMethod({ Gobackend.removeExtensionByID(extensionId); "ok" }, result)
                }
                "rewriteSplitArtistTags" -> {
                    val filePath = call.argument<String>("file_path") ?: ""
                    val artist = call.argument<String>("artist") ?: ""
                    val albumArtist = call.argument<String>("album_artist") ?: ""
                    executeJsonMethod({ Gobackend.rewriteSplitArtistTagsExport(filePath, artist, albumArtist) }, result)
                }
                "runPostProcessing" -> {
                    val filePath = call.argument<String>("file_path") ?: ""
                    val metadataJson = call.argument<String>("metadata") ?: ""
                    executeJsonMethod({ Gobackend.runPostProcessingJSON(filePath, metadataJson) }, result)
                }
                "runPostProcessingV2" -> {
                    val inputJson = call.argument<String>("input") ?: ""
                    val metadataJson = call.argument<String>("metadata") ?: ""
                    executeJsonMethod({ Gobackend.runPostProcessingV2JSON(inputJson, metadataJson) }, result)
                }
                "scanSafTreeIncremental" -> {
                    val folderPath = call.argument<String>("tree_uri") ?: ""
                    val existingFilesJson = call.argument<String>("existing_files") ?: "{}"
                    executeJsonMethod({ Gobackend.scanLibraryFolderIncrementalJSON(folderPath, existingFilesJson) }, result)
                }
                "scanSafTreeIncrementalFromSnapshot" -> {
                    val folderPath = call.argument<String>("tree_uri") ?: ""
                    val snapshotPath = call.argument<String>("snapshot_path") ?: ""
                    executeJsonMethod({ Gobackend.scanLibraryFolderIncrementalFromSnapshotJSON(folderPath, snapshotPath) }, result)
                }
                "searchDeezerByISRC" -> {
                    val isrc = call.argument<String>("isrc") ?: ""
                    executeJsonMethod({ Gobackend.searchDeezerByISRC(isrc) }, result)
                }
                "searchTracksWithExtensions" -> {
                    val query = call.argument<String>("query") ?: ""
                    val limit = (call.argument<Int>("limit") ?: 20)
                    executeJsonMethod({ Gobackend.searchTracksWithMetadataProvidersJSON(query, limit.toLong(), true) }, result)
                }
                "unloadExtension" -> {
                    val extensionId = call.argument<String>("extension_id") ?: ""
                    executeJsonMethod({ Gobackend.unloadExtensionByID(extensionId); "ok" }, result)
                }
                "upgradeExtension" -> {
                    val filePath = call.argument<String>("file_path") ?: ""
                    executeJsonMethod({ Gobackend.upgradeExtensionFromPath(filePath) }, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun executeJsonMethod(action: () -> String, result: MethodChannel.Result) {
        executor.execute {
            try {
                val res = action()
                handler.post { result.success(res) }
            } catch (e: Exception) {
                // Si falla por "method not found", probamos con CamelCase o damos error detallado
                handler.post { result.error("BACKEND_ERROR", e.message, null) }
            }
        }
    }

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

    // --- SAF Tree Picker Native Implementation ---
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
                    // Persist permission across reboots
                    contentResolver.takePersistableUriPermission(
                        treeUri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    )

                    // Get display name
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
                // User cancelled
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
                null,
                null,
                null
            )
            cursor?.use {
                if (it.moveToFirst()) {
                    val nameIndex = it.getColumnIndexOrThrow(android.provider.DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                    it.getString(nameIndex)
                } else "Unknown"
            } ?: "Unknown"
        } catch (e: Exception) {
            "Unknown"
        }
    }
}
