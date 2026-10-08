# Publishing `zebchat_flutter` to pub.dev

Nothing is published yet (Phase 15). This is the release checklist.

## Order

The plugin depends on the **published** native SDKs, so release them first:

1. Android: `com.zebchat:chat:<v>` on Maven Central (`sdks/android/PUBLISHING.md`).
2. iOS: pod `ZebChat` `<v>` on CocoaPods trunk (`sdks/ios/PUBLISHING.md`).
3. Then this plugin.

Check that both are resolvable from a clean machine (no `~/.m2` copy, no `:path` pod) before
publishing the plugin.

## Accounts

- pub.dev **verified publisher** `zebchat.com` (DNS-verified in Google Search Console). Publish
  as the publisher, not a personal account.
- The package is `zebchat_flutter`, not `zebchat`: the iOS plugin pod is named after the package,
  and a pod/module `zebchat` would collide with the SDK's `ZebChat` on case-insensitive file
  systems (macOS). The Dart class stays `ZebChat`.
- `pubspec.yaml` has no `repository` / `issue_tracker` yet: there is no public repository. Before
  the first release, create the public mirror of `sdks/flutter` (like the Drupal module and the
  `zebchat-ios` mirror), then add `repository:` and `issue_tracker:` pointing at it (pub.dev
  scores packages without them lower).

## Version bump (all in one commit)

| File                                                              | Field                                                     |
| ----------------------------------------------------------------- | --------------------------------------------------------- |
| `pubspec.yaml`                                                    | `version`                                                 |
| `lib/src/zebchat.dart`                                            | `ZebChat.version` (reported as `flutter/<v>`)             |
| `android/build.gradle`                                            | `version` and `com.zebchat:chat:<native v>`               |
| `ios/zebchat_flutter.podspec`                                     | `s.version` and `s.dependency 'ZebChat', '~> <native v>'` |
| `android/.../ZebChatPlugin.kt`, `ios/Classes/ZebChatPlugin.swift` | `SDK` / `sdk` fallback `flutter/<v>`                      |
| `CHANGELOG.md`                                                    | New section on top                                        |

## Checks

```bash
cd sdks/flutter
flutter pub get
dart format --set-exit-if-changed lib test example/lib
flutter analyze
flutter test
(cd example && flutter build apk --debug)   # needs com.zebchat:chat in mavenLocal or Central
(cd example/ios && pod install)              # macOS
flutter pub publish --dry-run
```

`--dry-run` must report 0 warnings. The package score expects: description 60–180 chars, a
LICENSE, an example, dartdoc on every public member (enforced by `very_good_analysis`).

## Publish

```bash
flutter pub publish
```

Or automate it: pub.dev → package admin → **Automated publishing** → GitHub Actions on the mirror
repository, tag pattern `v{{version}}`.

## Development-only settings (never in the published plugin)

- `mavenLocal()` lives only in `example/android/build.gradle.kts`. The plugin's own
  `android/build.gradle` uses `google()` and `mavenCentral()`.
- `android/build.gradle` stays Groovy with the classic Kotlin plugin setup (applied only when the
  host has no built-in Kotlin) so Flutter 3.22+ / AGP 8 hosts keep building. Migrate to built-in
  Kotlin only together with raising `environment.flutter` to `>=3.44.0`.
- `pod 'ZebChat', :path => '../../../ios'` lives only in `example/ios/Podfile` (it points at
  `sdks/ios` in the monorepo). Remove that line from the mirror's example once the pod is on
  trunk.
