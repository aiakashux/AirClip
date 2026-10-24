package com.airclip.airclip.pairing

import android.app.Activity
import android.content.Intent
import android.content.pm.ActivityInfo
import android.os.Bundle
import android.view.View
import androidx.core.view.WindowCompat
import android.widget.ImageButton
import com.airclip.airclip.R
import com.journeyapps.barcodescanner.CaptureActivity
import com.journeyapps.barcodescanner.DecoratedBarcodeView

class AirclipCaptureActivity : CaptureActivity() {
    companion object {
        const val EXTRA_SHOW_CODE_CONNECT = "com.airclip.airclip.SHOW_CODE_CONNECT"
        const val EXTRA_CODE_CONNECT_REQUESTED = "com.airclip.airclip.CODE_CONNECT_REQUESTED"
    }

    override fun initializeContent(): DecoratedBarcodeView {
        setContentView(R.layout.zxing_capture)
        return findViewById(R.id.zxing_barcode_scanner)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        super.onCreate(savedInstanceState)
        // Camera chrome is dark regardless of the app appearance.
        WindowCompat.getInsetsController(window, window.decorView).apply {
            isAppearanceLightStatusBars = false
            isAppearanceLightNavigationBars = false
        }

        findViewById<ImageButton>(R.id.airclip_scanner_back_button)?.setOnClickListener {
            finish()
        }

        findViewById<View>(R.id.airclip_scanner_code_connect)?.apply {
            visibility = if (intent.getBooleanExtra(EXTRA_SHOW_CODE_CONNECT, false)) {
                View.VISIBLE
            } else {
                View.GONE
            }
            setOnClickListener {
                setResult(
                    Activity.RESULT_CANCELED,
                    Intent().putExtra(EXTRA_CODE_CONNECT_REQUESTED, true),
                )
                finish()
            }
        }
    }
}
