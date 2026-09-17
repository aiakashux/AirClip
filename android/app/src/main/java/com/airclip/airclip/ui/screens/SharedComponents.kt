package com.airclip.airclip.ui.screens

import androidx.annotation.DrawableRes
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.EnterExitState
import androidx.compose.animation.ExperimentalAnimationApi
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.MutableTransitionState
import androidx.compose.animation.core.animateDp
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.hoverable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsHoveredAsState
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupProperties
import com.airclip.airclip.ui.theme.*
import com.airclip.airclip.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.UUID

@Composable
fun AirclipSheetHandle() {
    Box(Modifier.fillMaxWidth().padding(top = 12.dp, bottom = 16.dp), contentAlignment = Alignment.Center) {
        Box(Modifier.size(32.dp, 4.dp).clip(RoundedCornerShape(2.dp))
            .background(LocalAirclipColors.current.textTertiary.copy(alpha = 0.4f)))
    }
}

@Composable
fun AirclipEmptyState(
    @DrawableRes iconRes: Int,
    text: String,
    modifier: Modifier = Modifier,
    textColor: Color? = null,
) {
    val c = LocalAirclipColors.current
    Column(
        modifier = modifier
            .fillMaxSize()
            .offset(y = 40.dp)
            .padding(horizontal = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            painter = painterResource(iconRes),
            contentDescription = null,
            tint = Color.Unspecified,
            modifier = Modifier.size(68.dp),
        )
        Spacer(Modifier.height(20.dp))
        Text(
            text,
            fontSize = 16.sp,
            lineHeight = 24.sp,
            fontWeight = FontWeight.Normal,
            color = textColor ?: c.textSecondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.width(283.dp),
        )
    }
}

@Composable
fun AirclipTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    label: String,
    modifier: Modifier = Modifier,
    visualTransformation: VisualTransformation = VisualTransformation.None,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
    trailingIcon: (@Composable () -> Unit)? = null,
) {
    val c = LocalAirclipColors.current
    Column(modifier = modifier) {
        Text(
            label,
            style = MaterialTheme.typography.labelMedium,
            color = c.textSecondary,
        )
        Spacer(Modifier.height(6.dp))
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier.fillMaxWidth().height(52.dp),
            placeholder = { Text(placeholder, color = c.textTertiary, style = MaterialTheme.typography.bodyMedium) },
            visualTransformation = visualTransformation,
            keyboardOptions = keyboardOptions,
            keyboardActions = keyboardActions,
            trailingIcon = trailingIcon,
            singleLine = true,
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor        = c.textPrimary,
                unfocusedTextColor      = c.textPrimary,
                focusedBorderColor      = c.accent,
                unfocusedBorderColor    = c.borderDefault,
                focusedContainerColor   = c.bgBase,
                unfocusedContainerColor = c.bgBase,
                cursorColor             = c.accent,
            ),
            shape = RoundedCornerShape(12.dp),
            textStyle = MaterialTheme.typography.bodyMedium.copy(color = c.textPrimary),
        )
    }
}

@Composable
fun AirclipPrimaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    loading: Boolean = false,
) {
    val c = LocalAirclipColors.current
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.97f else 1f,
        animationSpec = spring(stiffness = 500f),
        label = "PrimaryBtnScale",
    )

    Button(
        onClick = onClick,
        enabled = enabled && !loading,
        interactionSource = interactionSource,
        modifier = modifier
            .fillMaxWidth()
            .height(52.dp)
            .graphicsLayer { scaleX = scale; scaleY = scale },
        shape = RoundedCornerShape(26.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor         = c.textPrimary,
            contentColor           = c.bgBase,
            disabledContainerColor = c.borderDefault,
            disabledContentColor   = c.textTertiary,
        ),
    ) {
        if (loading) {
            CircularProgressIndicator(
                modifier = Modifier.size(18.dp),
                color = c.bgBase,
                strokeWidth = 2.dp,
            )
        } else {
            Text(text, fontWeight = FontWeight.SemiBold, fontSize = 15.sp, letterSpacing = (-0.1).sp)
        }
    }
}

