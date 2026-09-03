package com.grs.perch

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Share-sheet ingestion.
 *
 * Perch only ever needs one thing out of an incoming intent — the shared text,
 * which is where the URL lives. A cold start parks it until Dart asks for it; a
 * warm share pushes it straight down the event channel.
 */
class MainActivity : FlutterActivity() {
    private companion object {
        const val METHOD_CHANNEL = "com.grs.perch/share"
        const val EVENT_CHANNEL = "com.grs.perch/share_events"
    }

    private var events: EventChannel.EventSink? = null
    private var pending: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Read before super, which is what builds the engine and asks Dart for
        // the initial text.
        pending = extractSharedText(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialText" -> {
                        result.success(pending)
                        // Consumed — a later restart must not re-save it.
                        pending = null
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                        events = sink
                    }

                    override fun onCancel(arguments: Any?) {
                        events = null
                    }
                },
            )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val text = extractSharedText(intent) ?: return
        val sink = events
        if (sink != null) sink.success(text) else pending = text
    }

    private fun extractSharedText(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_SEND) return null
        if (intent.type?.startsWith("text/") != true) return null
        return intent.getStringExtra(Intent.EXTRA_TEXT)?.takeIf { it.isNotBlank() }
    }
}
