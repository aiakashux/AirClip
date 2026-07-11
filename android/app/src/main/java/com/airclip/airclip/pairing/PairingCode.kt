package com.airclip.airclip.pairing

object PairingCode {
    const val LENGTH = 6

    fun normalize(value: String): String = value.filter(Char::isDigit)

    fun isValid(value: String): Boolean = normalize(value).length == LENGTH
}
