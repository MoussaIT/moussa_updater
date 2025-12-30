## 1.0.4
- Fixed Android GeneratedPluginRegistrant class-not-found issue
- Added/ensured Android v2 plugin entry class exists at the correct package path
- Resolved build error: cannot find symbol `com.moussa.updater.MoussaUpdaterPlugin`

## 1.0.3
- Fixed iOS plugin class name mismatch (case-sensitive)
- Aligned iOS `pluginClass` with actual Objective-C/Swift plugin class
- Resolved Xcode archive error: Unknown receiver 'MoussaUpdaterPlugin'

## 1.0.2
- Fixed Android plugin main class registration
- Corrected `pubspec.yaml` Android plugin configuration
- Aligned Android package name with plugin entry class
- Resolved build error: plugin doesn't have a main class defined

## 1.0.1
- Production-ready auto dialog support
- Platform-safe behavior
- Pub score fixes and formatting

## 1.0.0
- Initial production release
- Force update based on minimum app version
- Android In-App Updates (Immediate / Flexible)
- Play Store only enforcement (APK blocking)
- Safe no-op behavior on Web & Desktop
- Runtime platform guards
- Production-ready example app
