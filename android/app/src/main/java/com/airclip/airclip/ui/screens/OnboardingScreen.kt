package com.airclip.airclip.ui.screens

import android.graphics.Bitmap
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions
import com.airclip.airclip.MainViewModel
import com.airclip.airclip.pairing.AirClipCaptureActivity
import com.airclip.airclip.pairing.PairingCode
import com.airclip.airclip.ui.theme.*

private enum class OnboardingStep {
    CHOICE,         // Create or join an AirClip network
    CREATE_NAME,    // name device before creating
    JOIN_NAME,      // name device before joining
    PAIRING_WAIT,   // show QR + code, waiting for existing device to scan
}

@Composable
fun OnboardingScreen(viewModel: MainViewModel, uiState: MainViewModel.UiState) {
    // We control step state locally so we can transition without ViewModel
    var localStep by remember { mutableStateOf(OnboardingStep.CHOICE) }
    val currentStep = if (uiState.isPairingWaiting) OnboardingStep.PAIRING_WAIT else localStep

    // QR scanner launcher
    val scanLauncher = rememberLauncherForActivityResult(ScanContract()) { result ->
        result.contents?.let { qrContent ->
            viewModel.onQrScanned(qrContent)
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(AirClipBgBase),
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Branding header
            OnboardingHeader()

            AnimatedContent(
                targetState = currentStep,
                transitionSpec = { fadeIn() togetherWith fadeOut() },
                label = "onboardingStep",
            ) { s ->
                when (s) {
                    OnboardingStep.CHOICE -> ChoiceStep(
                        onCreateAirClip = { localStep = OnboardingStep.CREATE_NAME },
                        onJoinAirClip   = { localStep = OnboardingStep.JOIN_NAME },
                    )

                    OnboardingStep.CREATE_NAME -> DeviceNameStep(
                        title    = "Name this device",
                        subtitle = "Helps you recognise it on your other devices.",
                        actionLabel = "Create AirClip",
                        uiState  = uiState,
                        onDeviceNameChange = viewModel::onDeviceNameChange,
                        onBack   = { localStep = OnboardingStep.CHOICE },
                        onAction = { viewModel.onCreateAirClip() },
                    )

                    OnboardingStep.JOIN_NAME -> DeviceNameStep(
                        title    = "Name this device",
                        subtitle = "Helps you recognise it on your other devices.",
                        actionLabel = "Continue",
                        uiState  = uiState,
                        onDeviceNameChange = viewModel::onDeviceNameChange,
                        onBack   = { localStep = OnboardingStep.CHOICE },
                        onAction = {
                            viewModel.onStartPairingSession()
                        },
                    )

                    OnboardingStep.PAIRING_WAIT -> PairingWaitStep(
                        uiState    = uiState,
                        onCancel   = {
                            viewModel.onCancelPairing()
                            localStep = OnboardingStep.CHOICE
                        },
                        onScanInstead = {
                            val opts = ScanOptions().apply {
                                setPrompt("Scan another device's QR code")
                                setBeepEnabled(false)
                                setCaptureActivity(AirClipCaptureActivity::class.java)
                                setOrientationLocked(true)
                            }
                            scanLauncher.launch(opts)
                        },
                        onEnterCode = viewModel::onPairingCodeEntered,
                        onRefreshCode = viewModel::onRefreshPairingCode,
                    )
                }
            }

            // Error banner
            uiState.lastError?.let { err ->
                Spacer(Modifier.height(12.dp))
                Text(
                    err,
                    color = AirClipDestructive,
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.padding(horizontal = 24.dp),
                )
            }
        }
    }
}

// ── Branding header ────────────────────────────────────────────────────────────

@Composable
private fun OnboardingHeader() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(200.dp)
            .drawBehind {
                drawRect(
                    Brush.verticalGradient(
                        colors = listOf(AirClipBgBase, AirClipBgFloating),
                        startY = 0f, endY = size.height,
                    )
                )
                drawRect(
                    Brush.radialGradient(
                        colorStops = arrayOf(
                            0.00f to AirClipGreen.copy(alpha = 0.34f),
                            0.32f to AirClipBlue.copy(alpha = 0.20f),
                            0.62f to AirClipBgBase.copy(alpha = 0.0f),
                            0.75f to Color.Transparent,
                        ),
                        center = Offset(size.width / 2f, size.height * 1.08f),
                        radius = size.width * 0.88f,
                    )
                )
                drawRect(
                    Brush.verticalGradient(
                        colors = listOf(Color.Transparent, AirClipBgBase.copy(alpha = 0.92f)),
                        startY = size.height * 0.5f, endY = size.height,
                    )
                )
            }
    ) {
        Column(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(24.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(26.dp)
                        .background(AirClipBgElevated, RoundedCornerShape(8.dp))
                        .border(0.5.dp, AirClipBorderSubtle, RoundedCornerShape(8.dp)),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        Icons.Outlined.RadioButtonChecked,
                        null,
                        tint = AirClipGreen,
                        modifier = Modifier.size(14.dp),
                    )
                }
                Spacer(Modifier.width(8.dp))
                Text(
                    "AirClip",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AirClipTextPrimary,
                    letterSpacing = (-0.2).sp,
                )
            }
            Spacer(Modifier.height(20.dp))
            Text(
                buildAnnotatedString {
                    withStyle(SpanStyle(color = AirClipTextPrimary)) { append("Copy anywhere.\n") }
                    withStyle(SpanStyle(color = AirClipTextTertiary)) { append("Paste everywhere.") }
                },
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                lineHeight = 30.sp,
                letterSpacing = (-0.5).sp,
            )
        }
    }
}

