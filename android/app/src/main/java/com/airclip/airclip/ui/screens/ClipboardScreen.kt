package com.airclip.airclip.ui.screens

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.util.LruCache
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.clickable
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Notes
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.airclip.airclip.R
import com.airclip.airclip.AirClipIdentity
import com.airclip.airclip.ClipItemRecord
import com.airclip.airclip.ClipKind
import com.airclip.airclip.ImageClipboard
import com.airclip.airclip.MainViewModel
import com.airclip.airclip.SyncMode
import com.airclip.airclip.ui.theme.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.util.*

// ── Screen ────────────────────────────────────────────────────────────────────

private val BearyFontFamily = FontFamily(Font(R.font.beary))
private val ImagePreviewCache = LruCache<String, Bitmap>(24)

private data class ClipboardFeedGroups(
    val all: List<ClipItemRecord>,
    val today: List<ClipItemRecord>,
    val yesterday: List<ClipItemRecord>,
    val thisWeek: List<ClipItemRecord>,
    val earlier: List<ClipItemRecord>,
)

@Composable
fun ClipboardScreen(
    viewModel: MainViewModel,
    uiState: ClipboardTabUiState,
    listState: LazyListState,
) {
    val c = LocalAirClipColors.current
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val statusBarTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    var searchQuery by remember { mutableStateOf("") }
    var selectedKind by remember { mutableStateOf<ClipKind?>(null) }
    var showFilters by remember { mutableStateOf(false) }
    var actionRecord by remember { mutableStateOf<ClipItemRecord?>(null) }
    val headerHeight = statusBarTop + if (showFilters) 226.dp else 176.dp

    val groupedItems = remember(uiState.clipHistory, selectedKind, searchQuery) {
        val now = System.currentTimeMillis()
        val filtered = uiState.clipHistory
            .asSequence()
            .filter { selectedKind == null || recordKind(it) == selectedKind }
            .filter { searchQuery.isBlank() || recordMatchesSearch(it, searchQuery) }
            .toList()

        val today = ArrayList<ClipItemRecord>()
        val yesterday = ArrayList<ClipItemRecord>()
        val thisWeek = ArrayList<ClipItemRecord>()
        val earlier = ArrayList<ClipItemRecord>()

        filtered.forEach { item ->
            when {
                isToday(item.timestampMs, now) -> today += item
                isYesterday(item.timestampMs, now) -> yesterday += item
                isThisWeek(item.timestampMs, now) -> thisWeek += item
                else -> earlier += item
            }
        }

        ClipboardFeedGroups(
            all = filtered,
            today = today,
            yesterday = yesterday,
            thisWeek = thisWeek,
            earlier = earlier,
        )
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        containerColor = c.bgBase,
        contentWindowInsets = WindowInsets(0.dp),
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(top = headerHeight),
                state = listState,
                contentPadding = PaddingValues(bottom = 24.dp),
            ) {
                if (groupedItems.all.isNotEmpty()) {
                    // ── Today section ─────────────────────────────────────────────────
                    feedSection(
                        title = "Today",
                        records = groupedItems.today,
                        onCopy = { record ->
                            viewModel.onHistoryItemCopyStarted(record)
                            copyRecordToClipboard(context, record)
                            scope.launch { snackbarHostState.showSnackbar("Copied", duration = SnackbarDuration.Short) }
                        },
                        onLongPress = { actionRecord = it },
                    )

                    feedSection(
                        title = "Yesterday",
                        records = groupedItems.yesterday,
                        onCopy = { record ->
                            viewModel.onHistoryItemCopyStarted(record)
                            copyRecordToClipboard(context, record)
                            scope.launch { snackbarHostState.showSnackbar("Copied", duration = SnackbarDuration.Short) }
                        },
                        onLongPress = { actionRecord = it },
                    )

                    feedSection(
                        title = "This Week",
                        records = groupedItems.thisWeek,
                        onCopy = { record ->
                            viewModel.onHistoryItemCopyStarted(record)
                            copyRecordToClipboard(context, record)
                            scope.launch { snackbarHostState.showSnackbar("Copied", duration = SnackbarDuration.Short) }
                        },
                        onLongPress = { actionRecord = it },
                    )

                    feedSection(
                        title = "Earlier",
                        records = groupedItems.earlier,
                        onCopy = { record ->
                            viewModel.onHistoryItemCopyStarted(record)
                            copyRecordToClipboard(context, record)
                            scope.launch { snackbarHostState.showSnackbar("Copied", duration = SnackbarDuration.Short) }
                        },
                        onLongPress = { actionRecord = it },
                    )
                }
            }

            if (groupedItems.all.isEmpty()) {
                AirClipEmptyState(
                    iconRes = R.drawable.ic_home_empty_state,
                    text = if (searchQuery.isNotBlank() || selectedKind != null) {
                        "No results"
                    } else {
                        "Airclip is ready. Copy on one device, to use it on another."
                    },
                )
            }

            HomePageHeader(
                syncMode = uiState.syncMode,
                searchQuery = searchQuery,
                onSearchQueryChange = { searchQuery = it },
                showFilters = showFilters,
                onFilterToggle = { showFilters = !showFilters },
                selectedKind = selectedKind,
                onSelectedKind = { selectedKind = it },
                onCaptureClipboard = { viewModel.onCaptureClipboard() },
                modifier = Modifier.align(Alignment.TopCenter),
            )
        }
    }

    actionRecord?.let { record ->
        ClipActionSheet(
            record = record,
            onDismiss = { actionRecord = null },
            onCopy = {
                viewModel.onHistoryItemCopyStarted(record)
                copyRecordToClipboard(context, record)
                actionRecord = null
                scope.launch { snackbarHostState.showSnackbar("Copied", duration = SnackbarDuration.Short) }
            },
            onSave = {
                viewModel.onToggleSaved(record)
                actionRecord = null
            },
            onDelete = {
                viewModel.onDeleteClip(record)
                actionRecord = null
            },
            onOpenLink = {
                openRecordLink(context, record)
                actionRecord = null
            },
        )
    }
}

