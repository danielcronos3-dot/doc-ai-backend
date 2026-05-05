package com.cronos.dashboardapp

import android.content.ClipData
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channel = "nexadash/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "shareFile" -> {
                    try {
                        val path = call.argument<String>("path") ?: ""
                        val title = call.argument<String>("title") ?: "Compartir reporte"
                        val text = call.argument<String>("text") ?: ""
                        shareFile(path, title, text)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SHARE_ERROR", e.message, e.stackTraceToString())
                    }
                }
                "sendFeedback" -> {
                    try {
                        val email = call.argument<String>("email") ?: ""
                        val subject = call.argument<String>("subject") ?: "Sugerencia NexaDash AI"
                        val body = call.argument<String>("body") ?: ""
                        sendFeedback(email, subject, body)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("FEEDBACK_ERROR", e.message, e.stackTraceToString())
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun shareFile(path: String, title: String, text: String) {
        val source = File(path)
        if (!source.exists()) {
            throw IllegalArgumentException("El archivo no existe: $path")
        }

        val cacheFile = File(cacheDir, source.name.ifBlank { "reporte_nexadash_ai.pdf" })
        source.inputStream().use { input ->
            cacheFile.outputStream().use { output ->
                input.copyTo(output)
            }
        }

        val uri: Uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            cacheFile
        )

        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "application/pdf"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TEXT, text)
            clipData = ClipData.newUri(contentResolver, title, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        startActivity(Intent.createChooser(intent, title))
    }

    private fun sendFeedback(email: String, subject: String, body: String) {
        val intent = Intent(Intent.ACTION_SENDTO).apply {
            data = Uri.parse("mailto:")
            putExtra(Intent.EXTRA_EMAIL, arrayOf(email))
            putExtra(Intent.EXTRA_SUBJECT, subject)
            putExtra(Intent.EXTRA_TEXT, body)
        }

        startActivity(Intent.createChooser(intent, "Enviar sugerencia"))
    }
}
