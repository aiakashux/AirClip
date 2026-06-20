package com.airclip.airclip.ui.screens

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.airclip.airclip.ClipItemRecord
import com.airclip.airclip.ClipKind
import com.airclip.airclip.MainViewModel
import com.airclip.airclip.AirClipIdentity
import com.airclip.airclip.ImageClipboard
import com.airclip.airclip.ui.theme.*
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

private data class TypeSpec(val icon: ImageVector, val color: Color, val label: String)

private fun typeSpec(kind: ClipKind, preview: String) = when (kind) {
    ClipKind.URL   -> TypeSpec(Icons.Outlined.Link,        AirClipBlue,    "Link")
    ClipKind.CODE  -> TypeSpec(Icons.Outlined.Code,        AirClipGreen,   "Code")
    ClipKind.COLOR -> TypeSpec(Icons.Outlined.Circle,      parseHexColor(preview) ?: AirClipYellow,  "Color")
    ClipKind.EMAIL -> TypeSpec(Icons.Outlined.Email,      AirClipBlue,    "Email")
    ClipKind.IMAGE -> TypeSpec(Icons.Outlined.Image,       AirClipTextTertiary, "Image")
    ClipKind.TEXT  -> TypeSpec(Icons.Outlined.Notes,       AirClipTextSecondary, "Text")
}