@Composable
private fun HomePageHeader(
    syncMode: SyncMode,
    searchQuery: String,
    onSearchQueryChange: (String) -> Unit,
    showFilters: Boolean,
    onFilterToggle: () -> Unit,
    selectedKind: ClipKind?,
    onSelectedKind: (ClipKind?) -> Unit,
    onCaptureClipboard: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val statusBarTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(Color.White)
            .padding(top = statusBarTop + 24.dp, bottom = 24.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "Airclip",
                fontSize = 36.sp,
                lineHeight = 40.sp,
                fontFamily = BearyFontFamily,
                fontWeight = FontWeight.Normal,
                color = Color(0xFF202327),
                letterSpacing = (-0.6).sp,
            )
            Spacer(Modifier.weight(1f))
            if (syncMode == SyncMode.MANUAL_ONLY) {
                Spacer(Modifier.width(8.dp))
                IconButton(onClick = onCaptureClipboard) {
                    Icon(
                        painter = painterResource(R.drawable.ic_home_clipboard_sync),
                        contentDescription = "Sync clipboard",
                        tint = Color.Unspecified,
                        modifier = Modifier.size(24.dp),
                    )
                }
            }
        }
        Spacer(Modifier.height(32.dp))
        FeedSearchBar(
            value = searchQuery,
            onValueChange = onSearchQueryChange,
            filtersVisible = showFilters,
            onFilterToggle = onFilterToggle,
            modifier = Modifier.padding(horizontal = 20.dp),
        )
        AnimatedVisibility(
            visible = showFilters,
            enter = fadeIn(tween(160, easing = FastOutSlowInEasing)) +
                    slideInVertically(tween(190, easing = FastOutSlowInEasing)) { -it / 2 },
            exit = fadeOut(tween(120, easing = FastOutSlowInEasing)) +
                    slideOutVertically(tween(150, easing = FastOutSlowInEasing)) { -it / 2 },
        ) {
            Column {
                Spacer(Modifier.height(16.dp))
                FeedFilterRow(
                    selectedKind = selectedKind,
                    onSelectedKind = onSelectedKind,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
private fun LazyListScope.feedSection(
    title: String,
    records: List<ClipItemRecord>,
    onCopy: (ClipItemRecord) -> Unit,
    onLongPress: (ClipItemRecord) -> Unit,
) {
    if (records.isEmpty()) return

    stickyHeader { FeedSectionHeader(title) }
    itemsIndexed(records, key = { _, it -> it.messageId }) { _, record ->
        FeedClipItem(
            record = record,
            onTap = { onCopy(record) },
            onLongPress = { onLongPress(record) },
        )
    }
}

// ── Section header ────────────────────────────────────────────────────────────

@Composable
private fun FeedSectionHeader(title: String) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White),
    ) {
        Text(
            title,
            fontSize = 16.sp,
            lineHeight = 24.sp,
            fontFamily = BearyFontFamily,
            fontWeight = FontWeight.Normal,
            color = Color(0xFF6F7785),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(top = 0.dp, bottom = 7.dp),
        )
        HorizontalDivider(thickness = 1.dp, color = Color(0xFFEEEFF0))
    }
}

