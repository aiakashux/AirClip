package com.airclip.airclip.device

import android.content.Context
import android.net.wifi.WifiManager

object WifiNetworkName {
    fun current(context: Context): String? {
        val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            ?: return null
        val raw = wifi.connectionInfo?.ssid ?: return null
        val cleaned = raw.trim('"')
        return cleaned.takeIf {
            it.isNotBlank() &&
                !it.equals("<unknown ssid>", ignoreCase = true) &&
                !it.equals("0x", ignoreCase = true)
        }
    }
}
