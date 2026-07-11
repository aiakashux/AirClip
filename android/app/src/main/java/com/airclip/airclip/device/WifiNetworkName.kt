package com.airclip.airclip.device

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.wifi.WifiManager

object WifiNetworkName {
    enum class UnavailableReason {
        PermissionRequired,
        LocationDisabled,
        Unknown,
    }

    data class Result(
        val name: String?,
        val unavailableReason: UnavailableReason?,
    )

    fun current(context: Context): Result {
        val appContext = context.applicationContext
        if (!hasLocationPermission(appContext)) {
            return Result(name = null, unavailableReason = UnavailableReason.PermissionRequired)
        }
        if (!isLocationEnabled(appContext)) {
            return Result(name = null, unavailableReason = UnavailableReason.LocationDisabled)
        }
        val name = connectedWifiName(appContext) ?: hotspotName(appContext)
        return Result(name = name, unavailableReason = if (name == null) UnavailableReason.Unknown else null)
    }

    fun hasLocationPermission(context: Context): Boolean {
        return context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }

    private fun isLocationEnabled(context: Context): Boolean {
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
            ?: return false
        return runCatching {
            locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        }.getOrDefault(false)
    }

    private fun connectedWifiName(context: Context): String? {
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

    private fun hotspotName(context: Context): String? {
        val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            ?: return null
        return runCatching {
            val config = wifi.javaClass.getMethod("getSoftApConfiguration").invoke(wifi)
            val raw = config?.javaClass?.getMethod("getSsid")?.invoke(config) as? String
            raw?.trim('"')?.takeIf { it.isNotBlank() }
        }.getOrNull()
    }
}
