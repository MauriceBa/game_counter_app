package com.maurice.game_counter_app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import java.io.IOException

object RadioPlayerManager {
    private const val PREFS_NAME = "RadioWidgetPrefs"
    private const val PREF_IS_PLAYING = "is_playing"
    private const val STREAM_URL = "https://hosting.studioradiomedia.fr:1705/stream"
    
    private var mediaPlayer: MediaPlayer? = null
    private val listeners = mutableListOf<() -> Unit>()
    
    fun isPlaying(context: Context): Boolean {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(PREF_IS_PLAYING, false)
    }
    
    fun togglePlayPause(context: Context) {
        if (isPlaying(context)) {
            stop(context)
        } else {
            play(context)
        }
    }
    
    private fun play(context: Context) {
        Handler(Looper.getMainLooper()).post {
            try {
                if (mediaPlayer == null) {
                    mediaPlayer = MediaPlayer().apply {
                        setDataSource(STREAM_URL)
                        setOnPreparedListener { 
                            start()
                            setPlayingState(context, true)
                        }
                        setOnErrorListener { _, _, _ ->
                            setPlayingState(context, false)
                            true
                        }
                        setOnCompletionListener {
                            setPlayingState(context, false)
                        }
                        prepareAsync()
                    }
                } else {
                    mediaPlayer?.start()
                    setPlayingState(context, true)
                }
            } catch (e: IOException) {
                e.printStackTrace()
                setPlayingState(context, false)
            }
        }
    }
    
    private fun stop(context: Context) {
        mediaPlayer?.pause()
        setPlayingState(context, false)
    }
    
    private fun setPlayingState(context: Context, playing: Boolean) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(PREF_IS_PLAYING, playing)
            .apply()
        
        // Update all widgets
        Handler(Looper.getMainLooper()).post {
            updateAllWidgets(context)
        }
    }
    
    fun updateAllWidgets(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        
        // Update 1x1 widget
        val widget1x1 = ComponentName(context, RadioWidgetProvider::class.java)
        val ids1x1 = appWidgetManager.getAppWidgetIds(widget1x1)
        for (id in ids1x1) {
            RadioWidgetProvider.updateWidget(context, appWidgetManager, id)
        }
        
        // Update 1x2 left widget
        val widget1x2Left = ComponentName(context, RadioWidget1x2LeftProvider::class.java)
        val ids1x2Left = appWidgetManager.getAppWidgetIds(widget1x2Left)
        for (id in ids1x2Left) {
            RadioWidget1x2LeftProvider.updateWidget(context, appWidgetManager, id)
        }
        
        // Update 1x2 right widget
        val widget1x2Right = ComponentName(context, RadioWidget1x2RightProvider::class.java)
        val ids1x2Right = appWidgetManager.getAppWidgetIds(widget1x2Right)
        for (id in ids1x2Right) {
            RadioWidget1x2RightProvider.updateWidget(context, appWidgetManager, id)
        }
    }
}