// ── Choice step: Create or join an AirClip network ───────────────────────────

@Composable
private fun ChoiceStep(
    onCreateAirClip: () -> Unit,
    onJoinAirClip: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp)
            .padding(top = 32.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        ChoiceCard(
            icon     = Icons.Outlined.AddCircleOutline,
            iconTint = AirClipAccent,
            title    = "Create AirClip network",
            subtitle = "Start your own AirClip. Pair other devices to sync with you.",
            onClick  = onCreateAirClip,
        )
        ChoiceCard(
            icon     = Icons.Outlined.QrCodeScanner,
            iconTint = AirClipBlue,
            title    = "Join AirClip network",
            subtitle = "Pair this device with an existing AirClip network.",
            onClick  = onJoinAirClip,
        )
    }
}

@Composable
private fun ChoiceCard(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    iconTint: Color,
    title: String,
    subtitle: String,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(AirClipBgElevated)
            .border(0.5.dp, AirClipBorderSubtle, RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 18.dp, vertical = 18.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(
            modifier = Modifier
                .size(44.dp)
                .background(iconTint.copy(alpha = 0.12f), RoundedCornerShape(12.dp)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, null, tint = iconTint, modifier = Modifier.size(22.dp))
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold), color = AirClipTextPrimary)
            Spacer(Modifier.height(2.dp))
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = AirClipTextSecondary)
        }
        Icon(Icons.Outlined.ChevronRight, null, tint = AirClipTextTertiary, modifier = Modifier.size(18.dp))
    }
}

// ── Device name step (shared for Create + Join) ────────────────────────────────

@Composable
private fun DeviceNameStep(
    title: String,
    subtitle: String,
    actionLabel: String,
    uiState: MainViewModel.UiState,
    onDeviceNameChange: (String) -> Unit,
    onBack: () -> Unit,
    onAction: () -> Unit,
) {
    val focus = LocalFocusManager.current

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp)
            .padding(top = 28.dp),
    ) {
        // Back
        TextButton(
            onClick = onBack,
            contentPadding = PaddingValues(0.dp),
        ) {
            Icon(Icons.AutoMirrored.Outlined.ArrowBack, null, tint = AirClipTextSecondary, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(4.dp))
            Text("Back", style = MaterialTheme.typography.bodySmall, color = AirClipTextSecondary)
        }

        Spacer(Modifier.height(16.dp))

        Text(title, style = MaterialTheme.typography.titleMedium, color = AirClipTextPrimary)
        Spacer(Modifier.height(4.dp))
        Text(subtitle, style = MaterialTheme.typography.bodySmall, color = AirClipTextSecondary)

        Spacer(Modifier.height(20.dp))

        AirClipTextField(
            value          = uiState.deviceName,
            onValueChange  = onDeviceNameChange,
            placeholder    = "e.g. My Pixel",
            label          = "Device name",
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { focus.clearFocus() }),
        )

        Spacer(Modifier.height(20.dp))

        AirClipPrimaryButton(
            text    = actionLabel,
            enabled = uiState.deviceName.isNotBlank(),
            onClick = onAction,
        )
    }
}

// ── Pairing wait step: show QR + code ─────────────────────────────────────────

