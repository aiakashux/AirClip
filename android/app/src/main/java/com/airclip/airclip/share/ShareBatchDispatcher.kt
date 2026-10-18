package com.airclip.airclip.share

internal suspend fun <T> dispatchShareBatch(
    items: List<T>,
    dispatch: suspend (T) -> Boolean,
): Int {
    var successCount = 0
    for (item in items) {
        if (dispatch(item)) successCount += 1
    }
    return successCount
}
