import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zebchat_flutter/zebchat_flutter.dart';

/// Run with your site key:
/// `flutter run --dart-define=ZEBCHAT_SITE_KEY=zc_…`
///
/// Add this app's id (Android `com.zebchat.zebchat_example`, iOS
/// `com.zebchat.zebchatExample`) under Website → Mobile apps in the dashboard.
const String siteKey = String.fromEnvironment('ZEBCHAT_SITE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (siteKey.isNotEmpty) {
    await ZebChat.configure(siteKey: siteKey);
  }
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZebChat example',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF16A34A)),
      navigatorObservers: [ZebChatScreenObserver()],
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/products': (_) => const ProductsScreen(),
      },
    );
  }
}

/// Sends a screen view for every named route, so agents see where the user is.
class ZebChatScreenObserver extends NavigatorObserver {
  void _track(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null) unawaited(ZebChat.trackScreen(name));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _track(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _track(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _track(newRoute);
}

/// The chat button with the live unread count.
class ChatButton extends StatelessWidget {
  const ChatButton({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: ZebChat.unreadCount,
      initialData: 0,
      builder: (context, snapshot) {
        final unread = snapshot.data ?? 0;
        return FloatingActionButton.extended(
          onPressed: ZebChat.show,
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(Icons.chat_bubble_outline),
          ),
          label: const Text('Chat with us'),
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _signedIn = false;
  String _locale = 'auto';

  Future<void> _signIn() async {
    // In a real app, `hash` comes from your server:
    // hex(HMAC-SHA256(identitySecret, id)).
    await ZebChat.setUser(
      const ZebChatUser(id: 'demo-42', email: 'ana@example.com', name: 'Ana'),
    );
    setState(() => _signedIn = true);
  }

  Future<void> _signOut() async {
    await ZebChat.logout();
    setState(() => _signedIn = false);
  }

  Future<void> _setLocale(String? locale) async {
    if (locale == null) return;
    await ZebChat.setLocale(locale);
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ZebChat example')),
      floatingActionButton: const ChatButton(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (siteKey.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No site key: run with '
                  '--dart-define=ZEBCHAT_SITE_KEY=zc_…',
                ),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(_signedIn ? 'Signed in as Ana' : 'Not signed in'),
            trailing: _signedIn
                ? TextButton(onPressed: _signOut, child: const Text('Sign out'))
                : FilledButton(
                    onPressed: _signIn,
                    child: const Text('Sign in'),
                  ),
          ),
          ListTile(
            leading: const Icon(Icons.translate),
            title: const Text('Chat language'),
            trailing: DropdownButton<String>(
              value: _locale,
              onChanged: _setLocale,
              items: const [
                DropdownMenuItem(value: 'auto', child: Text('Device')),
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'fr', child: Text('Français')),
                DropdownMenuItem(value: 'es', child: Text('Español')),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('Products'),
            subtitle: const Text('Opens a screen that is tracked as a view'),
            onTap: () => Navigator.of(context).pushNamed('/products'),
          ),
        ],
      ),
    );
  }
}

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      floatingActionButton: const ChatButton(),
      body: ListView(
        children: const [
          ListTile(title: Text('Starter plan')),
          ListTile(title: Text('Team plan')),
          ListTile(title: Text('Business plan')),
        ],
      ),
    );
  }
}