// ── Search bar — pill style ───────────────────────────────────────────────────

@Composable
private fun FeedSearchBar(
    value: String,
    onValueChange: (String) -> Unit,
    filtersVisible: Boolean,
    onFilterToggle: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(56.dp)
            .clip(RoundedCornerShape(28.dp))
            .background(Color(0x33E3E5E8))
            .border(1.dp, Color(0xFFE9EAEC), RoundedCornerShape(28.dp))
            .padding(4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier.size(48.dp),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                painter = painterResource(R.drawable.ic_home_search),
                contentDescription = null,
                tint = Color.Unspecified,
                modifier = Modifier.size(20.dp),
            )
        }

        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            singleLine = true,
            textStyle = MaterialTheme.typography.bodyLarge.copy(
                color = Color(0xFF202327),
                fontSize = 16.sp,
                letterSpacing = 0.15.sp,
            ),
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight(),
            decorationBox = { innerTextField ->
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.CenterStart,
                ) {
                    if (value.isEmpty()) {
                        Text(
                            "Search words or type",
                            color = Color(0xFF9D95A8),
                            fontSize = 16.sp,
                            letterSpacing = 0.15.sp,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                    innerTextField()
                }
            },
        )

        Box(
            modifier = Modifier
                .size(48.dp)
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    onClick = onFilterToggle,
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                painter = painterResource(
                    if (filtersVisible) R.drawable.ic_home_filter_active else R.drawable.ic_home_filter,
                ),
                contentDescription = if (filtersVisible) "Hide filters" else "Show filters",
                tint = Color.Unspecified,
                modifier = Modifier.size(24.dp),
            )
        }
    }
}

// ── Filter chip row ───────────────────────────────────────────────────────────

@Composable
private fun FeedFilterRow(
    selectedKind: ClipKind?,
    onSelectedKind: (ClipKind?) -> Unit,
    modifier: Modifier = Modifier,
) {
    LazyRow(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        contentPadding = PaddingValues(horizontal = 20.dp),
    ) {
        item { FeedChip("All", selectedKind == null) { onSelectedKind(null) } }
        item { FeedChip("Text", selectedKind == ClipKind.TEXT) { onSelectedKind(if (selectedKind == ClipKind.TEXT) null else ClipKind.TEXT) } }
        item { FeedChip("Link", selectedKind == ClipKind.URL) { onSelectedKind(if (selectedKind == ClipKind.URL) null else ClipKind.URL) } }
        item { FeedChip("Image", selectedKind == ClipKind.IMAGE) { onSelectedKind(if (selectedKind == ClipKind.IMAGE) null else ClipKind.IMAGE) } }
        item { FeedChip("Color", selectedKind == ClipKind.COLOR) { onSelectedKind(if (selectedKind == ClipKind.COLOR) null else ClipKind.COLOR) } }
        item { FeedChip("Code", selectedKind == ClipKind.CODE) { onSelectedKind(if (selectedKind == ClipKind.CODE) null else ClipKind.CODE) } }
    }
}

