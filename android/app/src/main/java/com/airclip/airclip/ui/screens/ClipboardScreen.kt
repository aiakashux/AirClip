package com.airclip.airclip.ui.screens

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import android.util.Base64
import android.net.Uri
import android.util.LruCache
import androidx.annotation.DrawableRes
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.Crossfade
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.togetherWith
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.foundation.Image
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
import androidx.compose.material3.pulltorefresh.PullToRefreshState
import androidx.compose.material3.pulltorefresh.rememberPullToRefreshState
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.lerp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.viewinterop.AndroidView
import com.airclip.airclip.R
import com.airclip.airclip.AirclipIdentity
import com.airclip.airclip.ClipItemRecord
import com.airclip.airclip.ClipKind
import com.airclip.airclip.ImageClipboard
import com.airclip.airclip.MainViewModel
import com.airclip.airclip.SyncEngine
import com.airclip.airclip.FILE_PREVIEW_MAX_BYTES
import com.airclip.airclip.SyncMode
import com.airclip.airclip.parseClipboardColor
import com.airclip.airclip.ui.theme.*
import coil.compose.AsyncImage
import coil.compose.AsyncImagePainter
import coil.compose.rememberAsyncImagePainter
import coil.request.ImageRequest
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.io.File
import java.util.*
import android.media.MediaPlayer
import android.widget.MediaController
import android.widget.VideoView
import androidx.core.content.FileProvider

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
    val c = LocalAirclipColors.current
    val alertHostState = LocalAirclipAlertHostState.current
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var searchQuery by remember { mutableStateOf("") }
    var selectedKind by remember { mutableStateOf<ClipKind?>(null) }
    var savedOnly by remember { mutableStateOf(false) }
    var searchExpanded by remember { mutableStateOf(false) }
    var filtersVisible by remember { mutableStateOf(false) }
    var previewRecord by remember { mutableStateOf<ClipItemRecord?>(null) }
    val collapseRangePx = with(LocalDensity.current) {
        (if (filtersVisible) 116.dp else 56.dp).toPx()
    }
    val topAppBarState = rememberTopAppBarState(initialHeightOffsetLimit = -collapseRangePx)
    val topAppBarScrollBehavior = TopAppBarDefaults.enterAlwaysScrollBehavior(
        state = topAppBarState,
        canScroll = { !searchExpanded },
    )
    val pullToRefreshState = rememberPullToRefreshState(
        enabled = {
            !searchExpanded &&
                listState.firstVisibleItemIndex == 0 &&
                listState.firstVisibleItemScrollOffset == 0
        },
    )

    LaunchedEffect(pullToRefreshState.isRefreshing) {
        if (pullToRefreshState.isRefreshing) {
            viewModel.onRefreshClipboard { pullToRefreshState.endRefresh() }
        }
    }

    SideEffect {
        topAppBarState.heightOffsetLimit = -collapseRangePx
    }

    LaunchedEffect(searchExpanded) {
        if (searchExpanded) topAppBarState.heightOffset = 0f
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
                filtersVisible = filtersVisible,
                onSearchExpandedChange = { expanded ->
                    searchExpanded = expanded
                    if (!expanded) {
                        searchQuery = ""
                        selectedKind = null
                        savedOnly = false
                    }
                },
                onFiltersVisibleChange = { filtersVisible = !filtersVisible },
                searchQuery = searchQuery,
                onSearchQueryChange = { searchQuery = it },
                selectedKind = selectedKind,
                onSelectedKind = { selectedKind = it },
                savedOnly = savedOnly,
                onSavedOnly = { savedOnly = it },
                onCaptureClipboard = { viewModel.onCaptureClipboard() },
            )

            Box(
                modifier = Modifier
                    .weight(1f)
                    .nestedScroll(pullToRefreshState.nestedScrollConnection),
            ) {
                AnimatedContent(
                    targetState = groupedItems.all.isEmpty(),
                    modifier = Modifier
                        .fillMaxSize()
                        .graphicsLayer { translationY = pullToRefreshState.verticalOffset },
                    transitionSpec = { fadeIn(tween(150)) togetherWith fadeOut(tween(120)) },
                    label = "clipboard results",
                ) { isEmpty ->
                    if (!isEmpty) {
                        LazyColumn(
                            modifier = Modifier.fillMaxSize(),
                            state = listState,
                            contentPadding = PaddingValues(bottom = 24.dp),
                        ) {
                            val openRecord: (ClipItemRecord) -> Unit = { previewRecord = it }
                            val animateRemoteInsertion = uiState.remoteInsertionId != null &&
                                groupedItems.all.any { it.messageId == uiState.remoteInsertionId }
                            feedSection("Today", groupedItems.today, openRecord, animateRemoteInsertion)
                            feedSection("Yesterday", groupedItems.yesterday, openRecord, animateRemoteInsertion)
                            feedSection("This Week", groupedItems.thisWeek, openRecord, animateRemoteInsertion)
                            feedSection("Earlier", groupedItems.earlier, openRecord, animateRemoteInsertion)
                        }
                    } else {
                        AirclipEmptyState(
                            iconRes = R.drawable.ic_home_empty_state,
                            text = if (savedOnly) {
                                "No saved clips"
                            } else if (searchQuery.isNotBlank() || selectedKind != null) {
                                "No results"
                            } else {
                                "Copy something on either device. It will appear here automatically."
                            },
                        )
                    }
                }
                if (pullToRefreshState.progress > 0f || pullToRefreshState.isRefreshing) {
                    AirclipPullToRefreshIndicator(
                        state = pullToRefreshState,
                        modifier = Modifier.align(Alignment.TopCenter),
                    )
                }
            }
        }
    }

    previewRecord?.let { record ->
        ClipPreviewSheet(
            record = record,
            onDismiss = { previewRecord = null },
            onCopy = {
                viewModel.onHistoryItemCopyStarted(record)
                copyRecordToClipboard(context, record)
            },
            onFileAction = {
                if (SyncEngine.availableFile(record) != null) openRecordFile(context, record)
                else SyncEngine.downloadFile(record)
            },
            onOpenLink = { openRecordLink(context, record) },
            onSave = {
                viewModel.onToggleSaved(record)
                previewRecord = record.copy(isSaved = !record.isSaved)
            },
            onDelete = {
                previewRecord = null
                viewModel.onDeleteClip(record) {
                    scope.launch {
                        alertHostState.show(message = "Deleted")
                    }
                }
            },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AirclipPullToRefreshIndicator(
    state: PullToRefreshState,
    modifier: Modifier = Modifier,
) {
    val c = LocalAirclipColors.current
    val indicatorSize = 28.dp
    val indicatorSizePx = with(LocalDensity.current) { indicatorSize.toPx() }

    if (state.isRefreshing) {
        CircularProgressIndicator(
            modifier = modifier
                .size(indicatorSize)
                .graphicsLayer { translationY = state.verticalOffset - indicatorSizePx },
            color = c.accent,
            strokeWidth = 2.dp,
            trackColor = Color.Transparent,
        )
    } else {
        CircularProgressIndicator(
            progress = { state.progress.coerceIn(0f, 1f) },
            modifier = modifier
                .size(indicatorSize)
                .graphicsLayer { translationY = state.verticalOffset - indicatorSizePx },
            color = c.accent,
            strokeWidth = 2.dp,
            trackColor = Color.Transparent,
        )
    }
}

@Composable
private fun HomePageHeader(
    syncMode: SyncMode,
    collapseFraction: Float,
    searchExpanded: Boolean,
    filtersVisible: Boolean,
    onSearchExpandedChange: (Boolean) -> Unit,
    onFiltersVisibleChange: () -> Unit,
    searchQuery: String,
    onSearchQueryChange: (String) -> Unit,
    selectedKind: ClipKind?,
    onSelectedKind: (ClipKind?) -> Unit,
    savedOnly: Boolean,
    onSavedOnly: (Boolean) -> Unit,
    onCaptureClipboard: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val c = LocalAirclipColors.current
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
                .height(lerp(if (filtersVisible) 196.dp else 136.dp, 60.dp, progress))
                .clipToBounds(),
        ) {
            Text(
                "Airclip",
                fontSize = 36.sp,
                lineHeight = 40.sp,
                fontFamily = BearyFontFamily,
                fontWeight = FontWeight.Normal,
                color = c.textPrimary,
                letterSpacing = (-0.6).sp,
                modifier = Modifier
                    .offset(x = 20.dp, y = 20.dp)
                    .height(40.dp)
                    .semantics { heading() },
            )

            if (syncMode == SyncMode.MANUAL_ONLY && !searchExpanded) {
                IconButton(
                    onClick = onCaptureClipboard,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(top = 16.dp, end = 68.dp)
                        .graphicsLayer { alpha = 1f - progress },
                ) {
                    Icon(
                        painter = painterResource(R.drawable.ic_settings_database_sync),
                        contentDescription = "Sync clipboard",
                        tint = c.textSecondary,
                        modifier = Modifier.size(24.dp),
                    )
                }
            }

            val searchSize = lerp(56.dp, 40.dp, progress)
            val searchWidth = lerp(maxWidth - 40.dp, searchSize, progress)
            val searchX = lerp(20.dp, maxWidth - 60.dp, progress)
            val searchY = lerp(80.dp, 20.dp, progress)
            Box(
                modifier = Modifier
                    .offset(x = searchX, y = searchY)
                    .width(searchWidth)
                    .height(searchSize),
            ) {
                Crossfade(targetState = searchExpanded, animationSpec = tween(120), label = "search handoff") { expanded ->
                    if (expanded) {
                        FeedSearchBar(
                            value = searchQuery,
                            onValueChange = onSearchQueryChange,
                            onClose = { onSearchExpandedChange(false) },
                            filtersVisible = filtersVisible,
                            onFilter = onFiltersVisibleChange,
                        )
                    } else {
                        HomeSearchPrompt(
                            collapseFraction = progress,
                            onOpen = { onSearchExpandedChange(true) },
                            filtersVisible = filtersVisible,
                            onFilter = onFiltersVisibleChange,
                        )
                    }
                }
            }

            androidx.compose.animation.AnimatedVisibility(
                visible = filtersVisible,
                enter = fadeIn(tween(180)) + expandVertically(tween(180)),
                exit = fadeOut(tween(120)) + shrinkVertically(tween(140)),
            ) {
                FeedFilterRow(
                    selectedKind = selectedKind,
                    onSelectedKind = onSelectedKind,
                    savedOnly = savedOnly,
                    onSavedOnly = onSavedOnly,
                    modifier = Modifier
                        .offset(y = 136.dp)
                        .height(60.dp)
                        .fillMaxWidth()
                        .graphicsLayer { alpha = (1f - progress / 0.55f).coerceIn(0f, 1f) },
                )
            }
        }
    }
}