// ── Screen ───────────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ClipboardScreen(viewModel: MainViewModel, uiState: MainViewModel.UiState) {
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var searchQuery by remember { mutableStateOf("") }
    var showSavedOnly by remember { mutableStateOf(false) }
    var selectedKind by remember { mutableStateOf<ClipKind?>(null) }
    var selectedId by remember { mutableStateOf<String?>(null) }

    val items = uiState.clipHistory
        .asSequence()
        .filter { !showSavedOnly || it.isSaved }
        .filter { selectedKind == null || recordKind(it) == selectedKind }
        .filter { searchQuery.isBlank() || recordMatchesSearch(it, searchQuery) }
        .toList()
    val selectedRecord = items.firstOrNull { it.messageId == selectedId } ?: items.firstOrNull()

    val now = System.currentTimeMillis()
    val today    = items.filter { isToday(it.timestampMs, now) }
    val earlier  = items.filter { !isToday(it.timestampMs, now) }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        containerColor = AirClipBgBase,
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            // Header
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp)
                    .padding(top = 20.dp, bottom = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "Clipboard",
                    style = MaterialTheme.typography.titleLarge,
                    color = AirClipTextPrimary,
                    modifier = Modifier.weight(1f),
                )
                IconButton(
                    onClick = { viewModel.onCaptureClipboard() },
                    enabled = uiState.syncMode.allowsManualSend,
                ) {
                    Icon(
                        Icons.Outlined.ContentPaste,
                        contentDescription = "Capture clipboard",
                        tint = if (uiState.syncMode.allowsManualSend) {
                            AirClipTextSecondary
                        } else {
                            AirClipTextTertiary.copy(alpha = 0.45f)
                        },
                        modifier = Modifier.size(20.dp),
                    )
                }
            }

            AirClipSearchBar(
                value = searchQuery,
                onValueChange = { searchQuery = it },
                onClear = { searchQuery = "" },
                modifier = Modifier.padding(horizontal = 16.dp),
            )

            Spacer(Modifier.height(10.dp))

            SegmentedFilterRow(
                selectedSavedOnly = showSavedOnly,
                onSelectedSavedOnly = { showSavedOnly = it },
                modifier = Modifier.padding(horizontal = 16.dp),
            )

            Spacer(Modifier.height(8.dp))

            TypeFilterRow(
                selectedKind = selectedKind,
                onSelectedKind = { selectedKind = it },
                modifier = Modifier.padding(horizontal = 16.dp),
            )

            AnimatedVisibility(
                visible = selectedRecord != null,
                enter = fadeIn() + expandVertically(),
                exit = fadeOut() + shrinkVertically(),
            ) {
                selectedRecord?.let { record ->
                    Spacer(Modifier.height(12.dp))
                    PreviewPanel(
                        record = record,
                        onCopy = {
                            selectedId = record.messageId
                            viewModel.onHistoryItemCopyStarted(record)
                            copyRecordToClipboard(context, record)
                            scope.launch {
                                snackbarHostState.showSnackbar("Copied", duration = SnackbarDuration.Short)
                            }
                        },
                        onSave = { viewModel.onToggleSaved(record) },
                        onDelete = {
                            if (selectedId == record.messageId) selectedId = null
                            viewModel.onDeleteClip(record)
                        },
                    )
                }
            }

            Spacer(Modifier.height(12.dp))

            // List
            if (items.isEmpty()) {
                ClipboardEmptyState(
                    hasSearch = searchQuery.isNotBlank(),
                    hasFilter = showSavedOnly || selectedKind != null,
                )
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    if (today.isNotEmpty()) {
                        item { SectionHeader("Today") }
                        items(today, key = { it.messageId }) { record ->
                            SwipeableClipCard(
                                record = record,
                                onTap = {
                                    selectedId = record.messageId
                                    viewModel.onHistoryItemCopyStarted(record)
                                    copyRecordToClipboard(context, record)
                                    scope.launch {
                                        snackbarHostState.showSnackbar(
                                            "Copied",
                                            duration = SnackbarDuration.Short,
                                        )
                                    }
                                },
                                onSave = { viewModel.onToggleSaved(record) },
                                onDelete = { viewModel.onDeleteClip(record) },
                                isSelected = selectedRecord?.messageId == record.messageId,
                            )
                        }
                    }
                    if (earlier.isNotEmpty()) {
                        item { SectionHeader("Earlier") }
                        items(earlier, key = { it.messageId }) { record ->
                            SwipeableClipCard(
                                record = record,
                                onTap = {
                                    selectedId = record.messageId
                                    viewModel.onHistoryItemCopyStarted(record)
                                    copyRecordToClipboard(context, record)
                                    scope.launch {
                                        snackbarHostState.showSnackbar(
                                            "Copied",
                                            duration = SnackbarDuration.Short,
                                        )
                                    }
                                },
                                onSave = { viewModel.onToggleSaved(record) },
                                onDelete = { viewModel.onDeleteClip(record) },
                                isSelected = selectedRecord?.messageId == record.messageId,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TypeFilterRow(
    selectedKind: ClipKind?,
    onSelectedKind: (ClipKind?) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        TypeFilterChip("All", selectedKind == null, { onSelectedKind(null) }, Modifier.weight(1f))
        TypeFilterChip("Text", selectedKind == ClipKind.TEXT, { onSelectedKind(ClipKind.TEXT) }, Modifier.weight(1f))
        TypeFilterChip("Links", selectedKind == ClipKind.URL, { onSelectedKind(ClipKind.URL) }, Modifier.weight(1f))
        TypeFilterChip("Images", selectedKind == ClipKind.IMAGE, { onSelectedKind(ClipKind.IMAGE) }, Modifier.weight(1f))
    }
}

@Composable
private fun TypeFilterChip(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Button(
        onClick = onClick,
        modifier = modifier.height(30.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = if (selected) AirClipActiveFill else AirClipBgElevated,
            contentColor = if (selected) AirClipTextPrimary else AirClipTextTertiary,
        ),
        shape = RoundedCornerShape(10.dp),
        border = BorderStroke(0.5.dp, AirClipBorderSubtle),
        contentPadding = PaddingValues(horizontal = 6.dp, vertical = 0.dp),
    ) {
        Text(label, style = MaterialTheme.typography.labelSmall, maxLines = 1)
    }
}

@Composable
private fun AirClipSearchBar(
    value: String,
    onValueChange: (String) -> Unit,
    onClear: () -> Unit,
    modifier: Modifier = Modifier,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier
            .fillMaxWidth()
            .height(44.dp),
        placeholder = {
            Text("Search", color = AirClipTextTertiary, style = MaterialTheme.typography.bodySmall)
        },
        leadingIcon = {
            Icon(Icons.Outlined.Search, null, tint = AirClipTextTertiary, modifier = Modifier.size(18.dp))
        },
        trailingIcon = if (value.isNotEmpty()) {
            {
                IconButton(onClick = onClear) {
                    Icon(Icons.Outlined.Close, null, tint = AirClipTextTertiary, modifier = Modifier.size(16.dp))
                }
            }
        } else null,
        singleLine = true,
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = Color.White.copy(alpha = 0.18f),
            unfocusedBorderColor = AirClipBorderSubtle,
            focusedContainerColor = AirClipBgElevated,
            unfocusedContainerColor = AirClipBgElevated,
            focusedTextColor = AirClipTextPrimary,
            unfocusedTextColor = AirClipTextPrimary,
            cursorColor = AirClipAccent,
        ),
        shape = RoundedCornerShape(12.dp),
        textStyle = MaterialTheme.typography.bodySmall.copy(color = AirClipTextPrimary),
    )
}

@Composable
private fun SegmentedFilterRow(
    selectedSavedOnly: Boolean,
    onSelectedSavedOnly: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(AirClipBgElevated)
            .border(0.5.dp, AirClipBorderSubtle, RoundedCornerShape(12.dp))
            .padding(4.dp),
    ) {
        FilterSegment(
            label = "All",
            selected = !selectedSavedOnly,
            onClick = { onSelectedSavedOnly(false) },
            modifier = Modifier.weight(1f),
        )
        FilterSegment(
            label = "Saved",
            selected = selectedSavedOnly,
            onClick = { onSelectedSavedOnly(true) },
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun FilterSegment(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Button(
        onClick = onClick,
        modifier = modifier.height(30.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = if (selected) AirClipActiveFill else Color.Transparent,
            contentColor = if (selected) AirClipTextPrimary else AirClipTextTertiary,
        ),
        shape = RoundedCornerShape(9.dp),
        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 0.dp),
    ) {
        Text(label, style = MaterialTheme.typography.labelSmall)
    }
}

@Composable
private fun PreviewPanel(
    record: ClipItemRecord,
    onCopy: () -> Unit,
    onSave: () -> Unit,
    onDelete: () -> Unit,
) {
    val kind = runCatching { ClipKind.valueOf(record.kind) }.getOrDefault(ClipKind.TEXT)
    val text = record.displayText
    val spec = typeSpec(kind, text)
    val fadeBrush = Brush.verticalGradient(
        colors = listOf(Color.Transparent, AirClipBgFloating.copy(alpha = 0.82f), AirClipBgFloating),
    )

    Column(
        modifier = Modifier
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(AirClipBgElevated)
            .border(0.5.dp, AirClipBorderSubtle, RoundedCornerShape(16.dp))
            .clipToBounds(),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(30.dp)
                    .background(spec.color.copy(alpha = 0.16f), RoundedCornerShape(8.dp)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(spec.icon, spec.label, tint = spec.color, modifier = Modifier.size(15.dp))
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(text, style = MaterialTheme.typography.bodyMedium, color = AirClipTextPrimary, maxLines = 3, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.height(2.dp))
                Text(
                    if (record.isSaved) "Saved • ${formatTime(record.timestampMs)}" else formatTime(record.timestampMs),
                    style = MaterialTheme.typography.labelSmall,
                    color = AirClipTextTertiary,
                )
            }
        }

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 88.dp)
                .background(AirClipBgElevated)
                .clipToBounds(),
        ) {
            val bitmap = remember(record.imageDataBase64) {
                ImageClipboard.decode(record.imageDataBase64)
            }
            if (kind == ClipKind.IMAGE && bitmap != null) {
                androidx.compose.foundation.Image(
                    bitmap = bitmap.asImageBitmap(),
                    contentDescription = text,
                    contentScale = ContentScale.Fit,
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 180.dp, max = 320.dp)
                        .padding(horizontal = 14.dp)
                        .padding(bottom = 48.dp),
                )
            } else {
                Text(
                    text = text,
                    style = if (text.length > 260) {
                        MaterialTheme.typography.bodyLarge.copy(fontSize = 20.sp)
                    } else {
                        MaterialTheme.typography.bodyLarge
                    },
                    color = AirClipTextPrimary,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 14.dp)
                        .padding(bottom = 56.dp),
                )
            }
            Box(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .height(48.dp)
                    .background(fadeBrush)
            )
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
        ) {
            PreviewActionButton(Icons.Outlined.ContentCopy, "Copy", onCopy)
            PreviewActionButton(
                if (record.isSaved) Icons.Outlined.Bookmark else Icons.Outlined.BookmarkBorder,
                if (record.isSaved) "Saved" else "Save",
                onSave,
                tint = if (record.isSaved) AirClipGreen else AirClipTextSecondary,
            )
            PreviewActionButton(Icons.Outlined.Delete, "Delete", onDelete, tint = AirClipDestructive)
        }
    }
}

