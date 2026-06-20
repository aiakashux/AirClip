package com.airclip.airclip

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.airclip.airclip.clipboard.ClipboardMonitor
import com.airclip.airclip.device.PairingState
import com.airclip.airclip.ui.screens.MainScreen
import com.airclip.airclip.ui.screens.OnboardingScreen
import com.airclip.airclip.ui.theme.AirClipBgBase
import com.airclip.airclip.ui.theme.AirClipTheme
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {

    private val viewModel: MainViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Collect clipboard changes while Activity is in RESUMED state (has window focus).
        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.RESUMED) {
                ClipboardMonitor.clipboardFlow(applicationContext).collect { text ->
                    viewModel.onClipboardChanged(text)
                }
            }
        }

        setContent {
            AirClipTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = AirClipBgBase,
                ) {
                    val uiState by viewModel.uiState.collectAsState()

                    if (uiState.pairingState == PairingState.Paired) {
                        MainScreen(viewModel, uiState)
                    } else {
                        OnboardingScreen(viewModel, uiState)
                    }
                }
            }
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        // Read clipboard only when window has focus — Android 10+ blocks reads without it.
        if (hasFocus) viewModel.onAppForegrounded()
    }
}
