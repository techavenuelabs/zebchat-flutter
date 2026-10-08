/// ZebChat live chat for Flutter apps.
///
/// Wraps the native ZebChat Android and iOS SDKs: a full-screen chat for your
/// users, identity (`setUser`), screen views, the unread count and push
/// notifications.
///
/// ```dart
/// import 'package:zebchat_flutter/zebchat_flutter.dart';
///
/// await ZebChat.configure(siteKey: 'zc_…');
/// await ZebChat.show();
/// ```
library;

export 'src/zebchat.dart' show ZebChat;
export 'src/zebchat_user.dart' show ZebChatUser;
