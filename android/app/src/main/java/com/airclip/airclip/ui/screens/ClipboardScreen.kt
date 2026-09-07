package com.airclip.airclip.ui.screens

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.util.LruCache
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.LocalIndication
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.clickable
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.Notes
import androidx.compose.material.icons.automirrored.outlined.OpenInNew
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
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
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.lerp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.input.nestedscroll.nestedScroll
import com.airclip.airclip.R
import com.airclip.airclip.AirClipIdentity
import com.airclip.airclip.ClipItemRecord
import com.airclip.airclip.ClipKind
import com.airclip.airclip.ImageClipboard
import com.airclip.airclip.MainViewModel
import com.airclip.airclip.SyncMode
import com.airclip.airclip.parseClipboardColor
import com.airclip.airclip.ui.theme.*
import coil.compose.AsyncImage
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

@OptIn(ExperimentalFoundationApi::class, ExperimentalMaterial3Api::class)
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
    var searchQuery by remember { mutableStateOf("") }
    var selectedKind by remember { mutableStateOf<ClipKind?>(null) }
    var savedOnly by remember { mutableStateOf(false) }
    var searchExpanded by remember { mutableStateOf(false) }
    var previewRecord by remember { mutableStateOf<ClipItemRecord?>(null) }
    val collapseRangePx = with(LocalDensity.current) { 112.dp.toPx() }
    val topAppBarState = rememberTopAppBarState(initialHeightOffsetLimit = -collapseRangePx)
    val topAppBarScrollBehavior = TopAppBarDefaults.enterAlwaysScrollBehavior(
        state = topAppBarState,
        canScroll = { !searchExpanded },
    )

    SideEffect {
        topAppBarState.heightOffsetLimit = -collapseRangePx
    }

    LaunchedEffect(searchExpanded) {
        if (searchExpanded) topAppBarState.heightOffset = 0f
    }

    val copyRecord: (ClipItemRecord) -> Unit = { record ->
        viewModel.onHistoryItemCopyStarted(record)
        copyRecordToClipboard(context, record)
        scope.launch { snackbarHostState.showSnackbar("Copied", duration = SnackbarDuration.Short) }
    }

    val groupedItems = remember(uiState.clipHistory, selectedKind, savedOnly, searchQuery) {
        val now = System.currentTimeMillis()
        val filtered = uiState.clipHistory
            .asSequence()
            .filter { selectedKind == null || recordKind(it) == selectedKind }
            .filter { !savedOnly || it.isSaved }
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
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .nestedScroll(topAppBarScrollBehavior.nestedScrollConnection),
        ) {
            HomePageHeader(
                syncMode = uiState.syncMode,
                collapseFraction = if (searchExpanded) 0f else topAppBarState.collapsedFraction,
                searchExpanded = searchExpanded,
                onSearchExpandedChange = { expanded ->
                    searchExpanded = expanded
                    if (!expanded) {
                        searchQuery = ""
                        selectedKind = null
                        savedOnly = false
                    }
                },
                searchQuery = searchQuery,
                onSearchQueryChange = { searchQuery = it },
                selectedKind = selectedKind,
                onSelectedKind = { selectedKind = it },
                savedOnly = savedOnly,
                onSavedOnly = { savedOnly = it },
                onCaptureClipboard = { viewModel.onCaptureClipboard() },
            )

            Box(modifier = Modifier.weight(1f)) {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    state = listState,
                    contentPadding = PaddingValues(bottom = 24.dp),
                ) {
                    if (groupedItems.all.isNotEmpty()) {
                        val openRecord: (ClipItemRecord) -> Unit = { previewRecord = it }
                        feedSection("Today", groupedItems.today, openRecord)
                        feedSection("Yesterday", groupedItems.yesterday, openRecord)
                        feedSection("This Week", groupedItems.thisWeek, openRecord)
                        feedSection("Earlier", groupedItems.earlier, openRecord)
                    }
                }

                if (groupedItems.all.isEmpty()) {
                    AirClipEmptyState(
                        iconRes = R.drawable.ic_home_empty_state,
                        text = if (savedOnly) {
                            "No saved clips"
                        } else if (searchQuery.isNotBlank() || selectedKind != null) {
                            "No results"
                        } else {
                            "Airclip is ready. Copy on one device, to use it on another."
                        },
                    )
                }
            }
        }
    }

    previewRecord?.let { record ->
        ClipPreviewSheet(
            record = record,
            onDismiss = { previewRecord = null },
            onCopy = { copyRecord(record) },
            onOpenLink = { openRecordLink(context, record) },
            onSave = {
                viewModel.onToggleSaved(record)
                previewRecord = record.copy(isSaved = !record.isSaved)
            },
            onDelete = {
                val restorable = ImageClipboard.withInlineData(context, record)
                previewRecord = null
                viewModel.onDeleteClip(record) {
                    scope.launch {
                        val result = snackbarHostState.showSnackbar(
                            message = "Deleted",
                            actionLabel = "Undo",
                            duration = SnackbarDuration.Long,
                        )
                        if (result == SnackbarResult.ActionPerformed) viewModel.onRestoreClip(restorable)
                    }
                }
            },
        )
    }
}

