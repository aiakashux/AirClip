package com.airclip.airclip.ui.screens

import androidx.annotation.DrawableRes
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
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

@Composable
fun AirClipEmptyState(
    @DrawableRes iconRes: Int,
    text: String,
    modifier: Modifier = Modifier,
    textColor: Color = Color(0xFFA0A5B1),
) {
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
            color = textColor,
            textAlign = TextAlign.Center,
            modifier = Modifier.width(283.dp),
        )
    }
}

@Composable
fun AirClipTextField(
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
    val c = LocalAirClipColors.current
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
fun AirClipPrimaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    loading: Boolean = false,
) {
    val c = LocalAirClipColors.current
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

data class AirClipDropdownItem(
    val label: String,
    val onClick: () -> Unit,
    val color: Color? = null,
)

@Composable
@OptIn(ExperimentalComposeUiApi::class)
fun AirClipDropdownMenu(
    expanded: Boolean,
    onDismissRequest: () -> Unit,
    items: List<AirClipDropdownItem>,
    modifier: Modifier = Modifier,
    selectedLabel: String? = null,
) {
    if (!expanded) return

    val menuShape = RoundedCornerShape(16.dp)
    val yOffset = with(LocalDensity.current) { 8.dp.roundToPx() }
    val shadowGutter = 18.dp

    Popup(
        onDismissRequest = onDismissRequest,
        alignment = Alignment.TopEnd,
        offset = IntOffset(x = 0, y = yOffset),
        properties = PopupProperties(focusable = true),
    ) {
        Box(
            modifier = modifier
                .width(276.dp)
                .padding(end = 20.dp, bottom = shadowGutter),
            contentAlignment = Alignment.TopEnd,
        ) {
            Box(
                modifier = Modifier
                    .width(236.dp)
                    .shadow(
                        elevation = 14.dp,
                        shape = menuShape,
                        clip = false,
                    )
                    .clip(menuShape)
                    .background(Color.White),
            ) {
                Column(
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items.forEach { item ->
                        val selected = item.label == selectedLabel
                        AirClipDropdownRow(
                            item = item,
                            selected = selected,
                            onDismissRequest = onDismissRequest,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun AirClipDropdownRow(
    item: AirClipDropdownItem,
    selected: Boolean,
    onDismissRequest: () -> Unit,
) {
    val textColor = item.color ?: Color.Black
    Row(
        modifier = Modifier
            .width(204.dp)
            .height(40.dp)
            .clip(RoundedCornerShape(10.dp))
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
            ) {
                item.onClick()
                onDismissRequest()
            }
            .padding(start = 4.dp),
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
        if (selected) {
            Icon(
                Icons.Outlined.Check,
                contentDescription = null,
                tint = Color.Black,
                modifier = Modifier.size(24.dp),
            )
        } else {
            Spacer(Modifier.size(24.dp))
        }
    }
}