data class AirclipDropdownItem(
    val label: String,
    val onClick: () -> Unit,
    val color: Color? = null,
)

@Composable
@OptIn(ExperimentalComposeUiApi::class)
fun AirclipDropdownMenu(
    expanded: Boolean,
    onDismissRequest: () -> Unit,
    items: List<AirclipDropdownItem>,
    modifier: Modifier = Modifier,
    selectedLabel: String? = null,
) {
    val visibility = remember { MutableTransitionState(false) }
    LaunchedEffect(expanded) { visibility.targetState = expanded }
    if (!expanded && !visibility.currentState && !visibility.targetState) return

    val c = LocalAirclipColors.current
    val menuShape = RoundedCornerShape(14.dp)
    val yOffset = with(LocalDensity.current) { 4.dp.roundToPx() }
    val shadowGutter = 18.dp
    val showSelectionIndicator = selectedLabel != null
    val easeOut = CubicBezierEasing(0.23f, 1f, 0.32f, 1f)

    Popup(
        onDismissRequest = onDismissRequest,
        alignment = Alignment.TopEnd,
        offset = IntOffset(x = 0, y = yOffset),
        properties = PopupProperties(focusable = true),
    ) {
        AnimatedVisibility(
            visibleState = visibility,
            enter = fadeIn(tween(160, easing = easeOut)) + scaleIn(
                animationSpec = tween(160, easing = easeOut),
                initialScale = 0.98f,
                transformOrigin = TransformOrigin(1f, 0f),
            ),
            exit = fadeOut(tween(100, easing = easeOut)),
        ) {
            Box(
                modifier = modifier
                    .width(196.dp)
                    .padding(end = 8.dp, bottom = shadowGutter),
                contentAlignment = Alignment.TopEnd,
            ) {
                Box(
                    modifier = Modifier
                        .width(180.dp)
                        .shadow(
                            elevation = 14.dp,
                            shape = menuShape,
                            clip = false,
                        )
                        .clip(menuShape)
                        .background(if (c.isDark) c.bgFloating else Color(0xFFFAFAFA)),
                ) {
                    Column(
                        modifier = Modifier.padding(8.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        items.forEach { item ->
                            val selected = item.label == selectedLabel
                            AirclipDropdownRow(
                                item = item,
                                selected = selected,
                                showSelectionIndicator = showSelectionIndicator,
                                onDismissRequest = onDismissRequest,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AirclipDropdownRow(
    item: AirclipDropdownItem,
    selected: Boolean,
    showSelectionIndicator: Boolean,
    onDismissRequest: () -> Unit,
) {
    val c = LocalAirclipColors.current
    val textColor = item.color ?: c.textPrimary
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    val isHovered by interactionSource.collectIsHoveredAsState()
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(40.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(
                if (isPressed || isHovered) {
                    if (c.isDark) Color.White.copy(alpha = 0.08f)
                    else Color.Black.copy(alpha = 0.04f)
                } else {
                    Color.Transparent
                },
            )
            .hoverable(interactionSource)
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                role = Role.Button,
            ) {
                item.onClick()
                onDismissRequest()
            }
            .padding(horizontal = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            item.label,
            modifier = Modifier.weight(1f),
            fontSize = 16.sp,
            lineHeight = 16.sp,
            fontWeight = FontWeight.Normal,
            color = textColor,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        if (showSelectionIndicator) {
            if (selected) {
                Icon(
                    Icons.Outlined.Check,
                    contentDescription = null,
                    tint = c.textPrimary,
                    modifier = Modifier.size(20.dp),
                )
            } else {
                Spacer(Modifier.size(20.dp))
            }
        }
    }
}

enum class AirclipAlertKind { REGULAR, SUCCESS, DANGER }

data class AirclipAlertItem(
    val id: String = UUID.randomUUID().toString(),
    val message: String,
    val kind: AirclipAlertKind,
    val actionLabel: String? = null,
    val action: (() -> Unit)? = null,
)

@Stable
class AirclipAlertHostState internal constructor(private val scope: CoroutineScope) {
    var current by mutableStateOf<AirclipAlertItem?>(null)
        private set
    private var dismissJob: Job? = null

    fun show(
        message: String,
        kind: AirclipAlertKind = AirclipAlertKind.REGULAR,
        actionLabel: String? = null,
        action: (() -> Unit)? = null,
    ) {
        dismissJob?.cancel()
        val item = AirclipAlertItem(message = message, kind = kind, actionLabel = actionLabel, action = action)
        current = item
        val duration = if (actionLabel != null) 5_000L else if (kind == AirclipAlertKind.DANGER) 4_500L else 2_800L
        dismissJob = scope.launch {
            delay(duration)
            if (current?.id == item.id) dismiss()
        }
    }

    fun dismiss() {
        dismissJob?.cancel()
        dismissJob = null
        current = null
    }

    fun performAction() {
        val action = current?.action
        dismiss()
        action?.invoke()
    }
}

@Composable
fun rememberAirclipAlertHostState(): AirclipAlertHostState {
    val scope = rememberCoroutineScope()
    return remember(scope) { AirclipAlertHostState(scope) }
}

val LocalAirclipAlertHostState = staticCompositionLocalOf<AirclipAlertHostState> {
    error("AirclipAlertHostState is not provided")
}

@OptIn(ExperimentalAnimationApi::class)
@Composable
fun AirclipAlertHost(
    state: AirclipAlertHostState,
    modifier: Modifier = Modifier,
) {
    val current = state.current
    var displayed by remember { mutableStateOf<AirclipAlertItem?>(null) }
    LaunchedEffect(current?.id) {
        if (current != null) {
            displayed = current
        } else {
            delay(180)
            displayed = null
        }
    }
    AnimatedVisibility(
        visible = current != null,
        modifier = modifier,
        enter = fadeIn(tween(220)) + slideInVertically(tween(220)) { it / 2 },
        exit = fadeOut(tween(180)) + slideOutVertically(tween(180)) { it / 2 },
    ) {
        val blurRadius by transition.animateDp(label = "alert-blur") { visible ->
            if (visible == EnterExitState.Visible) 0.dp else 4.dp
        }
        (current ?: displayed)?.let { item ->
            AirclipBottomAlert(
                item = item,
                onDismiss = state::dismiss,
                onAction = state::performAction,
                modifier = Modifier.blur(blurRadius),
            )
        }
    }
}

@Composable
private fun AirclipBottomAlert(
    item: AirclipAlertItem,
    onDismiss: () -> Unit,
    onAction: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val c = LocalAirclipColors.current
    val foreground = if (item.kind == AirclipAlertKind.DANGER) c.yellow else c.textPrimary
    Row(
        modifier = modifier
            .widthIn(max = 520.dp)
            .shadow(
                elevation = 8.dp,
                shape = RoundedCornerShape(24.dp),
                ambientColor = Color(0x1F18274B),
                spotColor = Color(0x1418274B),
            )
            .clip(RoundedCornerShape(24.dp))
            .background(c.bgElevated)
            .border(1.dp, c.borderSubtle, RoundedCornerShape(24.dp))
            .padding(horizontal = 20.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Row(
            modifier = Modifier.weight(1f, fill = false),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            val icon = when (item.kind) {
                AirclipAlertKind.SUCCESS -> R.drawable.ic_alert_check
                AirclipAlertKind.DANGER -> R.drawable.ic_alert_warning
                AirclipAlertKind.REGULAR -> null
            }
            icon?.let {
                Icon(
                    painter = painterResource(it),
                    contentDescription = null,
                    tint = foreground,
                    modifier = Modifier.size(24.dp),
                )
            }
            Text(
                item.message,
                color = foreground,
                fontSize = 16.sp,
                lineHeight = 21.sp,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }

        if (item.actionLabel != null) {
            TextButton(onClick = onAction, contentPadding = PaddingValues(0.dp)) {
                Text(
                    item.actionLabel,
                    color = c.accent,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        } else {
            IconButton(onClick = onDismiss, modifier = Modifier.size(24.dp)) {
                Icon(
                    painter = painterResource(R.drawable.ic_alert_close),
                    contentDescription = "Dismiss",
                    tint = c.textSecondary,
                    modifier = Modifier.size(20.dp),
                )
            }
        }
    }
}
