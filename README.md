# ZebChat for Flutter

Live chat with your users, inside your Flutter app. `zebchat_flutter` wraps the native ZebChat
[Android](https://central.sonatype.com/artifact/com.zebchat/chat) and iOS SDKs: a full-screen chat
with every feature of the website widget (including file and photo uploads), user identity,
screen views agents see live, an unread count for badges, and push notifications for agent replies
through **your own** Firebase project.

| Platform | Minimum                                           |
| -------- | ------------------------------------------------- |
| Flutter  | 3.22 (Dart 3.4)                                   |
| Android  | minSdk 23, compileSdk 35+, AGP 8+, Kotlin 1.9.20+ |
| iOS      | 14.0                                              |
| Other    | Not supported: every call is a no-op              |

## 1. Allow your app

In the ZebChat dashboard open **Websites → your website → Mobile apps** and add your Android
package name (`applicationId`) and iOS bundle id. The chat refuses apps that are not listed. The
same tab has your site key and install snippets.

## 2. Install

```bash
flutter pub add zebchat_flutter
```

**iOS:** set the platform in `ios/Podfile` and run `pod install`:

```ruby
platform :ios, '14.0'
```

Add to `ios/Runner/Info.plist` (visitors can send photos):

```xml
<key>NSCameraUsageDescription</key>
<string>Take a photo to send in the chat.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Choose a photo to send in the chat.</string>
```

**Android:** set `minSdk = 23` (or higher) in `android/app/build.gradle(.kts)`; apps created with
Flutter 3.22–3.27 default to 21. The plugin builds with the classic Kotlin Gradle plugin (AGP 8,
`kotlin-android`) as well as AGP 9's built-in Kotlin. On Flutter 3.44+ with
`android.builtInKotlin=false`, Flutter prints a notice that `zebchat_flutter` applies the Kotlin
Gradle plugin: that is expected (it keeps older Flutter versions working) and the build succeeds.
The SDK does not declare `CAMERA`; if your app declares and holds it, the chat's file picker also
offers the camera.

## 3. Quick start

```dart
import 'package:flutter/material.dart';
import 'package:zebchat_flutter/zebchat_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ZebChat.configure(siteKey: 'zc_your_site_key'); // locale: 'auto' by default
  runApp(const MyApp());
}

// Anywhere, for example a "Help" button:
ElevatedButton(onPressed: ZebChat.show, child: const Text('Chat with us'));
```

### Identify your user

```dart
await ZebChat.setUser(ZebChatUser(
  id: user.id,
  email: user.email,
  name: user.name,
  phone: user.phone,
  hash: user.zebchatHash, // from your server, see below
));

// On sign-out:
await ZebChat.logout();
```

With **identity verification** on (an identity secret is set for the website), send `id` together with
`hash = hex(HMAC-SHA256(identitySecret, id))`, computed on **your server**. Never put the identity
secret in the app.

### Track screens

Agents see the current screen live. Track named routes with a `NavigatorObserver`:

```dart
class ZebChatScreenObserver extends NavigatorObserver {
  void _track(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null) ZebChat.trackScreen(name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _track(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _track(previousRoute);
}

MaterialApp(navigatorObservers: [ZebChatScreenObserver()], ...);
```

Or call `ZebChat.trackScreen('Checkout')` yourself. Views are buffered while offline.

### Unread badge

`ZebChat.unreadCount` streams the count (the current value first, then every change).
`await ZebChat.getUnreadCount()` reads the last known value once.

```dart
StreamBuilder<int>(
  stream: ZebChat.unreadCount,
  initialData: 0,
  builder: (context, snapshot) => Badge(
    isLabelVisible: (snapshot.data ?? 0) > 0,
    label: Text('${snapshot.data}'),
    child: const Icon(Icons.chat_bubble_outline),
  ),
);
```

### Language

`configure(siteKey: …, locale: 'fr')` or later `ZebChat.setLocale('fr')` (applies the next time
the chat opens). `auto` follows the device language.

## 4. Push notifications

ZebChat sends pushes for agent replies while your app is in the background, through **your**
Firebase project (FCM for Android and iOS). The plugin does not depend on Firebase: you forward
the token and the message data.

1. In the dashboard (**Mobile apps → Push notifications**) upload a Firebase service account JSON
   for your project, then use **Send test push** with a device token.
2. iOS: upload your APNs key to your Firebase project, and enable the **Push Notifications**
   capability and **Background Modes → Remote notifications** in Xcode.
3. Wire [`firebase_messaging`](https://pub.dev/packages/firebase_messaging):

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:zebchat_flutter/zebchat_flutter.dart';

Future<void> setUpZebChatPush() async {
  final messaging = FirebaseMessaging.instance;

  // Your app decides when to ask (Android 13+ and iOS).
  await messaging.requestPermission();

  // iOS: show ZebChat notifications while the app is open.
  await messaging.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // Register the token, and again whenever it changes.
  final token = await messaging.getToken();
  if (token != null) await ZebChat.setPushToken(token);
  messaging.onTokenRefresh.listen(ZebChat.setPushToken);

  // Android: FCM does not display notifications while the app is in the foreground.
  FirebaseMessaging.onMessage.listen((message) {
    if (ZebChat.isZebChatNotification(message.data)) {
      ZebChat.showNotification(message.data);
    }
  });

  // Tapped while in the background, or the tap that launched the app.
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    ZebChat.handleNotificationTap(message.data);
  });
  final initial = await messaging.getInitialMessage();
  if (initial != null) await ZebChat.handleNotificationTap(initial.data);
}
```

Call it after `ZebChat.configure`. `handleNotificationTap` and `showNotification` return `false`
and do nothing for pushes that are not from ZebChat, so they are safe to call for every message.
The SDK creates the Android channel `zebchat_chat`; it never declares a
`FirebaseMessagingService` and never requests the notification permission itself.

A visitor who has your website open in a browser tab counts as online and gets no push.

## API

| Call                                    | What it does                                                                                                             |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `configure(siteKey:, locale:)`          | Start the SDK. Call once, first.                                                                                         |
| `setUser(ZebChatUser(...))`             | Identify the signed-in user (`id`, `email`, `name`, `phone`, `hash`).                                                    |
| `logout()`                              | Unregister the push token, forget the user and the visitor.                                                              |
| `show()`                                | Open the full-screen chat.                                                                                               |
| `trackScreen(name)`                     | Record a screen view.                                                                                                    |
| `track(name, properties:)`              | Custom event, like `ZebChat.track()` on the web: `name` 1–64 of `A-Z a-z 0-9 _ . : -`, string properties ≤ 2 KB as JSON. |
| `setLocale(locale)`                     | Chat language (`auto` or a code); applies on the next `show()`.                                                          |
| `setPushToken(token)`                   | Register the FCM token.                                                                                                  |
| `isZebChatNotification(data)`           | `true` when `data['zebchat'] == '1'`.                                                                                    |
| `showNotification(data, title:, body:)` | Android: show a foreground ZebChat push (`false` if the chat is open). iOS: refreshes the unread count, returns `false`. |
| `handleNotificationTap(data)`           | Open the chat for a tapped ZebChat push; `true` when it did.                                                             |
| `unreadCount`                           | `Stream<int>` of unread agent messages.                                                                                  |
| `getUnreadCount()`                      | The last known unread count.                                                                                             |
| `refreshUnreadCount()`                  | Android: read the count now. iOS: no-op (the SDK refreshes on its own).                                                  |

Every call is safe before `configure` (the native SDK logs and ignores it). `show()` throws a
`PlatformException` (`no_activity` / `no_view_controller`) when there is no screen to present
from.

## Privacy

The SDK stores a random visitor key in the Keychain (iOS) or private, backup-excluded storage
(Android). It sends the user details you pass to `setUser`, screen names, app id and version, OS
version and device model to ZebChat. The iOS SDK ships a privacy manifest (no tracking).

## Licence

MIT. See [LICENSE](LICENSE).
