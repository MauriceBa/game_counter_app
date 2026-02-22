package com.maurice.game_counter_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import android.widget.RemoteViews

class RadioWidget1x2RightProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_PLAY_PAUSE = "com.maurice.game_counter_app.RADIO_PLAY_PAUSE_1x2R"
        
        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.radio_widget_1x2_right)
            
            val isPlaying = RadioPlayerManager.isPlaying(context)
            
            // Set icon based on playing state
            val iconRes = if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
            views.setImageViewResource(R.id.widget_play_button, iconRes)

            // Play/Pause button intent
            val playIntent = Intent(context, RadioWidget1x2RightProvider::class.java).apply {
                action = ACTION_PLAY_PAUSE
            }
            val playPendingIntent = PendingIntent.getBroadcast(
                context, 0, playIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_play_button, playPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
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
            RadioPlayerManager.togglePlayPause(context)
        }
    }
}