@Composable
private fun HomeSearchPrompt(
    collapseFraction: Float,
    onOpen: () -> Unit,
    filtersVisible: Boolean,
    onFilter: () -> Unit,
) {
    val c = LocalAirclipColors.current
    val detailAlpha = (1f - collapseFraction / 0.65f).coerceIn(0f, 1f)
    val searchBackground = if (c.isDark) c.bgElevated else Color(0xFFE3E5E8).copy(alpha = 0.2f)
    val searchBorder = if (c.isDark) c.borderSubtle else Color(0xFFE9EAEC)
    val placeholderColor = if (c.isDark) c.textTertiary else Color(0xFF9D95A8)

    Row(
        modifier = Modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(28.dp))
            .background(searchBackground.copy(alpha = searchBackground.alpha * (1f - collapseFraction)))
            .border(
                1.dp,
                searchBorder.copy(alpha = searchBorder.alpha * (1f - collapseFraction)),
                RoundedCornerShape(28.dp),
            )
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
            color = placeholderColor,
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
                painter = painterResource(if (filtersVisible) R.drawable.ic_home_filter_active else R.drawable.ic_home_filter),
                contentDescription = "Show filters",
                tint = if (filtersVisible) c.textPrimary else c.textSecondary,
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
    animateRemoteInsertion: Boolean,
) {
    if (records.isEmpty()) return

    stickyHeader { FeedSectionHeader(title) }
    itemsIndexed(records, key = { _, it -> it.messageId }) { _, record ->
        FeedClipItem(
            record = record,
            onOpen = { onOpen(record) },
            onLongPress = { onOpen(record) },
            modifier = if (animateRemoteInsertion) {
                Modifier.animateItemPlacement(spring(dampingRatio = 0.82f))
            } else Modifier,
        )
    }
}

