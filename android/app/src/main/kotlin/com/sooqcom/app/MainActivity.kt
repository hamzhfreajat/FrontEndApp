package com.sooqcom.app

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.sooqcom.app/share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "shareImageToApp") {
                try {
                    val text = call.argument<String>("text")
                    val imagePath = call.argument<String>("imagePath")
                    val packageId = call.argument<String>("packageId")
                    
                    val intent = Intent(Intent.ACTION_SEND)
                    intent.type = "image/jpeg"
                    
                    if (packageId != null && packageId.isNotEmpty()) {
                        intent.setPackage(packageId)
                    }
                    
                    if (text != null) {
                        intent.putExtra(Intent.EXTRA_TEXT, text)
                    }
                    
                    if (imagePath != null) {
                        val file = File(imagePath)
                        val uri = FileProvider.getUriForFile(
                            context,
                            context.packageName + ".custom_share_provider",
                            file
                        )
                        intent.putExtra(Intent.EXTRA_STREAM, uri)
                        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("APP_NOT_INSTALLED", "App not installed or failed to launch", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
