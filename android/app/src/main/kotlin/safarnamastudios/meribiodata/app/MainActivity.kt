package safarnamastudios.meribiodata.app

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hosts the one platform feature this app needs directly.
 *
 * **WhatsApp share (9.1).** share_plus cannot target a specific app, and a
 * biodata in Pakistan circulates on WhatsApp far more than by any other route,
 * so burying it in a generic chooser is the wrong default.
 *
 * A Storage Access Framework document picker used to live here too, for
 * choosing a `.mbd` backup file to restore. Google Drive sync replaced that
 * flow, so it was removed rather than left as unreachable code.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "safarnamastudios.meribiodata.app/platform"

    /** Both the consumer app and the business app can receive a share. */
    private val whatsAppPackages = listOf("com.whatsapp", "com.whatsapp.w4b")

    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).also { messages ->
            messages.setMethodCallHandler { call, result ->
                when (call.method) {
                    "isWhatsAppAvailable" -> result.success(installedWhatsApp() != null)
                    "shareToWhatsApp" -> {
                        val paths = call.argument<List<String>>("paths").orEmpty()
                        val mimeType = call.argument<String>("mimeType") ?: "*/*"
                        val text = call.argument<String>("text")
                        result.success(share(paths, mimeType, text))
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun installedWhatsApp(): String? = whatsAppPackages.firstOrNull {
        try {
            packageManager.getPackageInfo(it, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    /**
     * Returns false rather than throwing when WhatsApp is missing or refuses
     * the intent, so the Dart side can fall back to the ordinary share sheet.
     */
    private fun share(paths: List<String>, mimeType: String, text: String?): Boolean {
        val target = installedWhatsApp() ?: return false
        if (paths.isEmpty()) return false

        val uris = ArrayList(
            paths.map { path ->
                FileProvider.getUriForFile(
                    this,
                    "$packageName.fileprovider",
                    File(path),
                )
            }
        )

        val intent = if (uris.size == 1) {
            Intent(Intent.ACTION_SEND).apply { putExtra(Intent.EXTRA_STREAM, uris[0]) }
        } else {
            // Multi-page biodatas share as a set so the page order survives.
            Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
            }
        }

        intent.type = mimeType
        intent.setPackage(target)
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        if (text != null) intent.putExtra(Intent.EXTRA_TEXT, text)

        return try {
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

}
