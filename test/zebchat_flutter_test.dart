import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zebchat_flutter/zebchat_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  /// What the fake native side answers, by method (null otherwise).
  late Map<String, Object?> replies;

  setUp(() {
    calls = <MethodCall>[];
    replies = <String, Object?>{};
    ZebChat.resetForTesting();
    messenger.setMockMethodCallHandler(ZebChat.channel, (call) async {
      calls.add(call);
      return replies[call.method];
    });
  });

  tearDown(() {
    messenger
      ..setMockMethodCallHandler(ZebChat.channel, null)
      ..setMockStreamHandler(ZebChat.unreadChannel, null);
  });

  test('uses the documented channel names', () {
    expect(ZebChat.channel.name, 'com.zebchat/chat');
    expect(ZebChat.unreadChannel.name, 'com.zebchat/unread');
  });

  group('configure', () {
    test('sends the site key, locale and sdk name', () async {
      await ZebChat.configure(siteKey: ' zc_abc ', locale: 'fr');
      expect(calls.single.method, 'configure');
      expect(calls.single.arguments, <String, String>{
        'siteKey': 'zc_abc',
        'locale': 'fr',
        'sdk': 'flutter/${ZebChat.version}',
      });
    });

    test('defaults the locale to auto', () async {
      await ZebChat.configure(siteKey: 'zc_abc');
      expect(
        (calls.single.arguments as Map<Object?, Object?>)['locale'],
        'auto',
      );
    });

    test('rejects an empty site key without calling native', () {
      expect(() => ZebChat.configure(siteKey: '  '), throwsArgumentError);
      expect(calls, isEmpty);
    });
  });

  test('setUser sends only the fields that are set', () async {
    await ZebChat.setUser(
      const ZebChatUser(id: '42', email: 'a@b.com', hash: 'h'),
    );
    expect(calls.single.method, 'setUser');
    expect(
      calls.single.arguments,
      <String, String>{'id': '42', 'email': 'a@b.com', 'hash': 'h'},
    );
  });

  test('setUser sends every field', () async {
    await ZebChat.setUser(
      const ZebChatUser(
        id: '42',
        email: 'a@b.com',
        name: 'Ana',
        phone: '+1 555',
        hash: 'h',
      ),
    );
    expect(calls.single.arguments, <String, String>{
      'id': '42',
      'email': 'a@b.com',
      'name': 'Ana',
      'phone': '+1 555',
      'hash': 'h',
    });
  });

  test('logout, show', () async {
    await ZebChat.logout();
    await ZebChat.show();
    expect(calls.map((c) => c.method), <String>['logout', 'show']);
    expect(calls.map((c) => c.arguments), <Object?>[null, null]);
  });

  test('trackScreen', () async {
    await ZebChat.trackScreen('Checkout');
    expect(calls.single.method, 'trackScreen');
    expect(calls.single.arguments, <String, String>{'name': 'Checkout'});
  });

  test('track', () async {
    await ZebChat.track('added_to_cart', properties: {'sku': 'A1'});
    await ZebChat.track('signed_up');
    await ZebChat.track('empty', properties: {});
    expect(calls.map((c) => c.method), <String>['track', 'track', 'track']);
    expect(calls.map((c) => c.arguments), <Object?>[
      <String, Object>{
        'name': 'added_to_cart',
        'properties': <String, String>{'sku': 'A1'},
      },
      <String, Object>{'name': 'signed_up'},
      <String, Object>{'name': 'empty'},
    ]);
  });

  test('setPushToken', () async {
    await ZebChat.setPushToken('fcm-token');
    expect(calls.single.method, 'setPushToken');
    expect(calls.single.arguments, <String, String>{'token': 'fcm-token'});
  });

  test('setLocale', () async {
    await ZebChat.setLocale('de');
    expect(calls.single.method, 'setLocale');
    expect(calls.single.arguments, <String, String>{'locale': 'de'});
  });

  group('isZebChatNotification', () {
    test('true only for zebchat == "1"', () {
      expect(
        ZebChat.isZebChatNotification(<String, dynamic>{'zebchat': '1'}),
        isTrue,
      );
      expect(
        ZebChat.isZebChatNotification(<String, dynamic>{
          'zebchat': '1',
          'conversationId': 'c',
          'siteKey': 'zc_abc',
        }),
        isTrue,
      );
      expect(ZebChat.isZebChatNotification(<String, dynamic>{}), isFalse);
      expect(
        ZebChat.isZebChatNotification(<String, dynamic>{'zebchat': 1}),
        isFalse,
      );
      expect(
        ZebChat.isZebChatNotification(<String, dynamic>{'zebchat': '0'}),
        isFalse,
      );
      expect(
        ZebChat.isZebChatNotification(<String, dynamic>{'zebchat': true}),
        isFalse,
      );
      expect(
        ZebChat.isZebChatNotification(<String, dynamic>{'other': '1'}),
        isFalse,
      );
    });
  });

  group('handleNotificationTap', () {
    test('opens the chat for a ZebChat push, with string data', () async {
      replies['handleNotificationTap'] = true;
      final handled = await ZebChat.handleNotificationTap(<String, dynamic>{
        'zebchat': '1',
        'conversationId': 'c1',
        'n': 3,
        'empty': null,
      });
      expect(handled, isTrue);
      expect(calls.single.method, 'handleNotificationTap');
      expect(calls.single.arguments, <String, Object>{
        'data': <String, String>{
          'zebchat': '1',
          'conversationId': 'c1',
          'n': '3',
        },
      });
    });

    test('returns what native reports', () async {
      replies['handleNotificationTap'] = false;
      expect(
        await ZebChat.handleNotificationTap(<String, dynamic>{'zebchat': '1'}),
        isFalse,
      );
      expect(calls.single.method, 'handleNotificationTap');
    });

    test('ignores other pushes', () async {
      expect(
        await ZebChat.handleNotificationTap(
          <String, dynamic>{'type': 'promo'},
        ),
        isFalse,
      );
      expect(calls, isEmpty);
    });
  });

  group('showNotification', () {
    test('forwards a ZebChat push and returns what native reports', () async {
      replies['showNotification'] = true;
      final shown =
          await ZebChat.showNotification(<String, dynamic>{'zebchat': '1'});
      expect(shown, isTrue);
      expect(calls.single.method, 'showNotification');
      expect(calls.single.arguments, <String, Object>{
        'data': <String, String>{'zebchat': '1'},
      });
    });

    test('passes the title and body overrides', () async {
      await ZebChat.showNotification(
        <String, dynamic>{'zebchat': '1'},
        title: 'Support',
        body: 'New reply',
      );
      expect(calls.single.arguments, <String, Object>{
        'data': <String, String>{'zebchat': '1'},
        'title': 'Support',
        'body': 'New reply',
      });
    });

    test('is false when native shows nothing (iOS, chat open)', () async {
      replies['showNotification'] = false;
      expect(
        await ZebChat.showNotification(<String, dynamic>{'zebchat': '1'}),
        isFalse,
      );
      expect(calls, hasLength(1));
    });

    test('ignores other pushes', () async {
      expect(
        await ZebChat.showNotification(<String, dynamic>{'type': 'promo'}),
        isFalse,
      );
      expect(calls, isEmpty);
    });
  });

  group('unread count calls', () {
    test('getUnreadCount returns the native count', () async {
      replies['getUnreadCount'] = 4;
      expect(await ZebChat.getUnreadCount(), 4);
      expect(calls.single.method, 'getUnreadCount');
    });

    test('getUnreadCount is 0 without a plugin', () async {
      messenger.setMockMethodCallHandler(ZebChat.channel, null);
      expect(await ZebChat.getUnreadCount(), 0);
    });

    test('refreshUnreadCount', () async {
      await ZebChat.refreshUnreadCount();
      expect(calls.single.method, 'refreshUnreadCount');
      expect(calls.single.arguments, isNull);
    });
  });

  test('pushes are false without a plugin', () async {
    messenger.setMockMethodCallHandler(ZebChat.channel, null);
    final push = <String, dynamic>{'zebchat': '1'};
    expect(await ZebChat.handleNotificationTap(push), isFalse);
    expect(await ZebChat.showNotification(push), isFalse);
  });

  test('native errors reach the caller', () async {
    messenger.setMockMethodCallHandler(ZebChat.channel, (call) async {
      throw PlatformException(code: 'no_activity');
    });
    await expectLater(
      ZebChat.show(),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'no_activity'),
      ),
    );
  });

  test('calls are no-ops when the platform has no plugin', () async {
    messenger.setMockMethodCallHandler(ZebChat.channel, null);
    await ZebChat.configure(siteKey: 'zc_abc');
    await ZebChat.trackScreen('Home');
  });

  group('unreadCount', () {
    test('streams counts and drops malformed events', () async {
      messenger.setMockStreamHandler(
        ZebChat.unreadChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events
              ..success(0)
              ..success('7')
              ..success(-1)
              ..success(3)
              ..endOfStream();
          },
        ),
      );
      expect(await ZebChat.unreadCount.toList(), <int>[0, 3]);
    });

    test('is one shared broadcast stream', () async {
      messenger.setMockStreamHandler(
        ZebChat.unreadChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success(5);
          },
        ),
      );
      expect(identical(ZebChat.unreadCount, ZebChat.unreadCount), isTrue);
      final a = <int>[];
      final b = <int>[];
      final subA = ZebChat.unreadCount.listen(a.add);
      final subB = ZebChat.unreadCount.listen(b.add);
      await pumpEventQueue();
      expect(a, <int>[5]);
      expect(b, <int>[5]);
      await subA.cancel();
      await subB.cancel();
    });
  });

  test('ZebChatUser equality', () {
    expect(
      const ZebChatUser(id: '1', name: 'A'),
      const ZebChatUser(id: '1', name: 'A'),
    );
    expect(
      const ZebChatUser(id: '1').hashCode,
      const ZebChatUser(id: '1').hashCode,
    );
    expect(const ZebChatUser(id: '1') == const ZebChatUser(id: '2'), isFalse);
    expect(const ZebChatUser().toMap(), isEmpty);
  });

  test('ZebChatUser keeps personal data out of toString', () {
    final text = const ZebChatUser(
      id: '42',
      email: 'a@b.com',
      name: 'Ana',
      phone: '+1 555',
      hash: 'secret',
    ).toString();
    for (final value in <String>['42', 'a@b.com', 'Ana', '555', 'secret']) {
      expect(text, isNot(contains(value)));
    }
    expect(const ZebChatUser().toString(), contains('id: null'));
  });
}
