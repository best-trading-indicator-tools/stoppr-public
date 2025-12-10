package com.stoppr.sugar.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.*
import android.net.Uri
import android.os.Bundle
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class AccountabilityWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val hasPartner = widgetData.getBoolean("accountability_has_partner", false)
            
            val views = if (!hasPartner) {
                // Show "no partner" message
                RemoteViews(context.packageName, R.layout.accountability_widget_no_partner_layout).apply {
                    val intent = Intent(context, MainActivity::class.java).apply {
                        action = Intent.ACTION_VIEW
                        data = Uri.parse("stoppr://accountability")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                    }
                    val pendingIntent = PendingIntent.getActivity(
                        context,
                        widgetId,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                }
            } else {
                // Show partner data
                RemoteViews(context.packageName, R.layout.accountability_widget_layout).apply {
                    val myName = widgetData.getString("accountability_my_name", "Me") ?: "Me"
                    val myDays = widgetData.getInt("accountability_my_days", 0)
                    val myPercentage = widgetData.getInt("accountability_my_percentage", 0)
                    
                    val partnerName = widgetData.getString("accountability_partner_name", "Partner") ?: "Partner"
                    val partnerDays = widgetData.getInt("accountability_partner_days", 0)
                    val partnerPercentage = widgetData.getInt("accountability_partner_percentage", 0)
                    
                    val localizedTitle = widgetData.getString("accountability_localized_title", "RECOVERY") ?: "RECOVERY"
                    val localizedDaysSuffix = widgetData.getString("accountability_localized_days_suffix", "Days") ?: "Days"
                    
                    setTextViewText(R.id.tv_my_name, myName)
                    setTextViewText(R.id.tv_my_title, localizedTitle.uppercase())
                    setTextViewText(R.id.tv_my_percentage, "$myPercentage%")
                    setTextViewText(R.id.tv_my_days, "$myDays $localizedDaysSuffix")
                    
                    setTextViewText(R.id.tv_partner_name, partnerName)
                    setTextViewText(R.id.tv_partner_title, localizedTitle.uppercase())
                    setTextViewText(R.id.tv_partner_percentage, "$partnerPercentage%")
                    setTextViewText(R.id.tv_partner_days, "$partnerDays $localizedDaysSuffix")
                    
                    val intent = Intent(context, MainActivity::class.java).apply {
                        action = Intent.ACTION_VIEW
                        data = Uri.parse("stoppr://accountability")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                    }
                    val pendingIntent = PendingIntent.getActivity(
                        context,
                        widgetId,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                }
            }
            
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        val widgetData = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId), widgetData)
    }
}