@Composable
private fun PairingWaitStep(
    uiState: MainViewModel.UiState,
    onCancel: () -> Unit,
    onScanInstead: () -> Unit,
    onEnterCode: (String) -> Unit,
    onRefreshCode: () -> Unit,
) {
    var pairingMethod by remember { mutableStateOf(PairingMethod.SHOW_QR) }
    var enteredCode by remember { mutableStateOf("") }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp)
            .padding(top = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        // Tabs: Show QR / Scan instead
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(10.dp))
                .background(AirClipBgElevated)
                .border(0.5.dp, AirClipBorderSubtle, RoundedCornerShape(10.dp))
                .padding(3.dp),
        ) {
            PairingTab("Show QR", selected = pairingMethod == PairingMethod.SHOW_QR) {
                pairingMethod = PairingMethod.SHOW_QR
            }
            PairingTab("Scan QR", selected = pairingMethod == PairingMethod.SCAN_QR) {
                pairingMethod = PairingMethod.SCAN_QR
            }
            PairingTab("Enter code", selected = pairingMethod == PairingMethod.ENTER_CODE) {
                pairingMethod = PairingMethod.ENTER_CODE
            }
        }

        Spacer(Modifier.height(24.dp))

        when (pairingMethod) {
        PairingMethod.SHOW_QR -> {
            // QR display mode
            QrDisplay(uiState = uiState)

            Spacer(Modifier.height(20.dp))

            Text(
                "Open AirClip on an existing device and scan this code,\nor have them enter the code below.",
                style = MaterialTheme.typography.bodySmall,
                color = AirClipTextSecondary,
                textAlign = TextAlign.Center,
            )

            Spacer(Modifier.height(16.dp))

            // 8-digit code display
            uiState.pairingCode?.let { code ->
                Text(
                    code.chunked(4).joinToString("  "),   // "1234  5678" for readability
                    style = MaterialTheme.typography.headlineMedium.copy(
                        fontFamily  = FontFamily.Monospace,
                        fontWeight  = FontWeight.Bold,
                        letterSpacing = 2.sp,
                    ),
                    color = AirClipTextPrimary,
                )
                Spacer(Modifier.height(4.dp))
                TextButton(
                    onClick  = onRefreshCode,
                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
                ) {
                    Icon(Icons.Outlined.Refresh, null, tint = AirClipTextTertiary, modifier = Modifier.size(14.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("Refresh code", style = MaterialTheme.typography.labelSmall, color = AirClipTextTertiary)
                }
            }
        }
        PairingMethod.SCAN_QR -> {
            // Scan mode: launch camera
            Box(
                modifier = Modifier
                    .size(200.dp)
                    .clip(RoundedCornerShape(20.dp))
                    .background(AirClipBgElevated)
                    .border(0.5.dp, AirClipBorderSubtle, RoundedCornerShape(20.dp))
                    .clickable(onClick = onScanInstead),
                contentAlignment = Alignment.Center,
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Icon(
                        Icons.Outlined.QrCodeScanner,
                        null,
                        tint = AirClipTextSecondary,
                        modifier = Modifier.size(48.dp),
                    )
                    Text(
                        "Tap to open camera",
                        style = MaterialTheme.typography.bodySmall,
                        color = AirClipTextSecondary,
                    )
                }
            }
            Spacer(Modifier.height(16.dp))
            Text(
                "Scan the QR code shown on a device in your AirClip network.",
                style = MaterialTheme.typography.bodySmall,
                color = AirClipTextSecondary,
                textAlign = TextAlign.Center,
            )
        }
        PairingMethod.ENTER_CODE -> {
            Text(
                "Enter the 8-digit code shown on your Mac.",
                style = MaterialTheme.typography.bodySmall,
                color = AirClipTextSecondary,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(16.dp))
            AirClipTextField(
                value = enteredCode,
                onValueChange = { enteredCode = PairingCode.normalize(it).take(8) },
                placeholder = "0000 0000",
                label = "Pairing code",
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.NumberPassword,
                    imeAction = ImeAction.Done,
                ),
                keyboardActions = KeyboardActions(
                    onDone = {
                        if (PairingCode.isValid(enteredCode)) onEnterCode(enteredCode)
                    },
                ),
            )
            Spacer(Modifier.height(16.dp))
            AirClipPrimaryButton(
                text = "Join AirClip",
                enabled = PairingCode.isValid(enteredCode),
                onClick = { onEnterCode(enteredCode) },
            )
        }
        }

        Spacer(Modifier.height(28.dp))

        OutlinedButton(
            onClick = onCancel,
            shape   = RoundedCornerShape(10.dp),
            colors  = ButtonDefaults.outlinedButtonColors(contentColor = AirClipTextSecondary),
            border  = androidx.compose.foundation.BorderStroke(0.5.dp, AirClipBorderDefault),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Cancel", style = MaterialTheme.typography.labelLarge)
        }
    }
}

private enum class PairingMethod {
    SHOW_QR,
    SCAN_QR,
    ENTER_CODE,
}

@Composable
private fun RowScope.PairingTab(label: String, selected: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .weight(1f)
            .clip(RoundedCornerShape(8.dp))
            .background(if (selected) AirClipActiveFill else Color.Transparent)
            .let { if (selected) it.border(0.5.dp, AirClipBorderDefault, RoundedCornerShape(8.dp)) else it },
        contentAlignment = Alignment.Center,
    ) {
        TextButton(
            onClick = onClick,
            modifier = Modifier.fillMaxWidth().height(36.dp),
            contentPadding = PaddingValues(0.dp),
        ) {
            Text(
                label,
                style = MaterialTheme.typography.labelLarge,
                color = if (selected) AirClipTextPrimary else AirClipTextSecondary,
            )
        }
    }
}

@Composable
private fun QrDisplay(uiState: MainViewModel.UiState) {
    val qrBitmap = uiState.pairingQr

    Box(
        modifier = Modifier
            .size(220.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White)
            .padding(10.dp),
        contentAlignment = Alignment.Center,
    ) {
        if (qrBitmap != null) {
            androidx.compose.foundation.Image(
                bitmap      = qrBitmap.asImageBitmap(),
                contentDescription = "Pairing QR code",
                modifier    = Modifier.fillMaxSize(),
            )
        } else {
            CircularProgressIndicator(
                modifier = Modifier.size(36.dp),
                color    = AirClipAccent,
                strokeWidth = 2.dp,
            )
        }
    }
}
