# moussa_updater 🚀

A production-grade Flutter plugin for enforcing mandatory app updates
based on a minimum app version, with advanced Android support and
safe behavior on all platforms.

Built for real production apps, not demos.

---

## ✨ Features

### Platform support

Platform | Behavior
Android | Google Play In-App Updates (Immediate / Flexible)
iOS | Force update via App Store
Web | Safe no-op (notSupported)
Windows | Safe no-op
macOS | Safe no-op
Linux | Safe no-op

---

### Force update logic

- Enforce minimum app version
- Optional Play Store only enforcement (blocks APK installs)
- Blocks outdated or unofficial builds
- Fully controlled at runtime

---

## 📦 Installation

Add the dependency to your pubspec.yaml:

dependencies:
  moussa_updater: ^1.0.0

---

## 🚀 Usage (recommended in Splash / Startup)

It is recommended to call checkAndMaybeUpdate during app startup
(e.g. Splash screen) before allowing the user to continue.

Example:

final result = await MoussaUpater.checkAndMaybeUpdate(
  minVersion: '2.3.0',
  androidUpdateMode: AndroidUpdateMode.immediate,
  androidPackageId: 'com.example.app',
  iosAppId: '1234567890',
  playOnly: true,
);

if (result.action == MoussaAction.updateStarted) {
  // Android in-app update has started
  return;
}

if (result.action == MoussaAction.forceBlocked ||
    result.action == MoussaAction.openStore) {
  // Navigate to your force update screen
}

---

## 🔁 Android Update Modes

AndroidUpdateMode.immediate
Mandatory blocking update.

AndroidUpdateMode.flexible
Background download with manual installation.

Important:
Android In-App Updates only work when the app is installed from
Google Play (internal, closed, or production tracks).

---

## 🛡️ Play Store Only Enforcement

playOnly: true

When enabled, the plugin will block any non-Play Store installation
(APK or sideload), even if the version number is valid.

Scenarios:

- APK / sideload install → Blocked
- Google Play install → Allowed
- Below minimum version → Forced update

---

## 🧠 Returned Actions

Possible MoussaAction values:

- upToDate → app may continue normally
- updateStarted → Android in-app update flow started
- forceBlocked → user must update before continuing
- openStore → fallback to store page
- notSupported → Web / Desktop platforms (safe no-op)
- error → unexpected failure

---

## 🧩 Platform Safety

moussa_updater is designed to be safe in multi-platform Flutter projects.

- Automatically disables itself on unsupported platforms
- No crashes on Web, Windows, macOS, or Linux
- Gracefully handles missing native implementations
- Suitable for apps targeting mobile, desktop, and web

---

## 🧪 Testing

This plugin relies on native platform services
(Google Play Core and Apple App Store).

Automated Flutter unit or integration tests are not reliable
for this type of plugin.

Recommended testing approaches:

- Google Play Internal Testing
- TestFlight (iOS)
- Manual verification during release rollout

---

## 📄 License

MIT License © 2025 MoussaIT
Developed by Mostafa Azazy

See the LICENSE file for full details.

---

## 👨‍💻 Author

Mostafa Azazy
Principal Mobile Engineer
MoussaIT

---

## ⭐ Contributions

Contributions are welcome if they:

- Improve production stability
- Keep the API clean and minimal
- Avoid demo-only or experimental logic