@Composable
private fun FeedChip(label: String, selected: Boolean, onClick: () -> Unit) {
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.95f else 1f,
        animationSpec = spring(stiffness = 500f),
        label = "ChipScale",
    )
    val bg by animateColorAsState(
        if (selected) Color(0xFF2870DC).copy(alpha = 0.08f) else Color.Transparent,
        tween(150),
        "ChipBg",
    )
    val stroke by animateColorAsState(if (selected) Color(0xFF2870DC) else Color(0xFFDADDDF), tween(150), "ChipStroke")
    val tc by animateColorAsState(if (selected) Color(0xFF2870DC) else Color(0xFF4C575C), tween(150), "ChipTc")

    Box(
        modifier = Modifier
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .clip(RoundedCornerShape(20.dp))
            .background(color = bg)
            .border(
                1.dp,
                stroke,
                RoundedCornerShape(20.dp),
            )
            .clickable(interactionSource = interactionSource, indication = null, onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 6.dp),
    ) {
        Text(
            label,
            fontSize = 16.sp,
            lineHeight = 16.sp,
            fontWeight = FontWeight.Normal,
            letterSpacing = 0.125.sp,
            color = tc,
        )
    }
}

// ── Feed item dispatcher ──────────────────────────────────────────────────────

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun FeedClipItem(
    record: ClipItemRecord,
    onTap: () -> Unit,
    onLongPress: () -> Unit,
) {
    val kind = recordKind(record)
    val timeStr = remember(record.timestampMs) { formatTime(record.timestampMs) }
    val sourceName = sourceNameFor(record.fromDeviceId)

    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    val alpha by animateFloatAsState(
        targetValue = if (isPressed) 0.6f else 1f,
        animationSpec = tween(100),
        label = "ItemAlpha",
    )

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .graphicsLayer { this.alpha = alpha }
            .combinedClickable(
                interactionSource = interactionSource,
                indication = null,
                onClick = onTap,
                onLongClick = onLongPress,
            )
            .padding(horizontal = 20.dp),
    ) {
        when (kind) {
            ClipKind.TEXT  -> TextFeedItem(record, sourceName, timeStr)
            ClipKind.URL   -> UrlFeedItem(record, sourceName, timeStr)
            ClipKind.IMAGE -> ImageFeedItem(record, sourceName, timeStr)
            ClipKind.COLOR -> ColorFeedItem(record, sourceName, timeStr)
            ClipKind.CODE  -> CodeFeedItem(record, sourceName, timeStr)
            ClipKind.EMAIL -> TextFeedItem(record, sourceName, timeStr)
        }
    }
}

// ── Item type layouts ─────────────────────────────────────────────────────────

@Composable
private fun TextFeedItem(record: ClipItemRecord, sourceName: String, timeStr: String) {
    Column {
        Spacer(Modifier.height(24.dp))
        Text(
            record.displayText,
            fontSize = 18.sp,
            lineHeight = 27.sp,
            letterSpacing = 0.15.sp,
            color = Color.Black,
            maxLines = 3,
            overflow = TextOverflow.Ellipsis,
        )
        Spacer(Modifier.height(12.dp))
        ItemMeta(sourceName, timeStr)
        HorizontalDivider(thickness = 1.dp, color = Color(0xFFEEEFF0), modifier = Modifier.padding(top = 18.dp))
    }
}