@Composable
private fun HomePageHeader(
    syncMode: SyncMode,
    collapseFraction: Float,
    searchExpanded: Boolean,
    onSearchExpandedChange: (Boolean) -> Unit,
    searchQuery: String,
    onSearchQueryChange: (String) -> Unit,
    selectedKind: ClipKind?,
    onSelectedKind: (ClipKind?) -> Unit,
    savedOnly: Boolean,
    onSavedOnly: (Boolean) -> Unit,
    onCaptureClipboard: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val c = LocalAirClipColors.current
    val statusBarTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val progress = collapseFraction.coerceIn(0f, 1f)
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(c.bgBase)
            .padding(top = statusBarTop),
    ) {
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxWidth()
                .height(lerp(200.dp, 88.dp, progress))
                .clipToBounds(),
        ) {
            Text(
                "Airclip",
                fontSize = (36f - 4f * progress).sp,
                lineHeight = 44.sp,
                fontFamily = BearyFontFamily,
                fontWeight = FontWeight.Normal,
                color = c.textPrimary,
                letterSpacing = 0.sp,
                modifier = Modifier
                    .offset(x = 24.dp)
                    .height(88.dp)
                    .wrapContentHeight(Alignment.CenterVertically),
            )

            if (syncMode == SyncMode.MANUAL_ONLY && !searchExpanded) {
                IconButton(
                    onClick = onCaptureClipboard,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(top = 16.dp, end = 72.dp)
                        .graphicsLayer { alpha = 1f - progress },
                ) {
                    Icon(
                        painter = painterResource(R.drawable.ic_home_clipboard_sync),
                        contentDescription = "Sync clipboard",
                        tint = c.textSecondary,
                        modifier = Modifier.size(24.dp),
                    )
                }
            }

            val searchWidth = lerp(maxWidth - 48.dp, 56.dp, progress)
            val searchX = lerp(24.dp, maxWidth - 72.dp, progress)
            val searchY = lerp(88.dp, 16.dp, progress)
            Box(
                modifier = Modifier
                    .offset(x = searchX, y = searchY)
                    .width(searchWidth)
                    .height(56.dp),
            ) {
                if (searchExpanded) {
                    FeedSearchBar(
                        value = searchQuery,
                        onValueChange = onSearchQueryChange,
                        onClose = { onSearchExpandedChange(false) },
                    )
                } else {
                    HomeSearchPrompt(
                        collapseFraction = progress,
                        onOpen = { onSearchExpandedChange(true) },
                        onFilter = { onSearchExpandedChange(true) },
                    )
                }
            }

            FeedFilterRow(
                selectedKind = selectedKind,
                onSelectedKind = onSelectedKind,
                savedOnly = savedOnly,
                onSavedOnly = onSavedOnly,
                modifier = Modifier
                    .offset(y = 144.dp)
                    .height(56.dp)
                    .fillMaxWidth()
                    .graphicsLayer { alpha = (1f - progress / 0.55f).coerceIn(0f, 1f) },
            )
        }
    }
}

