package com.cliprplus.clipr.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.cliprplus.clipr.MainViewModel
import com.cliprplus.clipr.device.AuthState
import com.cliprplus.clipr.device.DeviceApprovalState
import com.cliprplus.clipr.device.TokenState
import com.cliprplus.clipr.device.WsState

@Composable
fun DebugScreen(vm: MainViewModel = viewModel()) {
    val state by vm.uiState.collectAsState()

    // Pre-compute state labels
    val authLabel = when (state.authState) {
        AuthState.LoggedOut         -> "LoggedOut"
        AuthState.AccountTokenReady -> "AccountTokenReady ✓"
    }
    val approvalLabel = when (state.deviceApprovalState) {
        DeviceApprovalState.NotRegistered   -> "NotRegistered"
        DeviceApprovalState.PendingApproval -> {
            val wait = state.approvalPollWaitSeconds
            if (wait != null) "PendingApproval (poll in ${wait}s)" else "PendingApproval"
        }
        DeviceApprovalState.Approved -> "Approved ✓"
        DeviceApprovalState.Revoked  -> "Revoked ✗"
    }
    val tokenLabel = when (state.tokenState) {
        TokenState.NoDeviceToken      -> "NoDeviceToken"
        TokenState.DeviceTokenReady   -> "DeviceTokenReady ✓"
        TokenState.DeviceTokenInvalid -> "DeviceTokenInvalid ✗"
    }
    val wsLabel = when (val ws = state.wsState) {
        WsState.Disconnected -> "Disconnected"
        WsState.Connecting   -> "Connecting…"
        WsState.Connected    -> "Connected ✓"
        is WsState.Backoff   -> "Backoff (${ws.nextRetrySeconds}s)"
    }

    val isTrusted = state.deviceApprovalState == DeviceApprovalState.Approved

    // Button gate conditions
    val canRegisterDevice = state.authState == AuthState.AccountTokenReady
    val canRefresh        = state.authState == AuthState.AccountTokenReady &&
                            state.tokenState == TokenState.DeviceTokenReady
    val canConnectWs      = isTrusted &&
                            state.tokenState == TokenState.DeviceTokenReady &&
                            state.wsState == WsState.Disconnected
    val canSendTest       = state.wsState == WsState.Connected && isTrusted

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 14.dp, vertical = 10.dp)
            .verticalScroll(rememberScrollState())
    ) {
        Text("Clipr+  Debug", style = MaterialTheme.typography.titleLarge)
        Spacer(Modifier.height(10.dp))

        // ── Server URL ────────────────────────────────────────────────
        OutlinedTextField(
            value = state.baseUrl,
            onValueChange = vm::onBaseUrlChange,
            label = { Text("Server URL") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(8.dp))

        // ── Credentials ──────────────────────────────────────────────
        OutlinedTextField(
            value = state.email,
            onValueChange = vm::onEmailChange,
            label = { Text("Email") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(4.dp))
        OutlinedTextField(
            value = state.password,
            onValueChange = vm::onPasswordChange,
            label = { Text("Password") },
            singleLine = true,
            visualTransformation = PasswordVisualTransformation(),
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(10.dp))

        // ── Auth buttons ─────────────────────────────────────────────
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = vm::onRegister, modifier = Modifier.weight(1f)) { Text("Register") }
            Button(onClick = vm::onLogin,    modifier = Modifier.weight(1f)) { Text("Login") }
        }
        Spacer(Modifier.height(6.dp))

        // ── Device / WS buttons ──────────────────────────────────────
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Button(
                onClick  = vm::onRegisterDevice,
                enabled  = canRegisterDevice,
                modifier = Modifier.weight(1f)
            ) {
                Text("Register\nDevice", fontSize = 11.sp, textAlign = TextAlign.Center)
            }
            Button(
                onClick  = vm::onConnectWs,
                enabled  = canConnectWs,
                modifier = Modifier.weight(1f)
            ) {
                Text("Connect\nWS", fontSize = 11.sp, textAlign = TextAlign.Center)
            }
            Button(
                onClick  = vm::onSendTestMessage,
                enabled  = canSendTest,
                modifier = Modifier.weight(1f)
            ) {
                Text("Send Test\nMsg", fontSize = 11.sp, textAlign = TextAlign.Center)
            }
        }
        Spacer(Modifier.height(6.dp))

        // ── Refresh Devices ───────────────────────────────────────────
        Button(
            onClick  = vm::onRefreshDevices,
            enabled  = canRefresh,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Refresh Devices")
        }
        state.lastRefreshTime?.let { t ->
            val suffix = state.lastRefreshError?.let { " — $it" } ?: ""
            Text(
                "Last refresh: $t$suffix",
                fontSize = 10.sp,
                fontFamily = FontFamily.Monospace,
                color = if (state.lastRefreshError != null) Color(0xFFC62828)
                        else MaterialTheme.colorScheme.outline
            )
        }
        Spacer(Modifier.height(8.dp))

        // ── Pending approval banner ───────────────────────────────────
        if (state.deviceApprovalState == DeviceApprovalState.PendingApproval) {
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors   = CardDefaults.cardColors(containerColor = Color(0xFFFFF3CD))
            ) {
                Text(
                    "Device pending approval. Approve from a trusted device (Mac), then tap Refresh.",
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                    fontSize = 12.sp,
                    color    = Color(0xFF664D03)
                )
            }
            Spacer(Modifier.height(8.dp))
        }

        // ── State summary ─────────────────────────────────────────────
        Text("State:", style = MaterialTheme.typography.labelMedium)
        Spacer(Modifier.height(2.dp))
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors   = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
        ) {
            Column(modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)) {
                StateRow("Auth",     authLabel)
                StateRow("Approval", approvalLabel,
                    isError = state.deviceApprovalState == DeviceApprovalState.Revoked)
                StateRow("Token",    tokenLabel,
                    isError = state.tokenState == TokenState.DeviceTokenInvalid)
                StateRow("WS",       wsLabel)
                state.lastError?.let { err ->
                    Spacer(Modifier.height(2.dp))
                    StateRow("Error", err, isError = true)
                }
            }
        }
        Spacer(Modifier.height(10.dp))

        // ── Log ───────────────────────────────────────────────────────
        Text("Log:", style = MaterialTheme.typography.labelMedium)
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .height(150.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(8.dp)
                    .verticalScroll(rememberScrollState())
            ) {
                Column {
                    state.statusLog.takeLast(20).reversed().forEach { line ->
                        Text(line, fontSize = 10.sp, fontFamily = FontFamily.Monospace, lineHeight = 13.sp)
                    }
                }
            }
        }
        Spacer(Modifier.height(10.dp))

        // ── Received messages ─────────────────────────────────────────
        Text(
            "Received Messages (${state.receivedMessages.size}) — encrypted, not decrypted here:",
            style = MaterialTheme.typography.labelMedium
        )
        Spacer(Modifier.height(4.dp))
        if (state.receivedMessages.isEmpty()) {
            Text("(none yet)", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        } else {
            state.receivedMessages.takeLast(20).reversed().forEach { msg ->
                ReceivedMessageCard(msg)
                Spacer(Modifier.height(4.dp))
            }
        }
        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun StateRow(label: String, value: String, isError: Boolean = false) {
    Row(modifier = Modifier.fillMaxWidth()) {
        Text(
            text  = "$label: ",
            fontSize = 10.sp,
            fontFamily = FontFamily.Monospace,
            color = MaterialTheme.colorScheme.outline
        )
        Text(
            text  = value,
            fontSize = 10.sp,
            fontFamily = FontFamily.Monospace,
            color = if (isError) Color(0xFFC62828) else MaterialTheme.colorScheme.onSurface
        )
    }
}

@Composable
private fun ReceivedMessageCard(msg: MainViewModel.ReceivedMessageUi) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors   = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer)
    ) {
        Column(modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)) {
            Row(
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    "${msg.direction}  ${msg.timestamp}",
                    fontSize = 10.sp,
                    fontFamily = FontFamily.Monospace,
                    color = MaterialTheme.colorScheme.onSecondaryContainer
                )
                Text(
                    "from: ${msg.fromDeviceId.take(8)}…",
                    fontSize = 10.sp,
                    fontFamily = FontFamily.Monospace,
                    color = MaterialTheme.colorScheme.onSecondaryContainer
                )
            }
            Text("cipher_hash: ${msg.ciphertextHash}", fontSize = 10.sp, fontFamily = FontFamily.Monospace)
            Text(
                "msg_id: ${msg.messageId.take(8)}…",
                fontSize = 10.sp,
                fontFamily = FontFamily.Monospace,
                color = MaterialTheme.colorScheme.outline
            )
        }
    }
}
