package com.example.cth_mobile

import android.content.Intent
import android.nfc.NdefMessage
import android.os.Bundle
import android.os.Parcelable
import android.util.Log
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
	private val TAG = "CTH_MainActivity"

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		try {
			intent?.let {
				dumpNfcIntent("onCreate", it)
			}
		} catch (e: Exception) {
			Log.e(TAG, "Error dumping intent onCreate", e)
		}
	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		try {
			// make sure FlutterActivity sees the new intent
			setIntent(intent)
			dumpNfcIntent("onNewIntent", intent)
		} catch (e: Exception) {
			Log.e(TAG, "Error dumping intent onNewIntent", e)
		}
	}

	private fun dumpNfcIntent(source: String, intent: Intent) {
		Log.d(TAG, "--- NFC Intent dump ($source) ---")
		Log.d(TAG, "Action: ${intent.action}")
		Log.d(TAG, "Type: ${intent.type}")

		val extras = intent.extras
		if (extras == null) {
			Log.d(TAG, "No extras on intent")
			return
		}

		for (key in extras.keySet()) {
			try {
				val value = extras.get(key)
				when (value) {
					is Parcelable[] -> {
						Log.d(TAG, "Extra[$key] is Parcelable[] length=${value.size}")
						for (i in value.indices) {
							val p = value[i]
							if (p is NdefMessage) {
								Log.d(TAG, "NdefMessage[$i]: records=${p.records.size}")
								for (r in p.records.indices) {
									val record = p.records[r]
									val payload = try {
										String(record.payload, Charsets.UTF_8)
									} catch (ex: Exception) {
										"<binary>"
									}
									Log.d(TAG, "  record[$r] t=${record.tnf} type=${String(record.type)} payload=$payload")
								}
							} else {
								Log.d(TAG, "  Parcelable[$i]: ${p?.javaClass?.name} -> $p")
							}
						}
					}
					is NdefMessage -> {
						Log.d(TAG, "Extra[$key] is NdefMessage records=${value.records.size}")
					}
					else -> {
						Log.d(TAG, "Extra[$key] (${value?.javaClass?.name}) -> $value")
					}
				}
			} catch (e: Exception) {
				Log.w(TAG, "Failed to read extra '$key'", e)
			}
		}

		Log.d(TAG, "--- end NFC Intent dump ($source) ---")
	}
}
