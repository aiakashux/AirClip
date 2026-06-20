package com.airclip.airclip.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.airclip.airclip.ui.theme.*

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
    Column(modifier = modifier) {
        Text(
            label,
            style = MaterialTheme.typography.labelMedium,
            color = AirClipTextSecondary,
        )
        Spacer(Modifier.height(6.dp))
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier.fillMaxWidth().height(48.dp),
            placeholder = { Text(placeholder, color = AirClipTextTertiary, style = MaterialTheme.typography.bodySmall) },
            visualTransformation = visualTransformation,
            keyboardOptions = keyboardOptions,
            keyboardActions = keyboardActions,
            trailingIcon = trailingIcon,
            singleLine = true,
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor      = AirClipTextPrimary,
                unfocusedTextColor    = AirClipTextPrimary,
                focusedBorderColor    = Color.White.copy(alpha = 0.22f),
                unfocusedBorderColor  = AirClipBorderDefault,
                focusedContainerColor = Color.White.copy(alpha = 0.08f),
                unfocusedContainerColor = Color.White.copy(alpha = 0.06f),
                cursorColor           = AirClipAccent,
            ),
            shape = RoundedCornerShape(8.dp),
            textStyle = MaterialTheme.typography.bodySmall.copy(color = AirClipTextPrimary),
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
    Button(
        onClick = onClick,
        enabled = enabled && !loading,
        modifier = modifier.fillMaxWidth().height(44.dp),
        shape = RoundedCornerShape(10.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor         = Color.White,
            contentColor           = Color(0xFF0E0E12),
            disabledContainerColor = Color.White.copy(alpha = 0.30f),
            disabledContentColor   = Color(0xFF0E0E12).copy(alpha = 0.50f),
        ),
    ) {
        if (loading) {
            CircularProgressIndicator(
                modifier = Modifier.size(18.dp),
                color = Color(0xFF0E0E12),
                strokeWidth = 2.dp,
            )
        } else {
            Text(text, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, letterSpacing = (-0.1).sp)
        }
    }
}
