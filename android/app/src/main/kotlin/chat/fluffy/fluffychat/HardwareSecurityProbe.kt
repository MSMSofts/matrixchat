// SPDX-FileCopyrightText: 2026 MatrixChat contributors
// SPDX-License-Identifier: AGPL-3.0-or-later
package chat.fluffy.fluffychat

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.util.UUID
import javax.crypto.KeyGenerator
import javax.crypto.SecretKeyFactory

/**
 * A capability probe, not attestation of the existing database key.
 * Creates a unique ephemeral alias, never reads or changes application keys.
 */
internal object HardwareSecurityProbe {
    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, "matrixchat/security").setMethodCallHandler { call, result ->
            if (call.method != "probeKeystore") {
                result.notImplemented()
            } else {
                Thread {
                    val status = try {
                        probe(app)
                    } catch (_: Exception) {
                        "unavailable"
                    }
                    Handler(Looper.getMainLooper()).post { result.success(status) }
                }.start()
            }
        }
    }

    private fun probe(context: Context): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return "unsupported"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
            context.packageManager.hasSystemFeature(PackageManager.FEATURE_STRONGBOX_KEYSTORE)
        ) {
            try {
                val status = probeKey(true)
                if (status == "strongbox" || status == "hardware") return status
            } catch (_: Exception) {
                // A device can advertise StrongBox while a key operation fails.
            }
        }
        return probeKey(false)
    }

    @Suppress("DEPRECATION")
    private fun probeKey(strongbox: Boolean): String {
        val alias = "matrixchat.probe." + UUID.randomUUID().toString()
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        try {
            val builder = KeyGenParameterSpec.Builder(
                alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setKeySize(256)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && strongbox) {
                builder.setIsStrongBoxBacked(true)
            }
            val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
            generator.init(builder.build())
            val key = generator.generateKey()
            val factory = SecretKeyFactory.getInstance(key.algorithm, "AndroidKeyStore")
            val info = factory.getKeySpec(key, KeyInfo::class.java) as KeyInfo
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                return when (info.securityLevel) {
                    KeyProperties.SECURITY_LEVEL_STRONGBOX -> "strongbox"
                    KeyProperties.SECURITY_LEVEL_TRUSTED_ENVIRONMENT -> "tee"
                    KeyProperties.SECURITY_LEVEL_SOFTWARE -> "software"
                    else -> if (info.isInsideSecureHardware) "hardware" else "unknown"
                }
            }
            return if (info.isInsideSecureHardware) "hardware" else "software"
        } finally {
            if (store.containsAlias(alias)) store.deleteEntry(alias)
        }
    }
}
