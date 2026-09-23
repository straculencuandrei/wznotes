package dev.opennotes.app

import android.app.DownloadManager
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import android.util.Log

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "dev.opennotes.app/file_manager"
    private val TAG = "MainActivity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openFolder") {
                val folderPath = call.argument<String>("folderPath")
                if (folderPath != null) {
                    val success = openFolderInFileManager(folderPath)
                    result.success(success)
                } else {
                    result.error("INVALID_PATH", "Folder path cannot be null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun openFolderInFileManager(folderPath: String): Boolean {
        val folder = File(folderPath)
        if (!folder.exists()) {
            folder.mkdirs()
        }

        val relativePath = folder.absolutePath
            .replace(Regex("^/storage/emulated/0/"), "")
            .replace(Regex("^/sdcard/"), "")

        // Strategy 1: Samsung My Files (Direct specific folder view)
        try {
            val samsungIntent = Intent("com.sec.android.app.myfiles.VIEW_FOLDER").apply {
                putExtra("folder_path", folder.absolutePath)
                putExtra("current_path", folder.absolutePath)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(samsungIntent)
            Log.d(TAG, "Launched Samsung My Files")
            return true
        } catch (_: Exception) {}

        // Strategy 2: Android DocumentsUI with specific document ID
        try {
            val docUri = DocumentsContract.buildDocumentUri(
                "com.android.externalstorage.documents",
                "primary:$relativePath"
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(docUri, DocumentsContract.Document.MIME_TYPE_DIR)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
            }
            startActivity(intent)
            Log.d(TAG, "Launched DocumentsUI specific directory")
            return true
        } catch (_: Exception) {}

        // Strategy 3: Android DocumentsUI Root
        try {
            val rootUri = DocumentsContract.buildRootUri("com.android.externalstorage.documents", "primary")
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(rootUri, DocumentsContract.Document.MIME_TYPE_DIR)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
            }
            startActivity(intent)
            Log.d(TAG, "Launched DocumentsUI root")
            return true
        } catch (_: Exception) {}

        // Strategy 4: DownloadManager ACTION_VIEW_DOWNLOADS (if inside Download)
        try {
            if (folder.absolutePath.contains("Download", ignoreCase = true)) {
                val dlIntent = Intent(DownloadManager.ACTION_VIEW_DOWNLOADS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(dlIntent)
                Log.d(TAG, "Launched Downloads")
                return true
            }
        } catch (_: Exception) {}

        // Strategy 5: FileProvider folder intent
        try {
            val contentUri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                folder
            )
            val folderIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(contentUri, "resource/folder")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
            }
            startActivity(folderIntent)
            Log.d(TAG, "Launched FileProvider resource/folder")
            return true
        } catch (_: Exception) {}

        // Strategy 6: Launch installed File Manager directly (Google Files, Samsung My Files, DocumentsUI, Mi File Explorer)
        val fileManagerPackages = listOf(
            "com.google.android.apps.nbu.files",
            "com.sec.android.app.myfiles",
            "com.google.android.documentsui",
            "com.android.documentsui",
            "com.mi.android.globalFileexplorer"
        )
        for (pkg in fileManagerPackages) {
            try {
                val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
                if (launchIntent != null) {
                    launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(launchIntent)
                    Log.d(TAG, "Launched $pkg")
                    return true
                }
            } catch (_: Exception) {}
        }

        // Strategy 7: Fallback chooser with ACTION_OPEN_DOCUMENT initialized to folder
        try {
            val treeUri = Uri.parse("content://com.android.externalstorage.documents/document/primary:$relativePath")
            val openDocIntent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                putExtra(DocumentsContract.EXTRA_INITIAL_URI, treeUri)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(openDocIntent)
            Log.d(TAG, "Launched ACTION_OPEN_DOCUMENT")
            return true
        } catch (_: Exception) {}

        return false
    }
}
