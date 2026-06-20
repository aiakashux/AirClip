package com.airclip.airclip.pairing

object PairingCode {
    fun normalize(value: String): String = value.filter(Char::isDigit)

    fun isValid(value: String): Boolean = normalize(value).length == 8
}
