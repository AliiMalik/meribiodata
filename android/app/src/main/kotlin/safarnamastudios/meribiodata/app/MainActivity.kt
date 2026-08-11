package safarnamastudios.meribiodata.app

import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
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
 * **Saving an export where the user can find it.** Exports are rendered into
 * app-private storage, which the share sheet can hand out through a
 * FileProvider grant but which the user can never browse to — and which is
 * erased on uninstall. "Save" therefore publishes a copy through MediaStore,
 * so a PDF lands in Downloads and an image in Pictures, visible in Files and
 * the gallery like anything else they downloaded.
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
                    "saveToGallery" -> {
                        val path = call.argument<String>("path")
                        val mimeType = call.argument<String>("mimeType") ?: "*/*"
                        result.success(publish(path, mimeType))
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    /**
     * Copies [path] into the user's own Downloads or Pictures collection.
     *
     * Returns the public display name on success and null on any failure, so
     * the Dart side can tell the user plainly rather than claiming a save that
     * did not happen.
     *
     * Only on API 29+. Below that, publishing to a public collection needs
     * WRITE_EXTERNAL_STORAGE — a runtime permission prompt asking for access to
     * *all* the user's files, in an app whose entire pitch is that it touches
     * nothing. That is a bad trade for a shrinking slice of devices, so older
     * versions fall back to the share sheet, which reaches the same Files app
     * without any permission at all.
     */
    private fun publish(path: String?, mimeType: String): String? {
        if (path == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null

        val source = File(path)
        if (!source.exists()) return null

        val images = mimeType.startsWith("image/")
        val collection = if (images) {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        }
        val folder = if (images) Environment.DIRECTORY_PICTURES else Environment.DIRECTORY_DOWNLOADS

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, source.name)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(MediaStore.MediaColumns.RELATIVE_PATH, folder)
            // Hides the row until the bytes are written. Without it a gallery
            // can index a half-copied file and show a broken thumbnail.
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val resolver = contentResolver
        val uri = resolver.insert(collection, values) ?: return null

        return try {
            resolver.openOutputStream(uri).use { out ->
                if (out == null) throw java.io.IOException("no output stream")
                source.inputStream().use { it.copyTo(out) }
            }
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            source.name
        } catch (e: Exception) {
            // Leave nothing half-written behind for the gallery to trip over.
            resolver.delete(uri, null, null)
            null
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
