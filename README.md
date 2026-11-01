> **🚀 Ship Your App Faster**: Try [Fastforge](https://fastforge.dev) - The simplest way to build, package and distribute your Flutter apps.

# hotkey_manager

[![pub version][pub-image]][pub-url] [![][discord-image]][discord-url] ![][visits-count-image] 

[pub-image]: https://img.shields.io/pub/v/hotkey_manager.svg
[pub-url]: https://pub.dev/packages/hotkey_manager

[discord-image]: https://img.shields.io/discord/884679008049037342.svg
[discord-url]: https://discord.gg/zPa6EZ2jqb

[visits-count-image]: https://img.shields.io/badge/dynamic/json?label=Visits%20Count&query=value&url=https://api.countapi.xyz/hit/leanflutter.hotkey_manager/visits

This plugin allows Flutter desktop apps to defines system/inapp wide hotkey (i.e. shortcut).

---

English | [简体中文](./README-ZH.md)

---

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [hotkey_manager](#hotkey_manager)
  - [Platform Support](#platform-support)
  - [Quick Start](#quick-start)
    - [Installation](#installation)
      - [Linux requirements](#linux-requirements)
    - [Usage](#usage)
  - [Who's using it?](#whos-using-it)
  - [API](#api)
    - [HotKeyManager](#hotkeymanager)
  - [Related Links](#related-links)
  - [License](#license)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Native API

System shortcuts use the C++ nativeapi core through Dart FFI. No per-platform
hotkey_manager plugin or method channel is needed.

Requires Dart 3.13+, Flutter 3.47+ and **nativeapi 0.5.3+**, including
`ShortcutReleasedEvent`. The nativeapi packages resolve from pub.dev; no local
dependency overrides are needed.

```dart
import 'package:hotkey_manager/hotkey_manager.dart' as hotkey;

final manager = hotkey.ShortcutManager.instance;
final listenerId = manager.addListener((event) {
  if (event is hotkey.ShortcutActivatedEvent) {
    print('Pressed: ${event.accelerator}');
  } else if (event is hotkey.ShortcutReleasedEvent) {
    print('Released: ${event.accelerator}'); // macOS
  }
});
final shortcut = manager.registerWithOptions(const hotkey.ShortcutOptions(
  accelerator: 'Ctrl+Alt+Q',
  description: 'Quick action',
  scope: hotkey.ShortcutScope.global,
  enabled: true,
));
if (shortcut == null) {
  throw StateError('Shortcut unavailable or unsupported');
}

// When the registration is no longer needed:
manager.unregisterWithId(shortcut.id);
shortcut.dispose();
manager.removeListener(listenerId);
```

Use `addListener` for Flutter callbacks: events are delivered asynchronously to
the registering Dart isolate. A shortcut handle must be unregistered before it
is disposed; disposing the handle alone does not remove the native registration.

The existing `HotKeyManager`, `HotKey`, `HotKeyRecorder`, `HotKeyVirtualView`,
`GlobalShortcuts` and `CallbackGlobalShortcuts` remain available from the same
import, and from `package:hotkey_manager/legacy.dart`. Old hotkey JSON is supported.
In-app shortcuts continue to use Flutter's `HardwareKeyboard`, with down and up
events on all Flutter platforms. System key-up events are available on macOS;
Windows and Linux report system key-down only. Fn and CapsLock system modifiers
are supported on macOS; unsupported keys/modifiers throw `PlatformException`.
Linux system shortcuts require X11 (including XWayland), not native Wayland.

Repeated registration of the same identifier replaces its handlers. Different
identifiers with the same combination share one native registration and each
receive events. `hotKeyManager.unregisterAll()` clears this package's shortcuts,
including leftovers after a hot restart, while preserving shortcuts registered
directly through `ShortcutManager`.

## Platform Support

| Linux | macOS | Windows |
| :---: | :---: | :-----: |
|   ✔️   |   ✔️   |    ✔️    |

## Quick Start

### Installation

Use the Git dependency for the nativeapi migration described here:

```yaml
dependencies:
  hotkey_manager:
    git:
      path: packages/hotkey_manager
      url: https://github.com/leanflutter/hotkey_manager.git
      ref: main
```

#### Linux requirements

```bash
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev libx11-dev libxi-dev
```

### Usage

```dart
import 'package:hotkey_manager/hotkey_manager.dart';

void main() async {
  // Must add this line.
  WidgetsFlutterBinding.ensureInitialized();
  // Reclaim native registrations left over after a hot restart.
  await hotKeyManager.unregisterAll();

  runApp(MyApp());
}
```

Register/Unregsiter a system/inapp wide hotkey.

```dart
// ⌥ + Q
HotKey _hotKey = HotKey(
  key: PhysicalKeyboardKey.keyQ,
  modifiers: [HotKeyModifier.alt],
  // Set hotkey scope (default is HotKeyScope.system)
  scope: HotKeyScope.inapp, // Set as inapp-wide hotkey.
);
await hotKeyManager.register(
  _hotKey,
  keyDownHandler: (hotKey) {
    print('onKeyDown+${hotKey.toJson()}');
  },
  // System key-up is macOS only; in-app key-up works on all platforms.
  keyUpHandler: (hotKey){
    print('onKeyUp+${hotKey.toJson()}');
  } ,
);

await hotKeyManager.unregister(_hotKey);

await hotKeyManager.unregisterAll();
```

Use `HotKeyRecorder` widget to help you record a hotkey.

```dart
HotKeyRecorder(
  onHotKeyRecorded: (hotKey) {
    _hotKey = hotKey;
    setState(() {});
  },
),
```

> Please see the example app of this plugin for a full example.

## Who's using it?

- [Airclap](https://airclap.app/) - Send any file to any device. cross platform, ultra fast and easy to use.
- [AuthPass](https://authpass.app/) - Password Manager based on Flutter for all platforms. Keepass 2.x (kdbx 3.x) compatible.
- [Biyi (比译)](https://biyidev.com/) - A convenient translation and dictionary app.

## API

### HotKeyManager

| Method        | Description                               | Linux | macOS | Windows |
| ------------- | ----------------------------------------- | ----- | ----- | ------- |
| register      | register an system/inapp wide hotkey.     | ✔️     | ✔️     | ✔️       |
| unregister    | unregister an system/inapp wide hotkey.   | ✔️     | ✔️     | ✔️       |
| unregisterAll | unregister all system/inapp wide hotkeys. | ✔️     | ✔️     | ✔️       |

## Related Links

- [nativeapi](https://github.com/libnativeapi/nativeapi)
- [nativeapi C++ core](https://github.com/libnativeapi/nativeapi-core)

## License

[MIT](./LICENSE)
