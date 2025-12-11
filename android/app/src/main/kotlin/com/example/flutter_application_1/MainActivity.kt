package com.example.flutter_application_1

import android.content.Intent
import android.nfc.NfcAdapter
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Handle NFC intents when app is already running
        if (NfcAdapter.ACTION_TAG_DISCOVERED == intent.action ||
            NfcAdapter.ACTION_NDEF_DISCOVERED == intent.action ||
            NfcAdapter.ACTION_TECH_DISCOVERED == intent.action) {
            // Forward NFC intent to Flutter
            setIntent(intent)
        }
    }
}
