package com.example.bitly

import gobackend.Gobackend
import android.util.Log

private const val TAG = "YouTubeService"

object YouTubeService {
    fun searchYouTubeVideo(trackName: String, artistName: String): String? {
        return try {
            val goResult = Gobackend.searchYouTubeVideo(trackName, artistName)
            if (goResult.isNullOrEmpty()) null else goResult
        } catch (e: Exception) {
            Log.e(TAG, "Go search failed", e)
            null
        }
    }

    fun downloadYouTubeVideo(trackName: String, artistName: String, outputPath: String): String? {
        return try {
            val goResult = Gobackend.downloadYouTubeVideo(trackName, artistName, outputPath)
            if (goResult.isNullOrEmpty()) null else goResult
        } catch (e: Exception) {
            Log.e(TAG, "Go download failed", e)
            null
        }
    }
}
