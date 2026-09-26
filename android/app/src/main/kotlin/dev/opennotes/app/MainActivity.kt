package dev.opennotes.app

import android.app.DownloadManager
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.DocumentsContract
import androidx.core.content.FileProvider
import androidx.core.graphics.Insets
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsAnimationCompat
import androidx.core.view.WindowInsetsCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import android.util.Log

class MainActivity: FlutterFragmentActivity() {
    private val FILE_CHANNEL = "dev.opennotes.app/file_manager"
    private val DEEP_LINK_CHANNEL = "dev.opennotes.app/deep_link"
    private val KEYBOARD_CHANNEL = "dev.opennotes.app/keyboard"
    private val TAG = "MainActivity"

    private var initialDeepLink: String? = null
    private var deepLinkChannel: MethodChannel? = null
    private var keyboardChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
        setupKeyboardInsetInterception()
    }

    /// Intercepts IME (keyboard) window insets at the content view level,
    /// BEFORE they reach Flutter's FlutterView engine. This prevents:
    /// 1. WidgetsBinding.handleMetricsChanged() from firing (20+ times per keyboard animation)
    /// 2. EditableTextState.didChangeMetrics() from doing expensive IME reconnections (134ms/frame)
    /// 3. Full render tree re-layout on every animation frame
    ///
    /// The keyboard height is sent to Dart via MethodChannel instead,
    /// where the dock island uses it for zero-overhead GPU Transform positioning.
    private fun setupKeyboardInsetInterception() {
        val contentView = window.decorView.findViewById<android.view.View>(android.R.id.content) ?: return
        val density = resources.displayMetrics.density

        // 1. Stop keyboard animation progress from reaching FlutterView
        //    DISPATCH_MODE_STOP prevents onProgress from being dispatched to child views
        ViewCompat.setWindowInsetsAnimationCallback(contentView,
            object : WindowInsetsAnimationCompat.Callback(DISPATCH_MODE_STOP) {
                override fun onProgress(
                    insets: WindowInsetsCompat,
                    runningAnimations: List<WindowInsetsAnimationCompat>
                ): WindowInsetsCompat {
                    val imeBottom = insets.getInsets(WindowInsetsCompat.Type.ime()).bottom
                    val dpHeight = imeBottom / density
                    keyboardChannel?.invokeMethod("keyboardHeight", dpHeight.toDouble())

                    // Return insets with IME zeroed so FlutterView doesn't see keyboard changes
                    return WindowInsetsCompat.Builder(insets)
                        .setInsets(WindowInsetsCompat.Type.ime(), Insets.NONE)
                        .build()
                }
            }
        )

        // 2. Also intercept final onApplyWindowInsets to zero out IME for the settled state
        ViewCompat.setOnApplyWindowInsetsListener(contentView) { _, insets ->
            val imeBottom = insets.getInsets(WindowInsetsCompat.Type.ime()).bottom
            val dpHeight = imeBottom / density
            keyboardChannel?.invokeMethod("keyboardHeight", dpHeight.toDouble())

            // Strip IME insets, pass everything else (system bars, cutouts) through
            WindowInsetsCompat.Builder(insets)
                .setInsets(WindowInsetsCompat.Type.ime(), Insets.NONE)
                .build()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val uri: Uri? = intent?.data
        if (uri != null) {
            val urlString = uri.toString()
            Log.d(TAG, "Received deep link: $urlString")
            initialDeepLink = urlString
            deepLinkChannel?.invokeMethod("onDeepLink", urlString)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openFolder") {
                val folderPath = call.argument<String>("folderPath")
                val filePath = call.argument<String>("filePath")
                if (folderPath != null) {
                    val success = openFolderInFileManager(folderPath, filePath)
                    result.success(success)
                } else {
                    result.error("INVALID_PATH", "Folder path cannot be null", null)
                }
            } else {
                result.notImplemented()
            }
        }

        deepLinkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEEP_LINK_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                if (call.method == "getInitialLink") {
                    val link = initialDeepLink
                    initialDeepLink = null
                    result.success(link)
                } else {
                    result.notImplemented()
                }
            }
        }

        // Native Keyboard Height Channel — bypasses Flutter engine entirely
        keyboardChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            KEYBOARD_CHANNEL
        )

        initialDeepLink?.let { link ->
            deepLinkChannel?.invokeMethod("onDeepLink", link)
        }
    }

    private fun openFolderInFileManager(folderPath: String, filePath: String?): Boolean {
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
            if (samsungIntent.resolveActivity(packageManager) != null) {
                startActivity(samsungIntent)
                Log.d(TAG, "Launched Samsung My Files")
                return true
            }
        } catch (_: Exception) {}

        // Strategy 2: Android DocumentsUI packages (target ONLY genuine DocumentsUI system app)
        val docUiPackages = listOf(
            "com.google.android.documentsui",
            "com.android.documentsui"
        )
        for (pkg in docUiPackages) {
            try {
                val docUri = DocumentsContract.buildDocumentUri(
                    "com.android.externalstorage.documents",
                    "primary:$relativePath"
                )
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(docUri, DocumentsContract.Document.MIME_TYPE_DIR)
                    setPackage(pkg)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
                }
                if (intent.resolveActivity(packageManager) != null) {
                    startActivity(intent)
                    Log.d(TAG, "Launched DocumentsUI with $pkg")
                    return true
                }
            } catch (_: Exception) {}
        }

        // Strategy 3: DownloadManager ACTION_VIEW_DOWNLOADS (if inside Download)
        try {
            if (folder.absolutePath.contains("Download", ignoreCase = true)) {
                val dlIntent = Intent(DownloadManager.ACTION_VIEW_DOWNLOADS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                if (dlIntent.resolveActivity(packageManager) != null) {
                    startActivity(dlIntent)
                    Log.d(TAG, "Launched Downloads")
                    return true
                }
            }
        } catch (_: Exception) {}

        // Strategy 4: Launch installed File Manager directly (Google Files, Samsung My Files, Mi File Explorer, etc.)
        val fileManagerPackages = listOf(
            "com.sec.android.app.myfiles",
            "com.google.android.apps.nbu.files",
            "com.google.android.documentsui",
            "com.android.documentsui",
            "com.mi.android.globalFileexplorer",
            "com.coloros.filemanager"
        )
        for (pkg in fileManagerPackages) {
            try {
                val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
                if (launchIntent != null) {
                    launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(launchIntent)
                    Log.d(TAG, "Launched file manager app $pkg")
                    return true
                }
            } catch (_: Exception) {}
        }

        // Strategy 5: DocumentsUI with ACTION_OPEN_DOCUMENT_TREE scoped to DocumentsUI
        for (pkg in docUiPackages) {
            try {
                val treeUri = Uri.parse("content://com.android.externalstorage.documents/document/primary:$relativePath")
                val openDocIntent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                    setPackage(pkg)
                    putExtra(DocumentsContract.EXTRA_INITIAL_URI, treeUri)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                if (openDocIntent.resolveActivity(packageManager) != null) {
                    startActivity(openDocIntent)
                    Log.d(TAG, "Launched ACTION_OPEN_DOCUMENT_TREE with $pkg")
                    return true
                }
            } catch (_: Exception) {}
        }

        return false
    }
}
