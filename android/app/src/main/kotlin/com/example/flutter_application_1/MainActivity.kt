package com.example.flutter_application_1

import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.Tag
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.flutter_application_1/nfc"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Handle NFC intent if app was launched by NFC tag
        handleNfcIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Handle NFC intents when app is already running
        handleNfcIntent(intent)
    }

    private fun handleNfcIntent(intent: Intent) {
        val action = intent.action
        if (action == NfcAdapter.ACTION_TAG_DISCOVERED ||
            action == NfcAdapter.ACTION_NDEF_DISCOVERED ||
            action == NfcAdapter.ACTION_TECH_DISCOVERED) {
            
            val tag: Tag? = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(NfcAdapter.EXTRA_TAG, Tag::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
            }
            if (tag != null) {
                // Try to read NDEF data from the tag
                var cardId: String? = null
                
                try {
                    // First, try to get NDEF message from intent (for NDEF_DISCOVERED)
                    var ndefMessage: NdefMessage? = null
                    if (action == NfcAdapter.ACTION_NDEF_DISCOVERED) {
                        val ndefMessages = intent.getParcelableArrayExtra(NfcAdapter.EXTRA_NDEF_MESSAGES)
                        if (ndefMessages != null && ndefMessages.isNotEmpty()) {
                            ndefMessage = ndefMessages[0] as? NdefMessage
                        }
                    }
                    
                    // If not in intent, try to read from tag
                    if (ndefMessage == null) {
                        val ndef = android.nfc.tech.Ndef.get(tag)
                        if (ndef != null) {
                            ndef.connect()
                            try {
                                ndefMessage = ndef.ndefMessage
                            } finally {
                                ndef.close()
                            }
                        }
                    }
                    
                    // Process NDEF message
                    if (ndefMessage != null) {
                        val records = ndefMessage.records
                        for (record in records) {
                            // Check if it's a text record (TNF_WELL_KNOWN with type "T")
                            if (record.tnf == NdefRecord.TNF_WELL_KNOWN) {
                                val typeBytes = record.type
                                if (typeBytes.isNotEmpty() && typeBytes[0] == 0x54.toByte()) { // 'T' = 0x54
                                    val payload = record.payload
                                    if (payload.isNotEmpty()) {
                                        // First byte is status byte
                                        val statusByte = payload[0].toInt() and 0xFF
                                        val langCodeLength = statusByte and 0x3F
                                        
                                        // Skip status byte and language code
                                        val textStartIndex = 1 + langCodeLength
                                        if (textStartIndex < payload.size) {
                                            val textBytes = payload.sliceArray(textStartIndex until payload.size)
                                            val text = String(textBytes, Charsets.UTF_8).trim()
                                            
                                            // Check if it matches RC-XXXXXXXX pattern
                                            if (text.matches(Regex("^[Rr][Cc]-[A-Fa-f0-9]{8}$", RegexOption.IGNORE_CASE))) {
                                                cardId = text
                                                break
                                            } else if (text.matches(Regex("^[Rr][Cc]-[A-Fa-f0-9]+$", RegexOption.IGNORE_CASE))) {
                                                cardId = text
                                                break
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Error reading NDEF: ${e.message}", e)
                }
                
                // Extract tag ID as fallback
                val tagId = tag.id
                val tagIdHex = tagId.joinToString(":") { "%02X".format(it) }
                
                // Notify Flutter that an NFC tag was received via intent
                methodChannel?.invokeMethod("onNfcIntent", mapOf(
                    "tagId" to tagIdHex,
                    "cardId" to (cardId ?: ""),
                    "action" to (action ?: ""),
                    "hasNdef" to (cardId != null)
                ))
            }
        }
    }
}
