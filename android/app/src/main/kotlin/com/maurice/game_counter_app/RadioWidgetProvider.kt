package com.maurice.game_counter_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import android.widget.RemoteViews
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import java.io.IOException

class RadioWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_PLAY_PAUSE = "com.maurice.game_counter_app.RADIO_PLAY_PAUSE"
        private const val PREFS_NAME = "RadioWidgetPrefs"
        private const val PREF_IS_PLAYING = "is_playing"
        
        private var mediaPlayer: MediaPlayer? = null
        private const val STREAM_URL = "https://hosting.studioradiomedia.fr:1705/stream"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val views = RemoteViews(context.packageName, R.layout.radio_widget)
        
        // Get current playing state
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isPlaying = prefs.getBoolean(PREF_IS_PLAYING, false)
        
        // Update button icon based on state (Play or Pause)
        val iconRes = if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
        views.setImageViewResource(R.id.widget_play_button, iconRes)

        // Play/Pause button intent
        val playIntent = Intent(context, RadioWidgetProvider::class.java).apply {
            action = ACTION_PLAY_PAUSE
        }
        val playPendingIntent = PendingIntent.getBroadcast(
            context, 0, playIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_play_button, playPendingIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_PLAY_PAUSE) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val isPlaying = prefs.getBoolean(PREF_IS_PLAYING, false)
            
            if (isPlaying) {
                stopRadio(context)
            } else {
                playRadio(context)
            }
            
            // Update all widgets
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = AppWidgetManager.getInstance(context).getAppWidgetIds(
                android.content.ComponentName(context, RadioWidgetProvider::class.java)
            )
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }
    
    private fun playRadio(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        
        Handler(Looper.getMainLooper()).post {
            try {
                if (mediaPlayer == null) {
                    mediaPlayer = MediaPlayer().apply {
                        setDataSource(STREAM_URL)
                        setOnPreparedListener { start() }
                        setOnErrorListener { _, _, _ ->
                            prefs.edit().putBoolean(PREF_IS_PLAYING, false).apply()
                            true
                        }
                        prepareAsync()
                    }
                } else {
                    mediaPlayer?.start()
                }
                prefs.edit().putBoolean(PREF_IS_PLAYING, true).apply()
            } catch (e: IOException) {
                e.printStackTrace()
                prefs.edit().putBoolean(PREF_IS_PLAYING, false).apply()
            }
        }
    }
    
    private fun stopRadio(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        mediaPlayer?.pause()
        prefs.edit().putBoolean(PREF_IS_PLAYING, false).apply()
    }
}
