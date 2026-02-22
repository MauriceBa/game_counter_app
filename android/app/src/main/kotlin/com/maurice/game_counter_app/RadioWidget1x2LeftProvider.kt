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

class RadioWidget1x2LeftProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_PLAY_PAUSE = "com.maurice.game_counter_app.RADIO_PLAY_PAUSE"
        private const val PREFS_NAME = "RadioWidgetPrefs"
        private const val PREF_IS_PLAYING = "is_playing"
        
        @JvmStatic
        private var mediaPlayer: MediaPlayer? = null
        private const val STREAM_URL = "https://hosting.studioradiomedia.fr:1705/stream"
        
        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, RadioWidget1x2LeftProvider::class.java)
            )
            for (appWidgetId in appWidgetIds) {
                updateWidget(context, appWidgetManager, appWidgetId)
            }
            // Also update other widget types
            RadioWidgetProvider.updateAllWidgets(context)
            RadioWidget1x2RightProvider.updateAllWidgets(context)
        }
        
        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.radio_widget_1x2_left)
            
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val isPlaying = prefs.getBoolean(PREF_IS_PLAYING, false)
            
            // Set icon based on playing state
            val iconRes = if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
            views.setImageViewResource(R.id.widget_play_button, iconRes)

            // Play/Pause button intent
            val playIntent = Intent(context, RadioWidget1x2LeftProvider::class.java).apply {
                action = ACTION_PLAY_PAUSE
            }
            val playPendingIntent = PendingIntent.getBroadcast(
                context, 0, playIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_play_button, playPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
        
        fun updateAllWidgetTypes(context: Context) {
            updateAllWidgets(context)
        }
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
        }
    }
    
    private fun playRadio(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        
        Handler(Looper.getMainLooper()).post {
            try {
                if (mediaPlayer == null) {
                    mediaPlayer = MediaPlayer().apply {
                        setDataSource(STREAM_URL)
                        setOnPreparedListener { 
                            start()
                            prefs.edit().putBoolean(PREF_IS_PLAYING, true).apply()
                            updateAllWidgets(context)
                        }
                        setOnErrorListener { _, _, _ ->
                            prefs.edit().putBoolean(PREF_IS_PLAYING, false).apply()
                            updateAllWidgets(context)
                            true
                        }
                        prepareAsync()
                    }
                } else {
                    mediaPlayer?.start()
                    prefs.edit().putBoolean(PREF_IS_PLAYING, true).apply()
                    updateAllWidgets(context)
                }
            } catch (e: IOException) {
                e.printStackTrace()
                prefs.edit().putBoolean(PREF_IS_PLAYING, false).apply()
                updateAllWidgets(context)
            }
        }
    }
    
    private fun stopRadio(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        mediaPlayer?.pause()
        prefs.edit().putBoolean(PREF_IS_PLAYING, false).apply()
        updateAllWidgets(context)
    }
}
