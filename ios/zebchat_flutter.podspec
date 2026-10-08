#
# Flutter plugin pod for package:zebchat_flutter. Wraps the native ZebChat iOS SDK (pod 'ZebChat').
# The pod is named after the Dart package (Flutter requires it), which also keeps its module
# `zebchat_flutter` apart from the SDK's `ZebChat` module on case-insensitive file systems.
# Run `pod lib lint zebchat_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'zebchat_flutter'
  s.version          = '1.0.0'
  s.summary          = 'ZebChat live chat for Flutter apps (iOS plugin).'
  s.description      = <<-DESC
Flutter plugin glue for the ZebChat iOS SDK: in-app chat, user identity, screen views,
unread count and push notifications.
                       DESC
  s.homepage         = 'https://www.zebchat.com'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'ZebChat' => 'hello@zebchat.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'ZebChat', '~> 1.0'
  s.platform         = :ios, '14.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.9'

  s.resource_bundles = { 'zebchat_flutter_privacy' => ['Resources/PrivacyInfo.xcprivacy'] }
end