// ── Section header ────────────────────────────────────────────────────────────

@Composable
private fun FeedSectionHeader(title: String) {
    val c = LocalAirclipColors.current
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
    filtersVisible: Boolean,
    onFilter: () -> Unit,
) {
    val c = LocalAirclipColors.current
    val focusRequester = remember { FocusRequester() }
    val keyboardController = LocalSoftwareKeyboardController.current

    LaunchedEffect(Unit) {
        focusRequester.requestFocus()
        keyboardController?.show()
    }

    Row(
        modifier = Modifier
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

        IconButton(onClick = onFilter, modifier = Modifier.size(48.dp)) {
            Icon(
                painter = painterResource(if (filtersVisible) R.drawable.ic_home_filter_active else R.drawable.ic_home_filter),
                contentDescription = "Show filters",
                tint = if (filtersVisible) c.textPrimary else c.textSecondary,
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
        contentPadding = PaddingValues(horizontal = 24.dp, vertical = 14.dp),
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
        item { FeedChip("Files", selectedKind == ClipKind.FILE) { onSelectedKind(if (selectedKind == ClipKind.FILE) null else ClipKind.FILE) } }
        item { FeedChip("Color", selectedKind == ClipKind.COLOR) { onSelectedKind(if (selectedKind == ClipKind.COLOR) null else ClipKind.COLOR) } }
    }
}

@Composable
private fun FeedChip(label: String, selected: Boolean, onClick: () -> Unit) {
    val c = LocalAirclipColors.current
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.95f else 1f,
        animationSpec = spring(stiffness = 500f),
        label = "ChipScale",
    )
    val bg by animateColorAsState(
        if (selected) c.accent.copy(alpha = 0.08f) else Color.Transparent,
        tween(150),
        "ChipBg",
    )
    val stroke by animateColorAsState(if (selected) c.accent else c.borderDefault, tween(150), "ChipStroke")
    val tc by animateColorAsState(if (selected) c.accent else c.textSecondary, tween(150), "ChipTc")

    Box(
        modifier = Modifier
            .height(32.dp)
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
            .padding(horizontal = 13.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            label,
            fontSize = 14.sp,
            lineHeight = 20.sp,
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
    modifier: Modifier = Modifier,
) {
    val kind = recordKind(record)
    val timeStr = remember(record.timestampMs) { formatTime(record.timestampMs) }

    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    val alpha by animateFloatAsState(
        targetValue = if (isPressed) 0.6f else 1f,
        animationSpec = tween(100),
        label = "ItemAlpha",
    )

    Column(
        modifier = modifier
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
            ClipKind.TEXT  -> TextFeedItem(record, timeStr)
            ClipKind.URL   -> UrlFeedItem(record, timeStr)
            ClipKind.IMAGE -> ImageFeedItem(record, timeStr)
            ClipKind.FILE -> FileFeedItem(record, timeStr)
            ClipKind.COLOR -> ColorFeedItem(record, timeStr)
            ClipKind.EMAIL -> TextFeedItem(record, timeStr)
        }
    }
}

@Composable
private fun FileFeedItem(record: ClipItemRecord, timeStr: String) {
    val c = LocalAirclipColors.current
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 18.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        FileVisual(
            record,
            28.dp,
            showBorder = true,
            backgroundOpacity = 0.07f,
            iconSize = 20.dp,
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(record.file?.name ?: record.displayText, fontSize = 18.sp, color = c.textPrimary,
                maxLines = 1, overflow = TextOverflow.Ellipsis)
            Spacer(Modifier.height(6.dp))
            Text("${record.file?.size?.let(::formatFileSize) ?: "File"} · $timeStr",
                fontSize = 13.sp, color = c.textSecondary)
        }
    }
    HorizontalDivider(thickness = 1.dp, color = c.borderSubtle)
}

@Composable
private fun FileVisual(
    record: ClipItemRecord,
    size: Dp,
    showBorder: Boolean = true,
    backgroundOpacity: Float = 0.05f,
    iconSize: Dp = size * 0.86f,
) {
    val c = LocalAirclipColors.current
    val bytes = remember(record.file?.thumbnailBase64) {
        record.file?.thumbnailBase64?.let { runCatching { Base64.decode(it, Base64.NO_WRAP) }.getOrNull() }
    }
    val bitmap = remember(bytes) { bytes?.let { BitmapFactory.decodeByteArray(it, 0, it.size) } }
    if (bitmap != null && (size > 28.dp || record.file?.let { isImageFile(it.name, it.mimeType) } == true)) {
        Image(bitmap.asImageBitmap(), contentDescription = null,
            modifier = Modifier.size(size).clip(RoundedCornerShape(6.dp)), contentScale = ContentScale.Crop)
    } else {
        val name = record.file?.name.orEmpty()
        val mimeType = record.file?.mimeType.orEmpty()
        val shape = RoundedCornerShape(6.dp)
        Box(
            modifier = Modifier
                .size(size)
                .clip(shape)
                .background(fileIconAccentColor(name, mimeType).copy(alpha = backgroundOpacity))
                .then(if (showBorder) Modifier.border(0.5.dp, c.borderDefault, shape) else Modifier),
            contentAlignment = Alignment.Center,
        ) {
            if (record.file?.let { isImageFile(it.name, it.mimeType) } == true) {
                Icon(Icons.Outlined.Image, contentDescription = "Image file",
                    tint = fileIconAccentColor(name, mimeType), modifier = Modifier.size(iconSize))
            } else {
                Image(painterResource(fileIconResource(name, mimeType)),
                    contentDescription = null, modifier = Modifier.size(iconSize))
            }
        }
    }
}

private fun fileIconAccentColor(name: String, mimeType: String): Color = when (fileIconResource(name, mimeType)) {
    R.drawable.file_icon_pdf -> Color(0xFFDC0C11)
    R.drawable.file_icon_presentation -> Color(0xFFFC6F40)
    R.drawable.file_icon_windows_installer, R.drawable.file_icon_apple_installer -> Color(0xFF33A1FE)
    R.drawable.file_icon_android_installer -> Color(0xFF50DA8C)
    R.drawable.file_icon_zip -> Color(0xFFFFBA02)
    R.drawable.file_icon_rar -> Color(0xFFA79455)
    R.drawable.file_icon_audio, R.drawable.file_icon_video -> Color(0xFFED144E)
    R.drawable.file_icon_code -> Color(0xFFDF53E3)
    else -> Color(0xFF33A1FE)
}

@DrawableRes
private fun fileIconResource(name: String, mimeType: String): Int {
    val extension = name.substringAfterLast('.', "").lowercase(Locale.ROOT)
    return when (extension) {
        "pdf" -> R.drawable.file_icon_pdf
        "ppt", "pptx", "key" -> R.drawable.file_icon_presentation
        "exe", "msi", "msix" -> R.drawable.file_icon_windows_installer
        "dmg", "ipa", "pkg", "app" -> R.drawable.file_icon_apple_installer
        "apk", "aab" -> R.drawable.file_icon_android_installer
        "zip", "7z", "tar", "gz", "bz2" -> R.drawable.file_icon_zip
        "rar" -> R.drawable.file_icon_rar
        "mp3", "m4a", "aac", "wav", "flac", "ogg", "opus", "aiff" -> R.drawable.file_icon_audio
        "mp4", "m4v", "mov", "mkv", "avi", "webm", "wmv" -> R.drawable.file_icon_video
        "html", "htm", "css", "js", "ts", "jsx", "tsx", "json", "xml", "py", "swift", "kt", "java", "c", "cpp", "h", "rs", "go", "sh", "sql" -> R.drawable.file_icon_code
        else -> when {
            mimeType == "application/pdf" -> R.drawable.file_icon_pdf
            mimeType.startsWith("audio/") -> R.drawable.file_icon_audio
            mimeType.startsWith("video/") -> R.drawable.file_icon_video
            mimeType.startsWith("text/") && extension != "txt" -> R.drawable.file_icon_code
            else -> R.drawable.file_icon_document
        }
    }
}

private fun isImageFile(name: String, mimeType: String): Boolean =
    mimeType.startsWith("image/") || name.substringAfterLast('.', "").lowercase(Locale.ROOT) in setOf(
        "png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "bmp", "tif", "tiff",
    )

private fun isPlayableFile(name: String, mimeType: String): Boolean {
    val extension = name.substringAfterLast('.', "").lowercase(Locale.ROOT)
    return mimeType.startsWith("audio/") || mimeType.startsWith("video/") ||
        extension in setOf(
            "mp3", "m4a", "aac", "wav", "flac", "ogg", "opus", "aiff",
            "mp4", "m4v", "mov", "mkv", "avi", "webm", "wmv",
        )
}

private fun formatFileSize(bytes: Long): String = when {
    bytes >= 1_000_000_000 -> String.format(Locale.US, "%.1f GB", bytes / 1_000_000_000.0)
    bytes >= 1_000_000 -> String.format(Locale.US, "%.1f MB", bytes / 1_000_000.0)
    bytes >= 1_000 -> String.format(Locale.US, "%.1f KB", bytes / 1_000.0)
    else -> "$bytes B"
}

// ── Item type layouts ─────────────────────────────────────────────────────────

@Composable
private fun TextFeedItem(record: ClipItemRecord, timeStr: String) {
    val c = LocalAirclipColors.current
    Column {
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(vertical = 20.dp),
        ) {
            FeedTypeBadge(R.drawable.ic_clip_type_text, c.green)
            Column(modifier = Modifier.weight(1f)) {
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
                ItemMeta(timeStr)
            }
        }
        HorizontalDivider(thickness = 1.dp, color = c.borderSubtle)
    }
}

