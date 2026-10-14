package com.airclip.airclip

import android.graphics.Color as AndroidColor
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.input.pointer.util.VelocityTrackerAddPointsFix
import androidx.core.view.WindowCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.airclip.airclip.clipboard.ClipboardMonitor
import com.airclip.airclip.device.PairingState
import com.airclip.airclip.ui.screens.MainScreen
import com.airclip.airclip.ui.screens.OnboardingScreen
import com.airclip.airclip.ui.theme.AirclipTheme
import kotlinx.coroutines.launch

@OptIn(ExperimentalComposeUiApi::class)
internal fun configureComposeVelocityTracking() {
    // Compose 1.6.8's legacy finger-up samples can reverse fast flings.
    VelocityTrackerAddPointsFix = true
}

class MainActivity : ComponentActivity() {

    private val viewModel: MainViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configureComposeVelocityTracking()

        // Collect clipboard changes while Activity is in RESUMED state (has window focus).
        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.RESUMED) {
                ClipboardMonitor.clipboardFlow(applicationContext).collect { text ->
                    viewModel.onClipboardChanged(text)
                }
            }
        }

        setContent {
            val uiState by viewModel.uiState.collectAsState()
            val isPaired = uiState.pairingState == PairingState.Paired
            SideEffect {
                WindowCompat.setDecorFitsSystemWindows(window, false)
                window.statusBarColor = AndroidColor.TRANSPARENT
                window.navigationBarColor = if (isPaired) AndroidColor.WHITE else AndroidColor.TRANSPARENT
                WindowCompat.getInsetsController(window, window.decorView).apply {
                    isAppearanceLightStatusBars = true
                    isAppearanceLightNavigationBars = true
                }
            }

            AirclipTheme(appearanceSetting = uiState.appearanceSetting) {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background,
                ) {
                    AnimatedContent(
                        targetState = isPaired,
                        transitionSpec = {
                            fadeIn(tween(220, easing = CubicBezierEasing(0.23f, 1f, 0.32f, 1f))) togetherWith
                                fadeOut(tween(140))
                        },
                        label = "onboarding to app",
                    ) { paired ->
                        if (paired) {
                            MainScreen(viewModel, uiState)
                        } else {
                            OnboardingScreen(viewModel, uiState)
                        }
                    }

                    if (uiState.showNetworkSwitchConfirmation) {
                        AlertDialog(
                            onDismissRequest = viewModel::onCancelNetworkSwitch,
                            title = { Text("Join this Airclip?") },
                            text = {
                                Text(
                                    "This device is already part of another Airclip. Joining this one will leave the current Airclip on this device.",
                                )
                            },
                            confirmButton = {
                                TextButton(onClick = viewModel::onConfirmNetworkSwitch) {
                                    Text("Join this Airclip")
                                }
                            },
                            dismissButton = {
                                TextButton(onClick = viewModel::onCancelNetworkSwitch) {
                                    Text("Cancel")
                                }
                            },
                        )
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
