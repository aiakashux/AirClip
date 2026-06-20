package com.airclip.airclip.lan

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

enum class LanRuntimeIssue {
    NONE,
    SERVER_FAILED,
    DISCOVERY_FAILED,
    ADVERTISEMENT_FAILED,
}

data class LanRuntimeDiagnostic(
    val issue: LanRuntimeIssue = LanRuntimeIssue.NONE,
    val detail: String? = null,
) {
    val hasIssue: Boolean
        get() = issue != LanRuntimeIssue.NONE
}

object LanRuntimeDiagnostics {
    private val _state = MutableStateFlow(LanRuntimeDiagnostic())
    val state: StateFlow<LanRuntimeDiagnostic> = _state

    fun clear() {
        _state.value = LanRuntimeDiagnostic()
    }

    fun serverFailed(detail: String?) {
        _state.value = LanRuntimeDiagnostic(LanRuntimeIssue.SERVER_FAILED, detail)
    }

    fun discoveryFailed(detail: String?) {
        _state.value = LanRuntimeDiagnostic(LanRuntimeIssue.DISCOVERY_FAILED, detail)
    }

    fun advertisementFailed(detail: String?) {
        _state.value = LanRuntimeDiagnostic(LanRuntimeIssue.ADVERTISEMENT_FAILED, detail)
    }
}