@Composable
private fun UrlFeedItem(record: ClipItemRecord, sourceName: String, timeStr: String) {
    val bitmap = rememberPreviewBitmap(record)
    val hasImagePreview = record.imageDataBase64 != null
    val lines = remember(record.displayText) { record.displayText.lines().map { it.trim() }.filter { it.isNotBlank() } }
    val url = remember(lines, record.displayText) { lines.firstOrNull { it.startsWith("http://") || it.startsWith("https://") } ?: record.displayText }
    val title = remember(lines, url) { lines.firstOrNull { it != url } ?: url.removePrefix("https://").removePrefix("http://") }

    Column {
        Spacer(Modifier.height(24.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            if (hasImagePreview) {
                ImagePreviewBox(
                    bitmap = bitmap,
                    modifier = Modifier
                        .width(178.dp)
                        .height(159.dp),
                )
            } else {
                Box(
                    modifier = Modifier
                        .width(96.dp)
                        .height(96.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(Color(0xFFF7F7F6)),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Outlined.Link, null, tint = Color(0xFFA0A6B1), modifier = Modifier.size(28.dp))
                }
            }
            Column(
                modifier = Modifier
                    .weight(1f)
                    .align(Alignment.CenterVertically),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    title,
                    fontSize = 18.sp,
                    lineHeight = 27.sp,
                    fontWeight = FontWeight.Medium,
                    letterSpacing = 0.15.sp,
                    color = Color.Black,
                    maxLines = 3,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    url,
                    fontSize = 16.sp,
                    lineHeight = 24.sp,
                    color = Color(0xFF5647F2),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    textDecoration = androidx.compose.ui.text.style.TextDecoration.Underline,
                )
            }
        }
        Spacer(Modifier.height(12.dp))
        ItemMeta(sourceName, timeStr)
        HorizontalDivider(thickness = 1.dp, color = Color(0xFFEEEFF0), modifier = Modifier.padding(top = 18.dp))
    }
}

@Composable
private fun ImageFeedItem(record: ClipItemRecord, sourceName: String, timeStr: String) {
    val bitmap = rememberPreviewBitmap(record)
    val hasImagePreview = record.imageDataBase64 != null

    Column {
        Spacer(Modifier.height(24.dp))
        if (hasImagePreview) {
            ImagePreviewBox(
                bitmap = bitmap,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(160.dp),
            )
            Spacer(Modifier.height(8.dp))
        }
        Text(
            record.displayText,
            fontSize = 18.sp,
            lineHeight = 27.sp,
            fontWeight = FontWeight.Medium,
            color = Color.Black,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Spacer(Modifier.height(12.dp))
        ItemMeta(sourceName, timeStr)
        HorizontalDivider(thickness = 1.dp, color = Color(0xFFEEEFF0), modifier = Modifier.padding(top = 18.dp))
    }
}

@Composable
private fun rememberPreviewBitmap(record: ClipItemRecord): Bitmap? {
    val imageData = record.imageDataBase64 ?: return null
    val cacheKey = remember(record.messageId, imageData) { record.messageId }
    return produceState(
        initialValue = ImagePreviewCache.get(cacheKey),
        key1 = cacheKey,
        key2 = imageData,
    ) {
        if (value != null) return@produceState
        value = withContext(Dispatchers.Default) {
            ImageClipboard.decode(imageData)?.also { bitmap ->
                ImagePreviewCache.put(cacheKey, bitmap)
            }
        }
    }.value
}

@Composable
private fun ImagePreviewBox(
    bitmap: Bitmap?,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(10.dp))
            .background(Color(0xFFF7F7F6)),
        contentAlignment = Alignment.Center,
    ) {
        if (bitmap != null) {
            androidx.compose.foundation.Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.matchParentSize(),
            )
        } else {
            Icon(
                Icons.Outlined.Image,
                contentDescription = null,
                tint = Color(0xFFA0A6B1),
                modifier = Modifier.size(28.dp),
            )
        }
    }
}