@Composable
private fun HomeSearchPrompt(
    collapseFraction: Float,
    onOpen: () -> Unit,
    onFilter: () -> Unit,
) {
    val c = LocalAirClipColors.current
    val detailAlpha = (1f - collapseFraction / 0.65f).coerceIn(0f, 1f)

    Row(
        modifier = Modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(28.dp))
            .background(c.bgElevated.copy(alpha = 1f - collapseFraction))
            .border(1.dp, c.borderSubtle.copy(alpha = 1f - collapseFraction), RoundedCornerShape(28.dp))
            .clickable(role = Role.Button, onClick = onOpen)
            .padding(4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(modifier = Modifier.size(48.dp), contentAlignment = Alignment.Center) {
            Icon(
                painter = painterResource(R.drawable.ic_home_search),
                contentDescription = "Search clipboard",
                tint = c.textSecondary,
                modifier = Modifier.size(lerp(20.dp, 24.dp, collapseFraction)),
            )
        }
        Text(
            "Search words or type",
            color = c.textTertiary,
            fontSize = 16.sp,
            lineHeight = 24.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier
                .weight(1f)
                .graphicsLayer { alpha = detailAlpha },
        )
        IconButton(
            onClick = onFilter,
            enabled = detailAlpha > 0.1f,
            modifier = Modifier.graphicsLayer { alpha = detailAlpha },
        ) {
            Icon(
                painter = painterResource(R.drawable.ic_home_filter),
                contentDescription = "Show filters",
                tint = c.textSecondary,
                modifier = Modifier.size(24.dp),
            )
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
private fun LazyListScope.feedSection(
    title: String,
    records: List<ClipItemRecord>,
    onOpen: (ClipItemRecord) -> Unit,
) {
    if (records.isEmpty()) return

    stickyHeader { FeedSectionHeader(title) }
    itemsIndexed(records, key = { _, it -> it.messageId }) { _, record ->
        FeedClipItem(
            record = record,
            onOpen = { onOpen(record) },
            onLongPress = { onOpen(record) },
        )
    }
}

// ── Section header ────────────────────────────────────────────────────────────

@Composable
private fun FeedSectionHeader(title: String) {
    val c = LocalAirClipColors.current
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(c.bgBase),
    ) {
        Text(
            title,
            fontSize = 16.sp,
            lineHeight = 24.sp,
            fontFamily = BearyFontFamily,
            fontWeight = FontWeight.Normal,
            color = c.textSecondary,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 12.dp),
        )
        HorizontalDivider(thickness = 1.dp, color = c.borderSubtle)
    }
}

// ── Search bar — pill style ───────────────────────────────────────────────────

@Composable
private fun FeedSearchBar(
    value: String,
    onValueChange: (String) -> Unit,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val c = LocalAirClipColors.current
    val focusRequester = remember { FocusRequester() }
    val keyboardController = LocalSoftwareKeyboardController.current

    LaunchedEffect(Unit) {
        focusRequester.requestFocus()
        keyboardController?.show()
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(56.dp)
            .clip(RoundedCornerShape(28.dp))
            .background(c.bgElevated)
            .border(1.dp, c.borderSubtle, RoundedCornerShape(28.dp))
            .padding(4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(onClick = onClose, modifier = Modifier.size(48.dp)) {
            Icon(
                Icons.AutoMirrored.Outlined.ArrowBack,
                contentDescription = "Close search",
                tint = c.textSecondary,
                modifier = Modifier.size(24.dp),
            )
        }

        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            singleLine = true,
            textStyle = MaterialTheme.typography.bodyLarge.copy(
                color = c.textPrimary,
                fontSize = 16.sp,
                letterSpacing = 0.15.sp,
            ),
            modifier = Modifier
                .weight(1f)
                .focusRequester(focusRequester)
                .fillMaxHeight(),
            decorationBox = { innerTextField ->
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.CenterStart,
                ) {
                    if (value.isEmpty()) {
                        Text(
                            "Search clips",
                            color = c.textTertiary,
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
            modifier = Modifier.size(40.dp),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                painter = painterResource(R.drawable.ic_home_filter_active),
                contentDescription = null,
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
    savedOnly: Boolean,
    onSavedOnly: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    LazyRow(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        contentPadding = PaddingValues(horizontal = 24.dp, vertical = 9.dp),
    ) {
        item {
            FeedChip("All", selectedKind == null && !savedOnly) {
                onSelectedKind(null)
                onSavedOnly(false)
            }
        }
        item { FeedChip("Saved", savedOnly) { onSavedOnly(!savedOnly) } }
        item { FeedChip("Text", selectedKind == ClipKind.TEXT) { onSelectedKind(if (selectedKind == ClipKind.TEXT) null else ClipKind.TEXT) } }
        item { FeedChip("Link", selectedKind == ClipKind.URL) { onSelectedKind(if (selectedKind == ClipKind.URL) null else ClipKind.URL) } }
        item { FeedChip("Image", selectedKind == ClipKind.IMAGE) { onSelectedKind(if (selectedKind == ClipKind.IMAGE) null else ClipKind.IMAGE) } }
        item { FeedChip("Color", selectedKind == ClipKind.COLOR) { onSelectedKind(if (selectedKind == ClipKind.COLOR) null else ClipKind.COLOR) } }
    }
}

@Composable
private fun FeedChip(label: String, selected: Boolean, onClick: () -> Unit) {
    val c = LocalAirClipColors.current
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.95f else 1f,
        animationSpec = spring(stiffness = 500f),
        label = "ChipScale",
    )
    val bg by animateColorAsState(
        if (selected) c.blue.copy(alpha = 0.08f) else Color.Transparent,
        tween(150),
        "ChipBg",
    )
    val stroke by animateColorAsState(if (selected) c.blue else c.borderDefault, tween(150), "ChipStroke")
    val tc by animateColorAsState(if (selected) c.blue else c.textSecondary, tween(150), "ChipTc")

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
            .clickable(
                interactionSource = interactionSource,
                indication = LocalIndication.current,
                role = Role.Button,
                onClick = onClick,
            )
            .padding(horizontal = 13.dp, vertical = 7.dp),
    ) {
        Text(
            label,
            fontSize = 14.sp,
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
    onOpen: () -> Unit,
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
                indication = LocalIndication.current,
                onClickLabel = "Preview clipboard item",
                onLongClickLabel = "Show clipboard item actions",
                onClick = onOpen,
                onLongClick = onLongPress,
            )
            .padding(horizontal = 24.dp),
    ) {
        when (kind) {
            ClipKind.TEXT  -> TextFeedItem(record, sourceName, timeStr)
            ClipKind.URL   -> UrlFeedItem(record, sourceName, timeStr)
            ClipKind.IMAGE -> ImageFeedItem(record, sourceName, timeStr)
            ClipKind.COLOR -> ColorFeedItem(record, sourceName, timeStr)
            ClipKind.CODE  -> TextFeedItem(record, sourceName, timeStr)
            ClipKind.EMAIL -> TextFeedItem(record, sourceName, timeStr)
        }
    }
}

// ── Item type layouts ─────────────────────────────────────────────────────────

@Composable
private fun TextFeedItem(record: ClipItemRecord, sourceName: String, timeStr: String) {
    val c = LocalAirClipColors.current
    Column {
        Column(Modifier.padding(vertical = 20.dp)) {
            Text(
                record.displayText,
                fontSize = 18.sp,
                lineHeight = 27.sp,
                letterSpacing = 0.15.sp,
                color = c.textPrimary,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(8.dp))
            ItemMeta(sourceName, timeStr)
        }
        HorizontalDivider(thickness = 1.dp, color = c.borderSubtle)
    }
}

private data class LinkPreviewData(val url: String, val title: String, val site: String, val imageUrl: String?)

@Composable
private fun rememberLinkPreview(record: ClipItemRecord): LinkPreviewData {
    val lines = remember(record.displayText) { record.displayText.lines().map(String::trim).filter(String::isNotBlank) }
    val url = remember(lines, record.displayText) {
        lines.firstOrNull { it.startsWith("http://") || it.startsWith("https://") } ?: record.displayText
    }
    val fallbackTitle = remember(lines, url) {
        lines.firstOrNull { it != url } ?: url.removePrefix("https://").removePrefix("http://")
    }
    val metadata by produceState<UrlMetadata?>(initialValue = null, key1 = url) {
        value = UrlMetadataLoader.load(url)
    }
    return LinkPreviewData(
        url = url,
        title = metadata?.title ?: fallbackTitle,
        site = metadata?.site?.takeIf(String::isNotBlank) ?: Uri.parse(url).host?.removePrefix("www.") ?: url,
        imageUrl = metadata?.imageUrl,
    )
}

@Composable
private fun LinkPreview(preview: LinkPreviewData, modifier: Modifier = Modifier) {
    val c = LocalAirClipColors.current
    Row(modifier = modifier, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(
            modifier = Modifier
                .size(96.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(c.bgElevated)
                .border(0.5.dp, c.borderSubtle, RoundedCornerShape(10.dp)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Outlined.Link, null, tint = c.textTertiary, modifier = Modifier.size(28.dp))
            preview.imageUrl?.let {
                AsyncImage(
                    model = it,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.matchParentSize(),
                )
            }
        }
        Column(
            modifier = Modifier.weight(1f).align(Alignment.CenterVertically),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                preview.title,
                fontSize = 18.sp,
                lineHeight = 27.sp,
                fontWeight = FontWeight.Medium,
                color = c.textPrimary,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(preview.site, fontSize = 14.sp, lineHeight = 20.sp, color = c.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
}

@Composable
private fun UrlFeedItem(record: ClipItemRecord, sourceName: String, timeStr: String) {
    val c = LocalAirClipColors.current
    val preview = rememberLinkPreview(record)
    Column {
        Column(Modifier.padding(vertical = 20.dp)) {
            LinkPreview(preview, Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp))
            ItemMeta(sourceName, timeStr)
        }
        HorizontalDivider(thickness = 1.dp, color = c.borderSubtle)
    }
}

@Composable
private fun ImageFeedItem(record: ClipItemRecord, sourceName: String, timeStr: String) {
    val c = LocalAirClipColors.current
    val bitmap = rememberPreviewBitmap(record)
    val name = record.imageFileName ?: record.displayText.takeIf { !it.startsWith("Image ") } ?: "Image"
    Column {
        Column(Modifier.padding(vertical = 20.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
                ImagePreviewBox(bitmap = bitmap, modifier = Modifier.size(96.dp))
                Column(
                    modifier = Modifier.weight(1f).align(Alignment.CenterVertically),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(name, fontSize = 18.sp, lineHeight = 27.sp, fontWeight = FontWeight.Medium, color = c.textPrimary, maxLines = 2, overflow = TextOverflow.Ellipsis)
                    bitmap?.let {
                        Text(
                            "${it.width} × ${it.height} px · ${String.format(Locale.US, "%.2f", it.width.toFloat() / it.height)}:1",
                            fontSize = 14.sp,
                            lineHeight = 20.sp,
                            color = c.textSecondary,
                        )
                    }
                }
            }
            Spacer(Modifier.height(8.dp))
            ItemMeta(sourceName, timeStr)
        }
        HorizontalDivider(thickness = 1.dp, color = c.borderSubtle)
    }
}

@Composable
private fun rememberPreviewBitmap(record: ClipItemRecord): Bitmap? {
    if (record.imageDataBase64 == null && record.imageFileName == null) return null
    val context = LocalContext.current.applicationContext
    val cacheKey = remember(record.messageId, record.imageDataBase64, record.imageFileName) { record.messageId }
    return produceState(
        initialValue = ImagePreviewCache.get(cacheKey),
        key1 = cacheKey,
        key2 = record.imageFileName,
    ) {
        if (value != null) return@produceState
        value = withContext(Dispatchers.Default) {
            ImageClipboard.decode(context, record)?.also { bitmap ->
                ImagePreviewCache.put(cacheKey, bitmap)
            }
        }
    }.value
}

@Composable
private fun ImagePreviewBox(
    bitmap: Bitmap?,
    contentScale: ContentScale = ContentScale.Crop,
    modifier: Modifier = Modifier,
) {
    val c = LocalAirClipColors.current
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(10.dp))
            .background(c.bgElevated)
            .border(0.5.dp, c.borderSubtle, RoundedCornerShape(10.dp)),
        contentAlignment = Alignment.Center,
    ) {
        if (bitmap != null) {
            androidx.compose.foundation.Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = null,
                contentScale = contentScale,
                modifier = Modifier.matchParentSize(),
            )
        } else {
            Icon(
                Icons.Outlined.Image,
                contentDescription = null,
                tint = c.textTertiary,
                modifier = Modifier.size(28.dp),
            )
        }
    }
}

@Composable
private fun ColorFeedItem(record: ClipItemRecord, sourceName: String, timeStr: String) {
    val c = LocalAirClipColors.current
    val parsedColor = parseClipboardColor(record.displayText)?.let(::Color) ?: Color(0xFF808080)

    Column {
        Row(
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalAlignment = Alignment.Top,
            modifier = Modifier.fillMaxWidth().padding(vertical = 20.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(80.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(color = parsedColor)
                    .border(0.5.dp, c.borderSubtle, RoundedCornerShape(12.dp)),
            )
            Column(modifier = Modifier.weight(1f).heightIn(min = 80.dp), verticalArrangement = Arrangement.Center) {
                Text(
                    record.displayText,
                    fontSize = 20.sp,
                    lineHeight = 28.sp,
                    fontWeight = FontWeight.Medium,
                    color = c.textPrimary,
                )
                Spacer(Modifier.height(8.dp))
                ItemMeta(sourceName, timeStr)
            }
        }
        HorizontalDivider(thickness = 1.dp, color = c.borderSubtle)
    }
}

// ── Meta row ──────────────────────────────────────────────────────────────────

@Composable
private fun ItemMeta(sourceName: String, timeStr: String) {
    val c = LocalAirClipColors.current
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            sourceName,
            fontSize = 14.sp,
            lineHeight = 16.sp,
            color = c.textSecondary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        Spacer(Modifier.width(16.dp))
        Text(
            timeStr,
            fontSize = 14.sp,
            lineHeight = 16.sp,
            color = c.textSecondary,
            maxLines = 1,
        )
    }
}

// ── Item preview ──────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ClipPreviewSheet(
    record: ClipItemRecord,
    onDismiss: () -> Unit,
    onCopy: () -> Unit,
    onOpenLink: () -> Unit,
    onSave: () -> Unit,
    onDelete: () -> Unit,
) {
    val c = LocalAirClipColors.current
    val kind = recordKind(record)
    val bitmap = if (kind == ClipKind.IMAGE) rememberPreviewBitmap(record) else null
    val linkPreview = if (kind == ClipKind.URL) rememberLinkPreview(record) else null
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = c.bgFloating,
        contentColor = c.textPrimary,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.86f)
                .navigationBarsPadding()
                .padding(horizontal = 24.dp, vertical = 20.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(sourceNameFor(record.fromDeviceId), fontSize = 14.sp, lineHeight = 20.sp, color = c.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                Spacer(Modifier.width(16.dp))
                Text(formatTime(record.timestampMs), fontSize = 14.sp, lineHeight = 20.sp, color = c.textSecondary)
            }

            Spacer(Modifier.height(20.dp))

            Box(modifier = Modifier.weight(1f).fillMaxWidth()) {
                when (kind) {
                    ClipKind.URL -> linkPreview?.let { LinkPreview(it, Modifier.fillMaxWidth()) }
                    ClipKind.IMAGE -> Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        ImagePreviewBox(
                            bitmap = bitmap,
                            contentScale = ContentScale.Fit,
                            modifier = Modifier.fillMaxWidth().heightIn(min = 220.dp, max = 360.dp),
                        )
                        val name = record.imageFileName ?: record.displayText.takeIf { !it.startsWith("Image ") } ?: "Image"
                        Text(name, fontSize = 18.sp, lineHeight = 27.sp, fontWeight = FontWeight.Medium, color = c.textPrimary)
                        bitmap?.let {
                            Text("${it.width} × ${it.height} px · ${String.format(Locale.US, "%.2f", it.width.toFloat() / it.height)}:1", fontSize = 14.sp, color = c.textSecondary)
                        }
                    }
                    ClipKind.COLOR -> {
                        val color = parseClipboardColor(record.displayText)?.let(::Color) ?: Color(0xFF808080)
                        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                            Box(Modifier.fillMaxWidth().height(180.dp).clip(RoundedCornerShape(12.dp)).background(color).border(0.5.dp, c.borderSubtle, RoundedCornerShape(12.dp)))
                            Text(record.displayText, fontSize = 24.sp, lineHeight = 32.sp, fontWeight = FontWeight.Medium)
                        }
                    }
                    else -> SelectionContainer {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .heightIn(max = 440.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .background(c.bgElevated)
                                .verticalScroll(rememberScrollState())
                                .padding(16.dp),
                        ) {
                            Text(record.displayText, fontSize = 18.sp, lineHeight = 28.sp, color = c.textPrimary)
                        }
                    }
                }
            }

            Spacer(Modifier.height(20.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Button(
                    onClick = onCopy,
                    modifier = Modifier
                        .weight(1f)
                        .height(52.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = c.textPrimary,
                        contentColor = c.bgBase,
                    ),
                ) {
                    Icon(Icons.Outlined.ContentCopy, contentDescription = null, modifier = Modifier.size(20.dp))
                    Spacer(Modifier.width(8.dp))
                    Text("Copy")
                }
                if (kind == ClipKind.URL) {
                    PreviewIconButton(Icons.AutoMirrored.Outlined.OpenInNew, "Visit link", onOpenLink)
                }
                PreviewIconButton(
                    icon = if (record.isSaved) Icons.Outlined.Bookmark else Icons.Outlined.BookmarkBorder,
                    description = if (record.isSaved) "Remove from saved" else "Save",
                    onClick = onSave,
                    tint = if (record.isSaved) c.blue else c.textSecondary,
                )
                PreviewIconButton(Icons.Outlined.Delete, "Delete", onDelete, c.destructive)
            }
        }
    }
}

@Composable
private fun PreviewIconButton(
    icon: ImageVector,
    description: String,
    onClick: () -> Unit,
    tint: Color = Color.Unspecified,
) {
    val c = LocalAirClipColors.current
    IconButton(
        onClick = onClick,
        modifier = Modifier
            .size(52.dp)
            .border(1.dp, c.borderDefault, RoundedCornerShape(12.dp)),
    ) {
        Icon(
            icon,
            contentDescription = description,
            tint = if (tint == Color.Unspecified) c.textSecondary else tint,
            modifier = Modifier.size(22.dp),
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
        .let {
            when {
                it == ClipKind.CODE -> ClipKind.TEXT
                it == ClipKind.TEXT && parseClipboardColor(record.displayText) != null -> ClipKind.COLOR
                else -> it
            }
        }
