package com.airclip.airclip.pairing

object PairingCompletionPolicy {
    fun shouldMergeIntoExistingNetwork(
        isAlreadyPaired: Boolean,
        currentAirClipId: String?,
        incomingAirClipId: String,
    ): Boolean =
        isAlreadyPaired && currentAirClipId == incomingAirClipId
}
