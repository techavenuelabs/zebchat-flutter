package com.zebchat.flutter

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.zebchat.chat.UnreadListener
import com.zebchat.chat.ZebChat
import com.zebchat.chat.ZebChatOptions
import com.zebchat.chat.ZebChatUser
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter glue for the native ZebChat SDK (com.zebchat:chat). Thin by design: every method maps
 * one-to-one onto a `ZebChat` call; the Dart side (lib/src/zebchat.dart) owns argument shapes.
 * The plugin reports itself to ZebChat as `flutter/<version>` (ZebChatOptions.sdk).
 */
class ZebChatPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware {
    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var unreadChannel: EventChannel
    private var activity: Activity? = null
    private var unreadListener: UnreadListener? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, "com.zebchat/chat")
        methodChannel.setMethodCallHandler(this)
        unreadChannel = EventChannel(binding.binaryMessenger, "com.zebchat/unread")
        unreadChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        unreadChannel.setStreamHandler(null)
        onCancel(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "configure" -> {
                val siteKey = call.argument<String>("siteKey")
                if (siteKey.isNullOrBlank()) {
                    result.error("invalid_argument", "siteKey is required", null)
                    return
                }
                ZebChat.configure(
                    context,
                    siteKey = siteKey,
                    options = ZebChatOptions(
                        locale = call.argument<String>("locale") ?: "auto",
                        sdk = call.argument<String>("sdk") ?: SDK,
                    ),
                )
                result.success(null)
            }
            "setUser" -> {
                ZebChat.setUser(
                    ZebChatUser(
                        id = call.argument<String>("id"),
                        email = call.argument<String>("email"),
                        name = call.argument<String>("name"),
                        phone = call.argument<String>("phone"),
                        hash = call.argument<String>("hash"),
                    ),
                )
                result.success(null)
            }
            "logout" -> {
                ZebChat.logout()
                result.success(null)
            }
            "show" -> {
                val current = activity ?: return noActivity(result)
                ZebChat.show(current)
                result.success(null)
            }
            "trackScreen" -> {
                call.argument<String>("name")?.let { ZebChat.trackScreen(it) }
                result.success(null)
            }
            "track" -> {
                call.argument<String>("name")?.let { ZebChat.track(it, stringMap(call, "properties")) }
                result.success(null)
            }
            "setPushToken" -> {
                call.argument<String>("token")?.let { ZebChat.setPushToken(it) }
                result.success(null)
            }
            "handleNotificationTap" -> {
                val current = activity ?: return noActivity(result)
                result.success(ZebChat.handleNotificationTap(current, stringData(call)))
            }
            "showNotification" -> {
                result.success(
                    ZebChat.showNotification(
                        context,
                        stringData(call),
                        title = call.argument<String>("title"),
                        body = call.argument<String>("body"),
                    ),
                )
            }
            "getUnreadCount" -> result.success(ZebChat.unreadCount)
            "refreshUnreadCount" -> {
                ZebChat.refreshUnreadCount()
                result.success(null)
            }
            "setLocale" -> {
                call.argument<String>("locale")?.let { ZebChat.setLocale(it) }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // ---- unread count (event channel) ----------------------------------------------------------

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        onCancel(null)
        // Native calls back on the main thread; post anyway so ordering never depends on it.
        val listener = UnreadListener { count -> mainHandler.post { events.success(count) } }
        unreadListener = listener
        ZebChat.addUnreadListener(listener)
    }

    override fun onCancel(arguments: Any?) {
        unreadListener?.let { ZebChat.removeUnreadListener(it) }
        unreadListener = null
    }

    // ---- ActivityAware: show() and notification taps need the current Activity ----------------

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    private fun noActivity(result: MethodChannel.Result) =
        result.error("no_activity", "ZebChat needs a foreground Activity to open the chat", null)

    /** FCM data from Dart (`{data: Map<String, String>}`); non-string entries are dropped. */
    private fun stringData(call: MethodCall): Map<String, String> = stringMap(call, "data") ?: emptyMap()

    /** The string entries of the map argument [name], or null when it is missing. */
    private fun stringMap(call: MethodCall, name: String): Map<String, String>? {
        val raw = call.argument<Map<*, *>>(name) ?: return null
        return buildMap {
            for ((key, value) in raw) {
                if (key is String && value is String) put(key, value)
            }
        }
    }

    private companion object {
        /** Fallback for `ZebChatOptions.sdk` (Dart sends `flutter/<ZebChat.version>`). */
        const val SDK = "flutter/1.0.0"
    }
}
