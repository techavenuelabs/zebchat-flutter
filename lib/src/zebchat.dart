import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:zebchat_flutter/src/zebchat_user.dart';

/// The ZebChat SDK: open the chat, identify your user, track screens and handle
/// pushes.
///
/// Every call is safe before [configure] (the native SDK logs and ignores it).
/// On platforms other than Android and iOS every call is a no-op.
abstract final class ZebChat {
  /// The plugin version, reported to ZebChat as `flutter/<version>`.
  static const String version = '1.0.0';

  /// The method channel shared with the native plugins.
  @visibleForTesting
  static const MethodChannel channel = MethodChannel('com.zebchat/chat');

  /// The event channel that streams the unread count.
  @visibleForTesting
  static const EventChannel unreadChannel = EventChannel('com.zebchat/unread');

  static Stream<int>? _unreadCount;
  static bool _warnedUnsupported = false;

  /// Starts the SDK. Call once at startup, before any other call.
  ///
  /// [siteKey] is the website's site key (`zc_…`, in the dashboard's install
  /// snippets). [locale] is `auto` (the device language) or a language code
  /// such as `fr`.
  static Future<void> configure({
    required String siteKey,
    String locale = 'auto',
  }) {
    if (siteKey.trim().isEmpty) {
      throw ArgumentError.value(siteKey, 'siteKey', 'must not be empty');
    }
    return _invoke('configure', <String, String>{
      'siteKey': siteKey.trim(),
      'locale': locale,
      'sdk': 'flutter/$version',
    });
  }

  /// Identifies the signed-in user. Call after sign-in (and on every app start
  /// while signed in).
  static Future<void> setUser(ZebChatUser user) =>
      _invoke('setUser', user.toMap());

  /// Forgets the user and the visitor on this device (call on sign-out). The
  /// push token is unregistered first.
  static Future<void> logout() => _invoke('logout');

  /// Opens the full-screen chat.
  ///
  /// Throws a [PlatformException] with code `no_activity` on Android when no
  /// Activity is attached, or `no_view_controller` on iOS when there is no view
  /// controller to present from.
  static Future<void> show() => _invoke('show');

  /// Records a screen view that agents see live (for example `Checkout`).
  static Future<void> trackScreen(String name) =>
      _invoke('trackScreen', <String, String>{'name': name});

  /// Records a custom event agents see in the visitor's journey, like
  /// `ZebChat.track()` on the web (for example `added_to_cart`).
  ///
  /// [name] is 1-64 of `A-Z a-z 0-9 _ . : -`; [properties] is at most 2 KB as
  /// JSON. The native SDK logs and ignores invalid events.
  static Future<void> track(String name, {Map<String, String>? properties}) =>
      _invoke('track', <String, Object>{
        'name': name,
        if (properties != null && properties.isNotEmpty)
          'properties': properties,
      });

  /// Registers the device's FCM token so the user gets pushes for agent
  /// replies.
  ///
  /// Pass the token from `FirebaseMessaging.instance.getToken()` and from
  /// `onTokenRefresh`.
  static Future<void> setPushToken(String token) =>
      _invoke('setPushToken', <String, String>{'token': token});

  /// Whether a push message's data payload came from ZebChat.
  static bool isZebChatNotification(Map<String, dynamic> data) =>
      data['zebchat'] == '1';

  /// Opens the chat for a tapped ZebChat notification.
  ///
  /// Returns `true` when the native SDK opened the chat, and `false` (doing
  /// nothing) when [data] is not a ZebChat notification.
  static Future<bool> handleNotificationTap(Map<String, dynamic> data) async {
    if (!isZebChatNotification(data)) return false;
    final opened = await _invoke<bool>(
      'handleNotificationTap',
      <String, Object>{'data': _stringData(data)},
    );
    return opened ?? false;
  }

  /// Call for every push that arrives while the app is in the foreground
  /// (`FirebaseMessaging.onMessage`).
  ///
  /// Android: shows a ZebChat push on the `zebchat_chat` channel (FCM does not
  /// display foreground pushes). [title] and [body] override the push's own
  /// `title` / `body`. Returns `false` when the chat is already on screen or
  /// notifications are not allowed.
  ///
  /// iOS: the system presents the notification (see the README); this only
  /// refreshes the unread count and returns `false`.
  ///
  /// Returns `false` (and does nothing) when [data] is not a ZebChat
  /// notification.
  static Future<bool> showNotification(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) async {
    if (!isZebChatNotification(data)) return false;
    final shown = await _invoke<bool>('showNotification', <String, Object>{
      'data': _stringData(data),
      if (title != null) 'title': title,
      if (body != null) 'body': body,
    });
    return shown ?? false;
  }

  /// Changes the chat language (`auto` or a language code); applies on the next
  /// [show].
  static Future<void> setLocale(String locale) =>
      _invoke('setLocale', <String, String>{'locale': locale});

  /// The last unread count the native SDK knows (0 before the first update,
  /// and on unsupported platforms).
  static Future<int> getUnreadCount() async =>
      await _invoke<int>('getUnreadCount') ?? 0;

  /// Asks ZebChat for the unread count now; [unreadCount] listeners hear about
  /// a change.
  ///
  /// Android only: on iOS the native SDK refreshes on its own (app foreground,
  /// [showNotification], chat closed), so this does nothing there.
  static Future<void> refreshUnreadCount() => _invoke('refreshUnreadCount');

  /// The number of unread agent messages, updated live.
  static Stream<int> get unreadCount => _unreadCount ??= unreadChannel
      .receiveBroadcastStream()
      .where((event) => event is int && event >= 0)
      .map((event) => event! as int);

  /// Resets cached state between tests.
  @visibleForTesting
  static void resetForTesting() {
    _unreadCount = null;
    _warnedUnsupported = false;
  }

  static Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      if (!_warnedUnsupported) {
        _warnedUnsupported = true;
        debugPrint(
          'ZebChat: this platform is not supported (Android and iOS only).',
        );
      }
      return null;
    }
  }

  /// FCM data values are strings; anything else is stringified and nulls are
  /// dropped.
  static Map<String, String> _stringData(Map<String, dynamic> data) =>
      <String, String>{
        for (final MapEntry<String, dynamic> entry in data.entries)
          if (entry.value != null) entry.key: '${entry.value}',
      };
}