@Composable
private fun ColorFeedItem(record: ClipItemRecord, sourceName: String, timeStr: String) {
    val parsedColor = parseHexColor(record.displayText) ?: Color(0xFF808080)

    Row(
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        verticalAlignment = Alignment.Top,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 24.dp),
    ) {
        Box(
            modifier = Modifier
                .size(80.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(color = parsedColor),
        )
        Column(modifier = Modifier.weight(1f).heightIn(min = 80.dp), verticalArrangement = Arrangement.Center) {
            Text(
                record.displayText.uppercase(),
                fontSize = 24.sp,
                lineHeight = 36.sp,
                fontWeight = FontWeight.Medium,
                color = Color.Black,
            )
            Spacer(Modifier.height(12.dp))
            ItemMeta(sourceName, timeStr)
        }
    }
    HorizontalDivider(thickness = 1.dp, color = Color(0xFFEEEFF0))
}

@Composable
private fun CodeFeedItem(record: ClipItemRecord, sourceName: String, timeStr: String) {
    Column {
        Spacer(Modifier.height(24.dp))
        Text(
            record.displayText,
            fontSize = 18.sp,
            lineHeight = 27.sp,
            fontWeight = FontWeight.Medium,
            color = Color(0xFF525F7A),
            maxLines = 3,
            overflow = TextOverflow.Ellipsis,
            fontFamily = FontFamily.Monospace,
        )
        Spacer(Modifier.height(12.dp))
        ItemMeta(sourceName, timeStr)
        HorizontalDivider(thickness = 1.dp, color = Color(0xFFEEEFF0), modifier = Modifier.padding(top = 18.dp))
    }
}

// ── Meta row: source · time + bookmark ────────────────────────────────────────

@Composable
private fun ItemMeta(sourceName: String, timeStr: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            sourceName,
            fontSize = 14.sp,
            lineHeight = 16.sp,
            color = Color(0xFF6F7785),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        Spacer(Modifier.width(16.dp))
        Text(
            timeStr,
            fontSize = 14.sp,
            lineHeight = 16.sp,
            color = Color(0xFF6F7785),
            maxLines = 1,
        )
    }
}

// ── Long-press actions ────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ClipActionSheet(
    record: ClipItemRecord,
    onDismiss: () -> Unit,
    onCopy: () -> Unit,
    onSave: () -> Unit,
    onDelete: () -> Unit,
    onOpenLink: () -> Unit,
) {
    val isUrl = recordKind(record) == ClipKind.URL

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = Color.White,
        contentColor = Color(0xFF202327),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 28.dp),
        ) {
            Text(
                "Clipboard item",
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium,
                color = Color(0xFF202327),
                modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp),
            )
            ActionSheetRow(Icons.Outlined.ContentCopy, "Copy", onCopy)
            ActionSheetRow(
                icon = if (record.isSaved) Icons.Outlined.Bookmark else Icons.Outlined.BookmarkBorder,
                label = if (record.isSaved) "Remove from saved" else "Save",
                onClick = onSave,
            )
            if (isUrl) {
                ActionSheetRow(Icons.Outlined.OpenInNew, "Open in browser", onOpenLink)
            }
            ActionSheetRow(Icons.Outlined.Delete, "Delete", onDelete, isDestructive = true)
        }
    }
}

@Composable
private fun ActionSheetRow(
    icon: ImageVector,
    label: String,
    onClick: () -> Unit,
    isDestructive: Boolean = false,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = if (isDestructive) Color(0xFFE5342A) else Color(0xFF6F7785),
            modifier = Modifier.size(22.dp),
        )
        Text(
            label,
            fontSize = 17.sp,
            color = if (isDestructive) Color(0xFFE5342A) else Color(0xFF202327),
        )
    }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

private fun copyRecordToClipboard(context: Context, record: ClipItemRecord) {
    if (runCatching { ImageClipboard.copy(context, record) }.getOrDefault(false)) return
    val mgr = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    mgr.setPrimaryClip(ClipData.newPlainText("AirClip", record.displayText))
}

