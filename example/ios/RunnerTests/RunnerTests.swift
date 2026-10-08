import Flutter
import UIKit
import XCTest

@testable import zebchat_flutter

/// Unit tests for the Swift side of the zebchat_flutter plugin (run with `xcodebuild test` on macOS).
class RunnerTests: XCTestCase {
  private func call(_ method: String, _ arguments: Any? = nil) -> Any? {
    let plugin = ZebChatPlugin()
    var received: Any?
    let done = expectation(description: "result")
    plugin.handle(FlutterMethodCall(methodName: method, arguments: arguments)) { result in
      received = result
      done.fulfill()
    }
    waitForExpectations(timeout: 1)
    return received
  }

  func testUnknownMethodIsNotImplemented() {
    XCTAssertTrue((call("nope") as AnyObject) === (FlutterMethodNotImplemented as AnyObject))
  }

  /// iOS presents foreground pushes through the system: the plugin only refreshes the count.
  func testShowNotificationReturnsFalseOnIOS() {
    XCTAssertEqual(call("showNotification", ["data": ["zebchat": "1"]]) as? Bool, false)
  }

  func testUnreadCountBeforeConfigureIsZero() {
    XCTAssertEqual(call("getUnreadCount") as? Int, 0)
  }

  func testConfigureRequiresASiteKey() {
    XCTAssertEqual((call("configure", ["siteKey": ""]) as? FlutterError)?.code, "invalid_argument")
  }
}