@Composable
private fun FeedTypeBadge(@DrawableRes iconRes: Int, tint: Color) {
    val c = LocalAirclipColors.current
    val shape = RoundedCornerShape(6.dp)
    Box(
        modifier = Modifier
            .size(28.dp)
            .clip(shape)
            .background(tint.copy(alpha = 0.12f))
            .border(0.5.dp, c.borderDefault, shape),
        contentAlignment = Alignment.Center,
    ) {
        Icon(painterResource(iconRes), contentDescription = null, tint = tint, modifier = Modifier.size(18.dp))
    }
}

private data class LinkPreviewData(val url: String, val title: String, val site: String, val imageUrl: String?)

@Composable
private fun rememberLinkPreview(record: ClipItemRecord): LinkPreviewData {
    val lines = remember(record.displayText) { record.displayText.lines().map(String::trim).filter(String::isNotBlank) }
    val url = remember(lines, record.displayText) {
        UrlMetadataLoader.urlsIn(record.displayText).firstOrNull() ?: record.displayText
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
private fun rememberEmbeddedLinkPreview(text: String): LinkPreviewData? {
    return produceState<LinkPreviewData?>(initialValue = null, key1 = text) {
        val (url, metadata) = UrlMetadataLoader.firstPreviewWithImage(text) ?: return@produceState
        value = LinkPreviewData(url, metadata.title, metadata.site, metadata.imageUrl)
    }.value
}

@Composable
private fun LinkPreviewImage(preview: LinkPreviewData, modifier: Modifier = Modifier) {
    val c = LocalAirclipColors.current
    val shape = RoundedCornerShape(12.dp)
    val painter = rememberAsyncImagePainter(
        model = ImageRequest.Builder(LocalContext.current)
            .data(preview.imageUrl).size(1200).build(),
    )
    val drawable = (painter.state as? AsyncImagePainter.State.Success)?.result?.drawable
    val ready = drawable != null && drawable.intrinsicWidth > 0 && drawable.intrinsicHeight > 0
    AnimatedVisibility(
        visible = ready,
        enter = expandVertically(animationSpec = tween(240, easing = CubicBezierEasing(0.23f, 1f, 0.32f, 1f))) + fadeIn(tween(180)),
        exit = shrinkVertically(tween(160)) + fadeOut(tween(120)),
        modifier = modifier,
    ) {
        if (drawable != null) {
            Image(
                painter = painter,
                contentDescription = "Preview image from ${preview.site}",
                contentScale = ContentScale.FillWidth,
                modifier = Modifier.fillMaxWidth()
                    .padding(bottom = 16.dp)
                    .aspectRatio(drawable.intrinsicWidth.toFloat() / drawable.intrinsicHeight.coerceAtLeast(1))
                    .clip(shape)
                    .background(if (c.isDark) c.bgElevated else Color(0xFFF5F5F5)),
            )
        }
    }
}

@Composable
private fun LinkPreview(preview: LinkPreviewData, modifier: Modifier = Modifier) {
    val c = LocalAirclipColors.current

    Column(modifier = modifier) {
        if (preview.imageUrl != null) {
            LinkPreviewImage(preview)
        }
        Column(
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(
                preview.title,
                fontSize = 20.sp,
                lineHeight = 28.sp,
                fontWeight = FontWeight.Medium,
                color = c.textPrimary,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(preview.site, fontSize = 14.sp, lineHeight = 20.sp, color = c.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(preview.url, fontSize = 13.sp, lineHeight = 18.sp, color = c.textSecondary, maxLines = 2, overflow = TextOverflow.Ellipsis)
        }
    }
}

@Composable
private fun LinkFeedVisual(preview: LinkPreviewData) {
    val imageUrl = preview.imageUrl
    if (imageUrl == null) {
        FeedTypeBadge(R.drawable.ic_clip_type_link, LocalAirclipColors.current.accent)
        return
    }

    val c = LocalAirclipColors.current
    val shape = RoundedCornerShape(10.dp)
    val painter = rememberAsyncImagePainter(
        model = ImageRequest.Builder(LocalContext.current)
            .data(imageUrl)
            .size(384)
            .build(),
    )
    val drawable = (painter.state as? AsyncImagePainter.State.Success)?.result?.drawable
    val ready = drawable != null && drawable.intrinsicWidth > 0 && drawable.intrinsicHeight > 0

    if (ready) {
        Image(
            painter = painter,
            contentDescription = "Preview image from ${preview.site}",
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .size(96.dp)
                .clip(shape)
                .background(c.bgElevated)
                .border(0.5.dp, c.borderSubtle, shape),
        )
    } else {
        FeedTypeBadge(R.drawable.ic_clip_type_link, c.accent)
    }
}

@Composable
private fun UrlFeedItem(record: ClipItemRecord, timeStr: String) {
    val preview = rememberLinkPreview(record)
    val c = LocalAirclipColors.current
    Column {
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(vertical = 20.dp),
        ) {
            LinkFeedVisual(preview)
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    preview.title,
                    fontSize = 18.sp,
                    lineHeight = 27.sp,
                    letterSpacing = 0.15.sp,
                    color = c.textPrimary,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    preview.url,
                    fontSize = 13.sp,
                    lineHeight = 18.sp,
                    color = c.textSecondary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(Modifier.height(6.dp))
                ItemMeta(timeStr)
            }
        }
        HorizontalDivider(thickness = 1.dp, color = c.borderSubtle)
    }
}

@Composable
private fun ImageFeedItem(record: ClipItemRecord, timeStr: String) {
    val c = LocalAirclipColors.current
    val bitmap = rememberPreviewBitmap(record)
    val name = record.imageFileName ?: record.displayText.takeIf { !it.startsWith("Image ") } ?: "Image"
    Column {
        Column(Modifier.padding(vertical = 20.dp)) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth(),
            ) {
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
                    ItemMeta(timeStr)
                }
            }
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
    val c = LocalAirclipColors.current
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
private fun ColorFeedItem(record: ClipItemRecord, timeStr: String) {
    val c = LocalAirclipColors.current
    val parsedColor = parseClipboardColor(record.displayText)?.let(::Color) ?: Color(0xFF808080)

    Column {
        Row(
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalAlignment = Alignment.CenterVertically,
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
                ItemMeta(timeStr)
            }
        }
        HorizontalDivider(thickness = 1.dp, color = c.borderSubtle)
    }
}

// ── Meta row ──────────────────────────────────────────────────────────────────

@Composable
private fun ItemMeta(timeStr: String) {
    val c = LocalAirclipColors.current
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
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
    onFileAction: () -> Unit,
    onOpenLink: () -> Unit,
    onSave: () -> Unit,
    onDelete: () -> Unit,
) {
    val c = LocalAirclipColors.current
    val kind = recordKind(record)
    val fileTransfers by SyncEngine.fileTransfers.collectAsState()
    val fileTransfer = record.file?.id?.let(fileTransfers::get)
    val fileAvailable = remember(record, fileTransfer) { SyncEngine.availableFile(record) != null }
    val playableFile = record.file?.let { isPlayableFile(it.name, it.mimeType) } == true
    val temporaryPreviewFile = remember(record, fileTransfer) { SyncEngine.availablePreviewFile(record) }
    val bitmap = if (kind == ClipKind.IMAGE) rememberPreviewBitmap(record) else null
    val linkPreview = if (kind == ClipKind.URL) rememberLinkPreview(record) else null
    val embeddedLinkPreview = if (kind == ClipKind.TEXT) rememberEmbeddedLinkPreview(record.displayText) else null
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var copied by remember(record.messageId) { mutableStateOf(false) }
    var copyFeedbackVersion by remember(record.messageId) { mutableIntStateOf(0) }
    val copyButtonColor by animateColorAsState(
        targetValue = if (copied) Color(0xFF246144) else c.textPrimary,
        animationSpec = tween(150),
        label = "copy button feedback",
    )
    val copyButtonContentColor by animateColorAsState(
        targetValue = if (copied) Color.White else c.bgBase,
        animationSpec = tween(150),
        label = "copy button content feedback",
    )
    val copyMorphProgress by animateFloatAsState(
        targetValue = if (copied) 1f else 0f,
        animationSpec = tween(180),
        label = "copy icon confirmation",
    )

    LaunchedEffect(copyFeedbackVersion) {
        if (copyFeedbackVersion == 0) return@LaunchedEffect
        delay(1_400)
        copied = false
    }

    DisposableEffect(record.messageId) {
        onDispose { SyncEngine.clearPreviewFile(record) }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = if (c.isDark) c.bgFloating else Color.White,
        tonalElevation = 0.dp,
        contentColor = c.textPrimary,
        dragHandle = { AirclipSheetHandle() },
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 20.dp),
        ) {
            if (kind != ClipKind.FILE) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(sourceNameFor(record.fromDeviceId), fontSize = 14.sp, lineHeight = 20.sp, color = c.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                    Spacer(Modifier.width(16.dp))
                    Text(formatTime(record.timestampMs), fontSize = 14.sp, lineHeight = 20.sp, color = c.textSecondary)
                }
            }

            Spacer(Modifier.height(20.dp))

            Box(modifier = Modifier.fillMaxWidth().weight(1f, fill = false)
                .verticalScroll(rememberScrollState())) {
                when (kind) {
                    ClipKind.FILE -> {
                        val file = record.file
                        Column(
                            modifier = Modifier.fillMaxWidth(),
                            verticalArrangement = Arrangement.spacedBy(20.dp),
                        ) {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(14.dp))
                                    .border(1.dp, c.borderDefault, RoundedCornerShape(14.dp))
                                    .padding(20.dp),
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(12.dp),
                            ) {
                                if (temporaryPreviewFile != null) {
                                    FileInlinePreview(record, temporaryPreviewFile)
                                } else {
                                    FileVisual(record, 104.dp)
                                }
                                Text(
                                    file?.name ?: record.displayText,
                                    fontSize = 18.sp,
                                    lineHeight = 24.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = c.textPrimary,
                                    textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                                    maxLines = 2,
                                    overflow = TextOverflow.Ellipsis,
                                )
                                file?.let {
                                    Text(
                                        buildList {
                                            add(formatFileSize(it.size))
                                            if (it.mimeType.isNotBlank() && it.mimeType != "application/octet-stream") add(it.mimeType)
                                            if (it.width != null && it.height != null) add("${it.width} × ${it.height}")
                                            it.durationMs?.let { duration -> add("${duration / 1000}s") }
                                        }.joinToString(" · "),
                                        fontSize = 14.sp,
                                        lineHeight = 20.sp,
                                        color = c.textSecondary,
                                        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                                    )
                                }
                                if (fileTransfer?.phase == "downloading") {
                                    LinearProgressIndicator(
                                        progress = { fileTransfer.received.toFloat() / maxOf(fileTransfer.total, 1).toFloat() },
                                        modifier = Modifier.fillMaxWidth(),
                                    )
                                    Text(
                                        "${if (fileTransfer.temporaryPreview) "Preparing preview" else "Downloading"} ${fileTransfer.received * 100 / maxOf(fileTransfer.total, 1)}%",
                                        color = c.textSecondary,
                                    )
                                }
                                fileTransfer?.error?.let { Text(it, color = c.destructive) }
                            }

                            if (file != null) {
                                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                    Text("Information", fontSize = 14.sp, fontWeight = FontWeight.Medium,
                                        color = c.textSecondary, modifier = Modifier.padding(start = 4.dp, bottom = 4.dp))
                                    val rows = buildList {
                                        add("Source" to sourceNameFor(record.fromDeviceId))
                                        add("Type" to "File")
                                        add("Size" to formatFileSize(file.size))
                                        file.mimeType.takeIf { it.isNotBlank() }?.let { add("Format" to it) }
                                        file.width?.let { width -> file.height?.let { height -> add("Dimensions" to "${width} × ${height}") } }
                                        file.durationMs?.let { add("Duration" to "${it / 1000}s") }
                                        file.artist?.let { add("Artist" to it) }
                                        file.album?.let { add("Album" to it) }
                                        add("Copied" to formatTime(record.timestampMs))
                                    }
                                    rows.forEachIndexed { index, (label, value) ->
                                        Row(
                                            modifier = Modifier
                                                .fillMaxWidth()
                                                .clip(RoundedCornerShape(10.dp))
                                                .background(if (index % 2 == 0) c.bgElevated else Color.Transparent)
                                                .padding(horizontal = 14.dp, vertical = 11.dp),
                                            verticalAlignment = Alignment.CenterVertically,
                                            horizontalArrangement = Arrangement.SpaceBetween,
                                        ) {
                                            Text(label, fontSize = 14.sp, color = c.textSecondary)
                                            Spacer(Modifier.width(16.dp))
                                            Text(value, fontSize = 14.sp, color = c.textPrimary,
                                                textAlign = androidx.compose.ui.text.style.TextAlign.End,
                                                maxLines = 2, overflow = TextOverflow.Ellipsis,
                                                modifier = Modifier.weight(1f, fill = false))
                                        }
                                    }
                                }
                            }
                        }
                    }
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
                        Column {
                            embeddedLinkPreview?.let {
                                LinkPreviewImage(it)
                            }
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .heightIn(max = 440.dp)
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(if (c.isDark) c.bgElevated else Color(0xFFF5F5F5))
                                    .verticalScroll(rememberScrollState())
                                    .padding(16.dp),
                            ) {
                                Text(record.displayText, fontSize = 18.sp, lineHeight = 28.sp, color = c.textPrimary)
                            }
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
                    onClick = {
                        if (kind == ClipKind.FILE) onFileAction() else {
                            onCopy()
                            copied = true
                            copyFeedbackVersion++
                        }
                    },
                    enabled = kind != ClipKind.FILE || fileTransfer?.phase != "downloading",
                    modifier = Modifier
                        .weight(1f)
                        .height(52.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = copyButtonColor,
                        contentColor = copyButtonContentColor,
                    ),
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        if (kind == ClipKind.FILE) {
                            if (fileTransfer?.phase != "downloading") {
                                Icon(
                                    painter = painterResource(
                                        when {
                                            !fileAvailable -> R.drawable.ic_file_download
                                            playableFile -> R.drawable.ic_file_play
                                            else -> R.drawable.ic_file_open
                                        },
                                    ),
                                    contentDescription = null,
                                    modifier = Modifier.size(16.dp),
                                )
                                Spacer(Modifier.width(8.dp))
                            }
                            Text(
                                when {
                                    fileTransfer?.phase == "downloading" -> "Downloading…"
                                    fileAvailable && playableFile -> "Play"
                                    fileAvailable -> "Open"
                                    else -> "Download"
                                },
                            )
                        } else {
                        CopyConfirmationIcon(
                            progress = copyMorphProgress,
                            tint = copyButtonContentColor,
                            modifier = Modifier.size(22.dp),
                        )
                        Spacer(Modifier.width(8.dp))
                        Crossfade(targetState = copied, animationSpec = tween(150), label = "copy confirmation") { isCopied ->
                            Text(if (isCopied) "Copied" else "Copy")
                        }
                        }
                    }
                }
                if (kind == ClipKind.URL) {
                    PreviewResourceIconButton(
                        R.drawable.ic_clip_open_external,
                        "Visit link",
                        onOpenLink,
                        c.textSecondary,
                        iconSize = 22.dp,
                    )
                }
                if (kind != ClipKind.FILE) {
                    Crossfade(targetState = record.isSaved, animationSpec = tween(120), label = "preview save") { saved ->
                        PreviewResourceIconButton(
                            iconRes = if (saved) R.drawable.ic_clip_unsave else R.drawable.ic_clip_save,
                            description = if (saved) "Remove from saved" else "Save",
                            onClick = onSave,
                            tint = if (saved) c.accent else c.textSecondary,
                        )
                    }
                }
                PreviewResourceIconButton(R.drawable.ic_clip_delete, "Delete", onDelete, c.destructive)
            }
        }
    }
}

