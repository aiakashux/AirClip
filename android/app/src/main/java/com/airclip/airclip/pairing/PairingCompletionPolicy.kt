package com.airclip.airclip.pairing

object PairingCompletionPolicy {
    fun pairingAirclipId(targetAirclipId: String?, currentAirclipId: String?): String? =
        targetAirclipId?.takeIf(String::isNotBlank) ?: currentAirclipId?.takeIf(String::isNotBlank)

    fun retainedDeviceId(currentDeviceId: String?, generatedDeviceId: String): String =
        currentDeviceId ?: generatedDeviceId

    @Suppress("UNUSED_PARAMETER")
    fun shouldAcceptAuth(isTrusted: Boolean, isPairingSessionActive: Boolean): Boolean = isTrusted

    fun isRemoteDevice(candidateDeviceId: String, currentDeviceId: String?): Boolean =
        candidateDeviceId.isNotBlank() && candidateDeviceId != currentDeviceId

    fun shouldMergeIntoExistingNetwork(
        isAlreadyPaired: Boolean,
        currentAirclipId: String?,
        incomingAirclipId: String,
    ): Boolean =
        isAlreadyPaired && currentAirclipId == incomingAirclipId
}