@Composable
private fun PreviewActionButton(
    icon: ImageVector,
    label: String,
    onClick: () -> Unit,
    tint: Color = AirClipTextSecondary,
) {
    TextButton(
        onClick = onClick,
        colors = ButtonDefaults.textButtonColors(contentColor = tint),
        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 8.dp),
    ) {
        Icon(icon, label, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(6.dp))
        Text(label, style = MaterialTheme.typography.labelLarge)
    }
}

// ── Swipeable wrapper ─────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SwipeableClipCard(
    record: ClipItemRecord,
    onTap: () -> Unit,
    onSave: () -> Unit,
    onDelete: () -> Unit,
    isSelected: Boolean,
) {
    val dismissState = rememberSwipeToDismissBoxState(
        confirmValueChange = { value ->
            if (value == SwipeToDismissBoxValue.EndToStart) {
                onDelete()
                true
            } else false
        }
    )

    SwipeToDismissBox(
        state = dismissState,
        enableDismissFromStartToEnd = false,
        backgroundContent = {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .clip(RoundedCornerShape(12.dp))
                    .background(AirClipDestructive.copy(alpha = 0.85f)),
                contentAlignment = Alignment.CenterEnd,
            ) {
                Icon(
                    imageVector = Icons.Outlined.Delete,
                    contentDescription = "Delete",
                    tint = Color.White,
                    modifier = Modifier
                        .padding(end = 20.dp)
                        .size(20.dp),
                )
            }
        },
        content = { ClipCard(record, onTap, onSave, isSelected) },
    )
}