@Composable
private fun CopyConfirmationIcon(
    progress: Float,
    tint: Color,
    modifier: Modifier = Modifier,
) {
    Box(modifier = modifier, contentAlignment = Alignment.Center) {
        Icon(
            painter = painterResource(R.drawable.ic_clip_copy),
            contentDescription = null,
            tint = tint,
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer {
                    alpha = 1f - progress
                    scaleX = 1f - (0.04f * progress)
                    scaleY = 1f - (0.04f * progress)
                },
        )
        Canvas(Modifier.fillMaxSize()) {
            val start = Offset(size.width * 0.22f, size.height * 0.53f)
            val corner = Offset(size.width * 0.43f, size.height * 0.74f)
            val end = Offset(size.width * 0.80f, size.height * 0.30f)
            val stroke = Stroke(width = 1.9.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round)
            fun between(from: Offset, to: Offset, fraction: Float) = Offset(
                from.x + ((to.x - from.x) * fraction),
                from.y + ((to.y - from.y) * fraction),
            )

            if (progress > 0f && progress <= 0.38f) {
                drawLine(tint, start, between(start, corner, progress / 0.38f), stroke.width, StrokeCap.Round)
            } else if (progress > 0f) {
                drawLine(tint, start, corner, stroke.width, StrokeCap.Round)
                drawLine(tint, corner, between(corner, end, (progress - 0.38f) / 0.62f), stroke.width, StrokeCap.Round)
            }
        }
    }
}

