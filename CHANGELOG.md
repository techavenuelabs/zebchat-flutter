# Changelog

## 1.0.0

- First release. Wraps the ZebChat Android SDK (`com.zebchat:chat:1.0.0`) and iOS SDK
  (pod `ZebChat` 1.0).
- `ZebChat.configure`, `setUser`, `logout`, `show`, `trackScreen`, `setLocale`.
- Push notifications through your own Firebase project: `setPushToken`,
  `isZebChatNotification`, `showNotification` (Android), `handleNotificationTap`.
- `ZebChat.unreadCount` stream for badges, `getUnreadCount()` and `refreshUnreadCount()`.
- Reports itself to ZebChat as `flutter/1.0.0`.
- Android: builds with AGP 8 and the classic Kotlin plugin (Flutter 3.22+) and with AGP 9.