// ── Clip card ─────────────────────────────────────────────────────────────────

@Composable
private fun ClipCard(record: ClipItemRecord, onTap: () -> Unit, onSave: () -> Unit, isSelected: Boolean) {
    val kind = runCatching { ClipKind.valueOf(record.kind) }.getOrDefault(ClipKind.TEXT)
    val text = record.displayText
    val spec = typeSpec(kind, text)
    val timeStr = remember(record.timestampMs) { formatTime(record.timestampMs) }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(if (isSelected) AirClipActiveFill else AirClipBgElevated)
            .border(0.5.dp, if (isSelected) AirClipAccent.copy(alpha = 0.34f) else AirClipBorderSubtle, RoundedCornerShape(14.dp))
            .clickable(onClick = onTap)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        val bitmap = remember(record.imageDataBase64) {
            ImageClipboard.decode(record.imageDataBase64)
        }

        // Type icon / image thumbnail
        Box(
            modifier = Modifier
                .size(32.dp)
                .background(spec.color.copy(alpha = 0.12f), RoundedCornerShape(8.dp)),
            contentAlignment = Alignment.Center,
        ) {
            if (kind == ClipKind.IMAGE && bitmap != null) {
                androidx.compose.foundation.Image(
                    bitmap = bitmap.asImageBitmap(),
                    contentDescription = text,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize(),
                )
            } else {
                Icon(
                    imageVector = spec.icon,
                    contentDescription = spec.label,
                    tint = spec.color,
                    modifier = Modifier.size(16.dp),
                )
            }
        }

        IconButton(
            onClick = onSave,
            modifier = Modifier.size(30.dp),
        ) {
            Icon(
                if (record.isSaved) Icons.Outlined.Bookmark else Icons.Outlined.BookmarkBorder,
                contentDescription = if (record.isSaved) "Saved" else "Save",
                tint = if (record.isSaved) AirClipGreen else AirClipTextTertiary,
                modifier = Modifier.size(16.dp),
            )
        }

        // Content
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = text,
                style = if (text.length > 260) {
                    MaterialTheme.typography.bodySmall.copy(fontSize = 12.sp)
                } else {
                    MaterialTheme.typography.bodySmall
                },
                color = AirClipTextPrimary,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(3.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(timeStr, style = MaterialTheme.typography.labelSmall, color = AirClipTextTertiary)
                Text("·", style = MaterialTheme.typography.labelSmall, color = AirClipTextTertiary)
                val sourceName = if (record.fromDeviceId == AirClipIdentity.deviceId) "This device"
                                 else AirClipIdentity.pairedDevices[record.fromDeviceId]?.deviceName ?: "Remote device"
                Text(
                    sourceName,
                    style = MaterialTheme.typography.labelSmall,
                    color = AirClipTextTertiary,
                )
            }
        }
    }
}

