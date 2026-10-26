package com.example.pmanager

import android.app.Activity
import android.content.ClipData
import java.io.InputStream
import java.io.ByteArrayOutputStream
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PersistableBundle
import android.util.AtomicFile
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private val handler = Handler(Looper.getMainLooper())
    private val limit = 8 * 1024 * 1024
    private var pending: MethodChannel.Result? = null
    private var exportData: ByteArray? = null
    private var clipboardLabel: String? = null
    private val vaultFile: AtomicFile get() = AtomicFile(File(noBackupFilesDir, "vault.sesame"))

    override fun onCreate(savedInstanceState: Bundle?) {
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }

    private fun io(result: MethodChannel.Result, work: () -> Any?) {
        executor.execute {
            try {
                val value = work()
                handler.post { result.success(value) }
            } catch (_: Exception) {
                handler.post { result.error("STORAGE_ERROR", "Opération de stockage impossible", null) }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sesame/vault")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "read" -> io(result) {
                        val file = vaultFile
                        // AtomicFile.openRead recovers the backup after an interrupted write.
                        if (!file.baseFile.exists() && !File(file.baseFile.path + ".bak").exists()) null
                        else file.openRead().use { stream ->
                            val bytes = readBounded(stream)
                            require(bytes.size <= limit)
                            String(bytes, Charsets.UTF_8)
                        }
                    }
                    "write" -> {
                        val value = call.arguments as? String
                        if (value == null || value.toByteArray(Charsets.UTF_8).size > limit) {
                            result.error("INVALID_DATA", "Taille invalide", null)
                        } else io(result) {
                            val file = vaultFile
                            val stream = file.startWrite()
                            try {
                                stream.write(value.toByteArray(Charsets.UTF_8))
                                file.finishWrite(stream)
                            } catch (error: Exception) {
                                file.failWrite(stream)
                                throw error
                            }
                            null
                        }
                    }
                    "export", "import" -> {
                        if (pending != null) result.error("BUSY", "Sélecteur déjà ouvert", null)
                        else {
                            val exporting = call.method == "export"
                            val value = call.arguments as? String
                            if (exporting && (value == null || value.toByteArray(Charsets.UTF_8).size > limit)) {
                                result.error("INVALID_DATA", "Sauvegarde invalide", null)
                            } else {
                                pending = result
                                exportData = if (exporting) value!!.toByteArray(Charsets.UTF_8) else null
                                val intent = Intent(if (exporting) Intent.ACTION_CREATE_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT)
                                    .addCategory(Intent.CATEGORY_OPENABLE)
                                    .setType(if (exporting) "application/octet-stream" else "*/*")
                                if (exporting) intent.putExtra(Intent.EXTRA_TITLE, "sesame-${System.currentTimeMillis()}.sesame")
                                try { startActivityForResult(intent, if (exporting) 701 else 702) }
                                catch (_: Exception) {
                                    pending = null; exportData = null
                                    result.error("PICKER_ERROR", "Sélecteur indisponible", null)
                                }
                            }
                        }
                    }
                    "copy" -> {
                        val text = call.arguments as? String
                        if (text == null) result.error("INVALID_DATA", "Texte manquant", null)
                        else {
                            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                            val label = "sesame-${UUID.randomUUID()}"
                            val clip = ClipData.newPlainText(label, text)
                            if (Build.VERSION.SDK_INT >= 24) {
                                clip.description.extras = PersistableBundle().apply {
                                    putBoolean("android.content.extra.IS_SENSITIVE", true)
                                }
                            }
                            clipboard.setPrimaryClip(clip)
                            clipboardLabel = label
                            handler.postDelayed({ if (clipboardLabel == label) clearClipboard() }, 30000)
                            result.success(null)
                        }
                    }
                    "clearClipboard" -> { clearClipboard(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
    }

    private fun readBounded(input: InputStream): ByteArray {
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        while (true) {
            val count = input.read(buffer)
            if (count < 0) break
            require(output.size() + count <= limit)
            output.write(buffer, 0, count)
        }
        return output.toByteArray()
    }

    override fun onPause() {
        clearClipboard()
        super.onPause()
    }

    private fun clearClipboard() {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val label = clipboardLabel ?: return
        if (clipboard.primaryClipDescription?.label?.toString() == label) {
            if (Build.VERSION.SDK_INT >= 28) clipboard.clearPrimaryClip()
            else clipboard.setPrimaryClip(ClipData.newPlainText("", ""))
        }
        clipboardLabel = null
    }

    @Deprecated("Android document picker compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 701 && requestCode != 702) return
        val result = pending ?: return
        val bytes = exportData
        pending = null; exportData = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(if (requestCode == 701) false else null)
            return
        }
        io(result) {
            if (requestCode == 701) {
                require(bytes != null)
                val output = contentResolver.openOutputStream(uri, "wt") ?: error("Output unavailable")
                output.use { it.write(bytes); it.flush() }
                true
            } else {
                val input = contentResolver.openInputStream(uri) ?: error("Input unavailable")
                input.use {
                    val imported = readBounded(it)
                    require(imported.size <= limit)
                    String(imported, Charsets.UTF_8)
                }
            }
        }
    }
}
