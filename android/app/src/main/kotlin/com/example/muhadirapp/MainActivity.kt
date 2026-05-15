package com.example.muhadirapp

import android.content.ComponentName
import android.content.Intent
import android.nfc.cardemulation.CardEmulation
import android.provider.Settings
import com.novice.flutter_nfc_hce.KHostApduService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val gateHceChannel = "com.example.muhadirapp/gate_hce"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, gateHceChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setPreferredGateHce" -> {
                        result.success(setPreferredGateHce())
                    }
                    "unsetPreferredGateHce" -> {
                        result.success(unsetPreferredGateHce())
                    }
                    "openNfcPaymentSettings" -> {
                        result.success(openNfcPaymentSettings())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun gateHceComponent(): ComponentName =
        ComponentName(this, KHostApduService::class.java)

    private fun setPreferredGateHce(): Boolean {
        val adapter = android.nfc.NfcAdapter.getDefaultAdapter(this) ?: return false
        if (!packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_NFC_HOST_CARD_EMULATION)) {
            return false
        }
        return try {
            CardEmulation.getInstance(adapter).setPreferredService(this, gateHceComponent())
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun unsetPreferredGateHce(): Boolean {
        val adapter = android.nfc.NfcAdapter.getDefaultAdapter(this) ?: return false
        return try {
            CardEmulation.getInstance(adapter).unsetPreferredService(this)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun openNfcPaymentSettings(): Boolean {
        val intents = listOf(
            Intent(Settings.ACTION_NFC_PAYMENT_SETTINGS),
            Intent(Settings.ACTION_NFC_SETTINGS),
            Intent(Settings.ACTION_WIRELESS_SETTINGS),
        )
        for (intent in intents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return true
            } catch (_: Exception) {
                // try next
            }
        }
        return false
    }
}