@Composable
private fun FileInlinePreview(record: ClipItemRecord, file: File) {
    val metadata = record.file ?: return
    val name = metadata.name.lowercase(Locale.ROOT)
    when {
        metadata.mimeType == "application/pdf" || name.endsWith(".pdf") -> PdfPagesPreview(file)
        metadata.mimeType.startsWith("video/") -> {
            AndroidView(
                factory = { viewContext ->
                    VideoView(viewContext).apply {
                        val controls = MediaController(viewContext)
                        controls.setAnchorView(this)
                        setMediaController(controls)
                        setVideoURI(Uri.fromFile(file))
                    }
                },
                modifier = Modifier.fillMaxWidth().heightIn(min = 180.dp, max = 320.dp)
                    .clip(RoundedCornerShape(10.dp)),
            )
        }
        metadata.mimeType.startsWith("audio/") -> AudioFilePreview(file, metadata.name)
        metadata.mimeType.startsWith("image/") || listOf(".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".heic")
            .any(name::endsWith) -> AsyncImage(
                model = file,
                contentDescription = metadata.name,
                modifier = Modifier.fillMaxWidth().heightIn(min = 200.dp, max = 360.dp)
                    .clip(RoundedCornerShape(10.dp)),
                contentScale = ContentScale.Fit,
            )
        metadata.mimeType.startsWith("text/") || listOf(".txt", ".md", ".csv", ".json", ".xml", ".log")
            .any(name::endsWith) -> PlainTextFilePreview(file)
        else -> FileVisual(record, 96.dp)
    }
}

@Composable
private fun PlainTextFilePreview(file: File) {
    val c = LocalAirclipColors.current
    val content by produceState(initialValue = "Loading preview…", file.absolutePath) {
        value = withContext(Dispatchers.IO) {
            runCatching { file.readText(Charsets.UTF_8).take(30_000) }
                .getOrElse { "Text preview unavailable" }
        }
    }
    SelectionContainer {
        Text(
            content,
            color = c.textPrimary,
            fontSize = 14.sp,
            lineHeight = 20.sp,
            modifier = Modifier.fillMaxWidth().heightIn(max = 360.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(c.bgElevated).verticalScroll(rememberScrollState()).padding(16.dp),
        )
    }
}

@Composable
private fun PdfPagesPreview(file: File) {
    val pageCount by produceState(initialValue = 0, file.absolutePath) {
        value = withContext(Dispatchers.IO) {
            runCatching {
                ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
                    PdfRenderer(descriptor).use { renderer -> renderer.pageCount }
                }
            }.getOrDefault(0)
        }
    }
    if (pageCount == 0) {
        Text("PDF preview unavailable", color = LocalAirclipColors.current.textSecondary)
        return
    }
    LazyColumn(
        modifier = Modifier.fillMaxWidth().heightIn(max = 440.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        items(pageCount) { pageIndex ->
            val bitmap by produceState<Bitmap?>(initialValue = null, file.absolutePath, pageIndex) {
                value = withContext(Dispatchers.IO) {
                    runCatching {
                        ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
                            PdfRenderer(descriptor).use { renderer ->
                                renderer.openPage(pageIndex).use { page ->
                                    val scale = minOf(900f / page.width.coerceAtLeast(1), 1200f / page.height.coerceAtLeast(1))
                                    val width = (page.width * scale).toInt().coerceIn(1, 900)
                                    val height = (page.height * scale).toInt().coerceIn(1, 1200)
                                    Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also { page.render(it, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY) }
                                }
                            }
                        }
                    }.getOrNull()
                }
            }
            bitmap?.let {
                Image(
                    bitmap = it.asImageBitmap(),
                    contentDescription = "PDF page ${pageIndex + 1} of $pageCount",
                    modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(6.dp))
                        .border(0.5.dp, LocalAirclipColors.current.borderSubtle, RoundedCornerShape(6.dp)),
                    contentScale = ContentScale.FillWidth,
                )
            } ?: Box(Modifier.fillMaxWidth().height(240.dp), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(modifier = Modifier.size(24.dp), strokeWidth = 2.dp)
            }
        }
    }
}