private fun isToday(timestampMs: Long, now: Long): Boolean {
    val c1 = Calendar.getInstance().apply { timeInMillis = timestampMs }
    val c2 = Calendar.getInstance().apply { timeInMillis = now }
    return c1.get(Calendar.YEAR) == c2.get(Calendar.YEAR) &&
           c1.get(Calendar.DAY_OF_YEAR) == c2.get(Calendar.DAY_OF_YEAR)
}

private fun isYesterday(timestampMs: Long, now: Long): Boolean {
    val item = Calendar.getInstance().apply { timeInMillis = timestampMs }
    val yesterday = Calendar.getInstance().apply {
        timeInMillis = now
        add(Calendar.DAY_OF_YEAR, -1)
    }
    return item.get(Calendar.YEAR) == yesterday.get(Calendar.YEAR) &&
           item.get(Calendar.DAY_OF_YEAR) == yesterday.get(Calendar.DAY_OF_YEAR)
}

private fun isThisWeek(timestampMs: Long, now: Long): Boolean {
    val item = Calendar.getInstance().apply { timeInMillis = timestampMs }
    val current = Calendar.getInstance().apply { timeInMillis = now }
    return item.get(Calendar.YEAR) == current.get(Calendar.YEAR) &&
           item.get(Calendar.WEEK_OF_YEAR) == current.get(Calendar.WEEK_OF_YEAR)
}

private fun openRecordLink(context: Context, record: ClipItemRecord) {
    val url = extractUrl(record.displayText) ?: return
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    runCatching { context.startActivity(intent) }
}

private fun extractUrl(text: String): String? =
    text.lines()
        .map { it.trim() }
        .firstOrNull { it.startsWith("http://") || it.startsWith("https://") }

private val dateFmt = SimpleDateFormat("MMM d", Locale.getDefault())

private fun formatTime(ms: Long): String {
    val now = System.currentTimeMillis()
    val diff = (now - ms).coerceAtLeast(0L)
    val minute = 60_000L
    val hour = 60L * minute
    val day = 24L * hour

    return when {
        diff < minute -> "Just now"
        diff < hour -> "${diff / minute}m ago"
        diff < day -> "${diff / hour}h ago"
        diff < 2L * day -> "Yesterday"
        diff < 7L * day -> "${diff / day}d ago"
        else -> dateFmt.format(Date(ms))
    }
}

private fun parseHexColor(text: String): Color? {
    val match = Regex("""#([0-9A-Fa-f]{3,8})\b""").find(text) ?: return null
    val hex = match.groupValues[1].let { v ->
        if (v.length == 3 || v.length == 4) v.map { "$it$it" }.joinToString("") else v
    }
    if (hex.length != 6 && hex.length != 8) return null
    val v = hex.toLong(16)
    return if (hex.length == 6) Color(
        red   = ((v shr 16) and 0xFFL) / 255f,
        green = ((v shr  8) and 0xFFL) / 255f,
        blue  = (v and 0xFFL) / 255f,
        alpha = 1f,
    ) else Color(
        red   = ((v shr 24) and 0xFFL) / 255f,
        green = ((v shr 16) and 0xFFL) / 255f,
        blue  = ((v shr  8) and 0xFFL) / 255f,
        alpha = (v and 0xFFL) / 255f,
    )
}

private fun recordMatchesSearch(record: ClipItemRecord, query: String): Boolean {
    val n = query.trim()
    if (n.isEmpty()) return true
    val src = sourceNameFor(record.fromDeviceId)
    return record.displayText.contains(n, ignoreCase = true) ||
           record.kind.contains(n, ignoreCase = true) ||
           src.contains(n, ignoreCase = true)
}

private fun sourceNameFor(deviceId: String): String =
    if (deviceId == AirClipIdentity.deviceId) {
        "This device"
    } else {
        AirClipIdentity.deviceNameFor(deviceId) ?: "Remote"
    }

private fun recordKind(record: ClipItemRecord): ClipKind =
    runCatching { ClipKind.valueOf(record.kind) }.getOrDefault(ClipKind.TEXT)
