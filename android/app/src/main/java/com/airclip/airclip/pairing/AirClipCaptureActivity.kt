package com.airclip.airclip.pairing

import android.content.pm.ActivityInfo
import android.os.Bundle
import android.widget.ImageButton
import com.airclip.airclip.R
import com.journeyapps.barcodescanner.CaptureActivity
import com.journeyapps.barcodescanner.DecoratedBarcodeView

class AirClipCaptureActivity : CaptureActivity() {
    override fun initializeContent(): DecoratedBarcodeView {
        setContentView(R.layout.zxing_capture)
        return findViewById(R.id.zxing_barcode_scanner)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        super.onCreate(savedInstanceState)

        findViewById<ImageButton>(R.id.airclip_scanner_back_button)?.setOnClickListener {
            finish()
        }
    }
}