@Composable
private fun AudioFilePreview(file: File, name: String) {
    val c = LocalAirclipColors.current
    val context = LocalContext.current
    var player by remember(file.absolutePath) { mutableStateOf<MediaPlayer?>(null) }
    var prepared by remember(file.absolutePath) { mutableStateOf(false) }
    var playing by remember(file.absolutePath) { mutableStateOf(false) }
    DisposableEffect(file.absolutePath) {
        val created = MediaPlayer()
        player = created
        runCatching {
            created.setDataSource(context, Uri.fromFile(file))
            created.setOnPreparedListener { prepared = true }
            created.setOnCompletionListener { playing = false }
            created.prepareAsync()
        }.onFailure { prepared = false }
        onDispose {
            player = null
            runCatching { created.stop() }
            created.release()
        }
    }
    Row(
        modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp))
            .background(c.bgElevated).padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(Icons.Outlined.AudioFile, contentDescription = null, tint = c.accent, modifier = Modifier.size(32.dp))
        Text(name, color = c.textPrimary, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
        IconButton(onClick = {
            player?.let { active ->
                if (active.isPlaying) { active.pause(); playing = false }
                else if (prepared) { active.start(); playing = true }
            }
        }, enabled = prepared) {
            Icon(if (playing) Icons.Outlined.Pause else Icons.Outlined.PlayArrow, contentDescription = if (playing) "Pause audio preview" else "Play audio preview", tint = c.textPrimary)
        }
    }
}

