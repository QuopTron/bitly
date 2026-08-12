package com.example.bitly

import android.util.Log

private const val TAG = "YouTubeService"

/**
 * YouTube search/download is now handled by the Go provider system
 * via the generic dispatch in MainActivity.kt.
 *
 * The Go backend's youtube provider uses yt-dlp internally
 * to search and download from YouTube Music.
 *
 * This file exists for native Android-specific YouTube operations
 * that require the YouTube Data API (not yet implemented).
 */
object YouTubeService {
    fun searchYouTubeVideo(trackName: String, artistName: String): String? {
        Log.d(TAG, "searchYouTubeVideo called for: $trackName - $artistName")
        Log.w(TAG, "YouTube search is handled by Go backend provider. Return null for fallback.")
        return null
    }

    fun downloadYouTubeVideo(trackName: String, artistName: String, outputPath: String): String? {
        Log.d(TAG, "downloadYouTubeVideo called for: $trackName - $artistName -> $outputPath")
        Log.w(TAG, "YouTube download is handled by Go backend provider. Return null for fallback.")
        return null
    }
}
