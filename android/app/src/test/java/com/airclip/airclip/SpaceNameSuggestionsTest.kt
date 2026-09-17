package com.airclip.airclip

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SpaceNameSuggestionsTest {
    @Test fun suggestions_doNotRepeatWithinOneSession() {
        val seen = mutableSetOf<String>()
        repeat(100) { seen += requireNotNull(SpaceNameSuggestions.next(seen)) }
        assertEquals(100, seen.size)
        assertNull(SpaceNameSuggestions.next(seen))
    }
}
