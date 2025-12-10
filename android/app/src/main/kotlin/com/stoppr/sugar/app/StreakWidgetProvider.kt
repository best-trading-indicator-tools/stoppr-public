package com.stoppr.sugar.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Calendar
import java.util.Date

class StreakWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            // Get widget dimensions to adjust display for different sizes
            val widgetOptions = appWidgetManager.getAppWidgetOptions(widgetId)
            val isLargeWidget = isLargeWidget(widgetOptions)
            
            val views = RemoteViews(context.packageName, R.layout.streak_widget_layout).apply {

                // Get data from SharedPreferences
                val timestamp = widgetData.getLong("streak_start_timestamp", 0L)
                val localizedLabel = widgetData.getString("widget_localized_label_sugar_free_since", "Sugar-free since:")
                val hasActiveSubscription = widgetData.getBoolean("widget_has_active_subscription", false)
                val subscribePrompt = widgetData.getString("widget_subscribeToTrackStreak", "Subscribe to\ntrack your streak")
                
                // Debug logging
                android.util.Log.d("StreakWidget", "Timestamp from prefs: $timestamp")
                android.util.Log.d("StreakWidget", "Has subscription: $hasActiveSubscription")
                
                // Show/hide views based on subscription status
                if (hasActiveSubscription) {
                    // Show streak counter for paid users
                    setViewVisibility(R.id.ll_streak_content, View.VISIBLE)
                    setViewVisibility(R.id.ll_subscription_prompt, View.GONE)
                    
                    // Adjust font sizes based on widget size
                    if (isLargeWidget) {
                        setTextViewTextSize(R.id.tv_localized_label, TypedValue.COMPLEX_UNIT_SP, 20f)
                        setTextViewTextSize(R.id.tv_days_value, TypedValue.COMPLEX_UNIT_SP, 50f)
                        setTextViewTextSize(R.id.tv_days_label, TypedValue.COMPLEX_UNIT_SP, 24f)
                        setTextViewTextSize(R.id.tv_hours_minutes_value_large, TypedValue.COMPLEX_UNIT_SP, 48f)
                        setTextViewTextSize(R.id.tv_minutes_value_large, TypedValue.COMPLEX_UNIT_SP, 48f)
                        setTextViewTextSize(R.id.tv_hours_minutes_secondary, TypedValue.COMPLEX_UNIT_SP, 22f)
                    }
                    
                    setTextViewText(R.id.tv_localized_label, localizedLabel)

                    val startTime = if (timestamp == 0L) null else Date(timestamp)
                    val duration = calculateDuration(startTime)

                    // Reset visibility
                    setViewVisibility(R.id.ll_days_display, View.GONE)
                    setViewVisibility(R.id.tv_hours_minutes_value_large, View.GONE)
                    setViewVisibility(R.id.tv_minutes_value_large, View.GONE)
                    setViewVisibility(R.id.tv_hours_minutes_secondary, View.GONE)

                    if (duration.days > 0) {
                        setViewVisibility(R.id.ll_days_display, View.VISIBLE)
                        setTextViewText(R.id.tv_days_value, duration.days.toString())
                        val daysLabel = if (duration.days > 1) context.getString(R.string.streak_days_suffix) else context.getString(R.string.streak_day_suffix_singular)
                        setTextViewText(R.id.tv_days_label, daysLabel)

                        setViewVisibility(R.id.tv_hours_minutes_secondary, View.VISIBLE)
                        val hoursAbbrev = context.getString(R.string.streak_hours_abbrev)
                        val minutesAbbrev = context.getString(R.string.streak_minutes_abbrev)
                        setTextViewText(R.id.tv_hours_minutes_secondary, "${duration.hours}$hoursAbbrev ${duration.minutes}$minutesAbbrev")
                    } else if (duration.hours > 0) {
                        setViewVisibility(R.id.tv_hours_minutes_value_large, View.VISIBLE)
                        val hoursAbbrev2 = context.getString(R.string.streak_hours_abbrev)
                        val minutesAbbrev2 = context.getString(R.string.streak_minutes_abbrev)
                        setTextViewText(R.id.tv_hours_minutes_value_large, "${duration.hours}$hoursAbbrev2 ${duration.minutes}$minutesAbbrev2")
                        // No secondary seconds display in this case, matching iOS
                    } else {
                        setViewVisibility(R.id.tv_minutes_value_large, View.VISIBLE)
                        val minutesAbbrev3 = context.getString(R.string.streak_minutes_abbrev)
                        setTextViewText(R.id.tv_minutes_value_large, "${duration.minutes}$minutesAbbrev3")
                        // No secondary seconds display in this case, matching iOS
                    }
                } else {
                    // Show subscription prompt for free users
                    setViewVisibility(R.id.ll_streak_content, View.GONE)
                    setViewVisibility(R.id.ll_subscription_prompt, View.VISIBLE)
                    setTextViewText(R.id.tv_subscribe_prompt, subscribePrompt)
                }

                // Create an Intent to launch MainActivity when the widget is clicked
                // Using stoppr://home URI to potentially navigate to a specific screen
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("stoppr://home")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                }
                val pendingIntent = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
    
    override fun onAppWidgetOptionsChanged(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, newOptions: Bundle) {
        // When the widget is resized, update it
        val widgetData = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId), widgetData)
    }
    
    private fun isLargeWidget(options: Bundle): Boolean {
        // Consider widget "large" if it takes up more than 2x2 cells or is at least 220dp in either dimension
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        
        return minWidth >= 220 || minHeight >= 220
    }

    private fun calculateDuration(startTime: Date?): DurationParts {
        if (startTime == null) return DurationParts(0, 0, 0, 0)
        
        val now = Calendar.getInstance().time
        if (now.before(startTime)) return DurationParts(0,0,0,0)

        var diffInMillis = now.time - startTime.time

        val days = (diffInMillis / (1000 * 60 * 60 * 24)).toInt()
        diffInMillis %= (1000 * 60 * 60 * 24)

        val hours = (diffInMillis / (1000 * 60 * 60)).toInt()
        diffInMillis %= (1000 * 60 * 60)

        val minutes = (diffInMillis / (1000 * 60)).toInt()
        diffInMillis %= (1000 * 60)
        
        val seconds = (diffInMillis / 1000).toInt()

        return DurationParts(days, hours, minutes, seconds)
    }

    private data class DurationParts(val days: Int, val hours: Int, val minutes: Int, val seconds: Int)
} 