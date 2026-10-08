import Flutter
import UIKit
import ZebChat

/// Flutter glue for the native ZebChat SDK (pod `ZebChat`). Thin by design: every method maps
/// one-to-one onto a `ZebChat` call; the Dart side (lib/src/zebchat.dart) owns argument shapes.
/// The plugin reports itself to ZebChat as `flutter/<version>` (`ZebChatOptions.wrapperSDK`).
///
/// Flutter delivers method calls on the main thread; the two calls that present the chat find
/// the top view controller (UIKit, main actor) inside `MainActor.assumeIsolated` and call the SDK
/// right away.
public final class ZebChatPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var unreadToken: ZebChatListenerToken?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = ZebChatPlugin()
    let methods = FlutterMethodChannel(name: "com.zebchat/chat", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    let unread = FlutterEventChannel(name: "com.zebchat/unread", binaryMessenger: registrar.messenger())
    unread.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "configure":
      guard let siteKey = args["siteKey"] as? String, !siteKey.isEmpty else {
        result(FlutterError(code: "invalid_argument", message: "siteKey is required", details: nil))
        return
      }
      let options = ZebChatOptions(
        locale: args["locale"] as? String ?? "auto",
        wrapperSDK: args["sdk"] as? String ?? Self.sdk
      )
      ZebChat.configure(siteKey: siteKey, options: options)
      result(nil)
    case "setUser":
      ZebChat.setUser(
        ZebChatUser(
          id: args["id"] as? String,
          email: args["email"] as? String,
          name: args["name"] as? String,
          phone: args["phone"] as? String,
          hash: args["hash"] as? String
        )
      )
      result(nil)
    case "logout":
      ZebChat.logout()
      result(nil)
    case "show":
      MainActor.assumeIsolated {
        guard let presenter = Self.topViewController() else { return Self.noViewController(result) }
        ZebChat.show(from: presenter)
        result(nil)
      }
    case "trackScreen":
      if let name = args["name"] as? String { ZebChat.trackScreen(name) }
      result(nil)
    case "track":
      if let name = args["name"] as? String {
        ZebChat.track(name, properties: Self.stringMap(args["properties"]))
      }
      result(nil)
    case "setPushToken":
      if let token = args["token"] as? String { ZebChat.setPushToken(token) }
      result(nil)
    case "handleNotificationTap":
      let userInfo = Self.stringData(args)
      MainActor.assumeIsolated {
        guard let presenter = Self.topViewController() else { return Self.noViewController(result) }
        result(ZebChat.handleNotificationTap(userInfo, from: presenter))
      }
    case "showNotification":
      // iOS presents foreground notifications through the system (the host's notification
      // delegate); a ZebChat push only refreshes the unread count here.
      ZebChat.notificationReceived(Self.stringData(args))
      result(false)
    case "getUnreadCount":
      result(ZebChat.unreadCount)
    case "refreshUnreadCount":
      // The iOS SDK refreshes on its own (foreground, ZebChat pushes, chat closed).
      result(nil)
    case "setLocale":
      if let locale = args["locale"] as? String { ZebChat.setLocale(locale) }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Unread count (event channel)

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    stopUnread()
    unreadToken = ZebChat.addUnreadListener { count in
      DispatchQueue.main.async { events(count) }
    }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopUnread()
    return nil
  }

  private func stopUnread() {
    if let token = unreadToken { ZebChat.removeUnreadListener(token) }
    unreadToken = nil
  }

  // MARK: - Helpers

  /// Fallback for `ZebChatOptions.wrapperSDK` (Dart sends `flutter/<ZebChat.version>`).
  private static let sdk = "flutter/1.0.0"

  private static func noViewController(_ result: FlutterResult) {
    result(FlutterError(code: "no_view_controller", message: "ZebChat needs a view controller to present the chat", details: nil))
  }

  /// FCM data from Dart (`{data: [String: String]}`); non-string entries are dropped.
  /// The string entries of a map argument, or nil when it is missing.
  private static func stringMap(_ value: Any?) -> [String: String]? {
    guard let raw = value as? [String: Any] else { return nil }
    var out: [String: String] = [:]
    for (key, value) in raw {
      if let value = value as? String { out[key] = value }
    }
    return out
  }

  private static func stringData(_ args: [String: Any]) -> [AnyHashable: Any] {
    guard let raw = args["data"] as? [String: Any] else { return [:] }
    var out: [AnyHashable: Any] = [:]
    for (key, value) in raw {
      if let value = value as? String { out[key] = value }
    }
    return out
  }

  /// The top-most view controller of the foreground key window.
  @MainActor
  private static func topViewController() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    var top = window?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}