@Composable
private fun PreviewResourceIconButton(
    @DrawableRes iconRes: Int,
    description: String,
    onClick: () -> Unit,
    tint: Color = Color.Unspecified,
    iconSize: Dp = 24.dp,
) {
    val c = LocalAirclipColors.current
    IconButton(
        onClick = onClick,
        modifier = Modifier
            .size(52.dp)
            .border(1.dp, c.borderDefault, RoundedCornerShape(12.dp)),
    ) {
        Icon(
            painter = painterResource(iconRes),
            contentDescription = description,
            tint = if (tint == Color.Unspecified) c.textSecondary else tint,
            modifier = Modifier.size(iconSize),
        )
    }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

private fun copyRecordToClipboard(context: Context, record: ClipItemRecord) {
    if (runCatching { ImageClipboard.copy(context, record) }.getOrDefault(false)) return
    val mgr = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    mgr.setPrimaryClip(ClipData.newPlainText("Airclip", record.displayText))
}

private fun openRecordFile(context: Context, record: ClipItemRecord) {
    val file = SyncEngine.availableFile(record) ?: return
    val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
    val intent = Intent(Intent.ACTION_VIEW).apply {
        setDataAndType(uri, record.file?.mimeType ?: "application/octet-stream")
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    runCatching { context.startActivity(intent) }
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
    if (deviceId == AirclipIdentity.deviceId) {
        "This device"
    } else {
        AirclipIdentity.deviceNameFor(deviceId) ?: "Remote"
    }

private fun recordKind(record: ClipItemRecord): ClipKind =
    runCatching { ClipKind.valueOf(record.kind) }.getOrDefault(ClipKind.TEXT)
        .let {
            when {
                it == ClipKind.TEXT && parseClipboardColor(record.displayText) != null -> ClipKind.COLOR
                else -> it
            }
        }