// ── Section header ───────────────────────────────────────────────────────────

@Composable
private fun SectionHeader(title: String) {
    Text(
        title,
        style = MaterialTheme.typography.labelMedium,
        color = AirClipTextTertiary,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp)
            .padding(top = 12.dp, bottom = 4.dp),
    )
}

// ── Empty state ───────────────────────────────────────────────────────────────

@Composable
private fun ClipboardEmptyState(hasSearch: Boolean, hasFilter: Boolean) {
    Column(
        modifier = Modifier.fillMaxSize().padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            imageVector = Icons.Outlined.ContentPaste,
            contentDescription = null,
            tint = AirClipTextTertiary,
            modifier = Modifier.size(40.dp),
        )
        Spacer(Modifier.height(12.dp))
        Text(
            if (hasSearch || hasFilter) "No results" else "No clipboard history yet",
            style = MaterialTheme.typography.bodyMedium,
            color = AirClipTextSecondary,
        )
        if (!hasSearch && !hasFilter) {
            Spacer(Modifier.height(4.dp))
            Text(
                "Copy something on another device to see it here.",
                style = MaterialTheme.typography.bodySmall,
                color = AirClipTextTertiary,
                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            )
        }
    }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

private fun copyRecordToClipboard(context: Context, record: ClipItemRecord) {
    if (runCatching { ImageClipboard.copy(context, record) }.getOrDefault(false)) return
    val mgr = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    mgr.setPrimaryClip(ClipData.newPlainText("AirClip", record.displayText))
}

private fun isToday(timestampMs: Long, now: Long): Boolean {
    val cal1 = Calendar.getInstance().apply { timeInMillis = timestampMs }
    val cal2 = Calendar.getInstance().apply { timeInMillis = now }
    return cal1.get(Calendar.YEAR) == cal2.get(Calendar.YEAR) &&
           cal1.get(Calendar.DAY_OF_YEAR) == cal2.get(Calendar.DAY_OF_YEAR)
}

private val timeFmt = SimpleDateFormat("h:mm a", Locale.getDefault())
private val dateFmt = SimpleDateFormat("MMM d", Locale.getDefault())

private fun formatTime(timestampMs: Long): String {
    val now = System.currentTimeMillis()
    return if (isToday(timestampMs, now)) timeFmt.format(Date(timestampMs))
           else dateFmt.format(Date(timestampMs))
}

private fun recordMatchesSearch(record: ClipItemRecord, query: String): Boolean {
    val needle = query.trim()
    if (needle.isEmpty()) return true
    val sourceName = if (record.fromDeviceId == AirClipIdentity.deviceId) {
        "This device"
    } else {
        AirClipIdentity.pairedDevices[record.fromDeviceId]?.deviceName ?: "Remote device"
    }
    return record.displayText.contains(needle, ignoreCase = true) ||
        record.kind.contains(needle, ignoreCase = true) ||
        sourceName.contains(needle, ignoreCase = true)
}

private fun recordKind(record: ClipItemRecord): ClipKind =
    runCatching { ClipKind.valueOf(record.kind) }.getOrDefault(ClipKind.TEXT)

private fun parseHexColor(text: String): Color? {
    val hex = text.trim().removePrefix("#")
    if (hex.length !in listOf(3, 4, 6, 8)) return null
    if (!hex.all { it.isDigit() || it.lowercaseChar() in 'a'..'f' }) return null
    return try {
        val expanded = when (hex.length) {
            3 -> hex.map { "$it$it" }.joinToString("") + "FF"
            4 -> hex.map { "$it$it" }.joinToString("")
            6 -> hex + "FF"
            else -> hex
        }
        val value = expanded.toLong(16)
        Color(
            red = ((value shr 24) and 0xFF) / 255f,
            green = ((value shr 16) and 0xFF) / 255f,
            blue = ((value shr 8) and 0xFF) / 255f,
            alpha = (value and 0xFF) / 255f,
        )
    } catch (_: Exception) {
        null
    }
}
