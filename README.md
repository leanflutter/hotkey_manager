> **hotkey_manager is built on [nativeapi](https://github.com/libnativeapi/nativeapi)**, a
> Flutter binding of one C++ core library ([libnativeapi/nativeapi](https://github.com/libnativeapi/nativeapi))
> shared by macOS, Windows and Linux. Coming from 0.2.x? See [Upgrading from 0.2.x](#upgrading-from-02x).

> **Issues:** Please report bugs and feature requests in [nativeapi issues](https://github.com/libnativeapi/nativeapi/issues). Include the package name, version, operating system, and a minimal reproduction.

# hotkey_manager

[![pub version][pub-image]][pub-url] [![][discord-image]][discord-url] ![][visits-count-image] 

[pub-image]: https://img.shields.io/pub/v/hotkey_manager.svg
[pub-url]: https://pub.dev/packages/hotkey_manager

[discord-image]: https://img.shields.io/discord/884679008049037342.svg
[discord-url]: https://discord.gg/zPa6EZ2jqb

[visits-count-image]: https://img.shields.io/badge/dynamic/json?label=Visits%20Count&query=value&url=https://api.countapi.xyz/hit/leanflutter.hotkey_manager/visits

System-wide desktop shortcuts and in-app hardware-keyboard shortcuts for Flutter desktop and Android apps.

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
native hotkey_manager plugin or method channel is needed.

Requires Dart 3.13+, Flutter 3.47+ and **nativeapi/cnativeapi 0.5.6+** with asynchronous desktop shortcut registration.
Both dependencies are published on pub.dev; no local dependency overrides are needed.

```dart
import 'package:hotkey_manager/native.dart' as hotkey;

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
`GlobalShortcuts` and `CallbackGlobalShortcuts` remain available from the original
`package:hotkey_manager/hotkey_manager.dart` import, and from `package:hotkey_manager/legacy.dart`. Old hotkey JSON is supported.
Ordinary in-app shortcuts use Flutter's `HardwareKeyboard`; macOS media keys
use nativeapi. Both support down and up events. System key-up events are available on macOS and
Wayland Portal providers that send release notifications; Windows and X11 report
system key-down only. Fn is supported on macOS;
CapsLock is supported on macOS and X11. Windows retains the old behavior of
ignoring Fn/CapsLock, and Linux ignores Fn. Unmapped system keys throw
`PlatformException`. The original platform keycodes preserve media, international
and keypad keys, and Windows system shortcuts retain native automatic repetition.
Linux uses X11 (including XWayland) or the GlobalShortcuts Portal on native
Wayland. An explicitly X11 GTK application retains the X11 path.

On Wayland, `await hotKeyManager.register(...)` waits for the desktop's result
without blocking Flutter. Unregistering a pending hotkey, disposing its global
shortcut widget, or calling `unregisterAll()` cancels its request. The desktop
controls approval and the final binding: your combination is a preference and
may be changed, ignored or left unassigned. Some desktops, including Hyprland,
require assigning the advertised action in the compositor's configuration.
The `HotKey` model retains your requested combination. Native callers can read
`Shortcut.triggerDescription` for the current desktop label (empty or absent if unassigned).
Shared combinations have stable registration keys even when HotKey UUIDs change.
Unregistering releases the live session; it does not erase saved desktop choices.
The Hyprland Portal backend may retain the advertised action in its catalog after
the client session closes; this is separate from an active SDK registration.

The original injectable `HotKeyManagerPlatform` and `MethodChannelHotKeyManager`
interfaces are retained; the default implementation uses nativeapi. The native
shortcut types are exported separately from `package:hotkey_manager/native.dart`
to avoid collisions with Flutter’s `ShortcutManager`.

Repeated registration of the same identifier retains any omitted handlers.
`registeredHotKeyList` remains a live list. Different identifiers with the same combination share one native registration and each
receive events. `hotKeyManager.unregisterAll()` clears this package's shortcuts,
including leftovers after a hot restart, while preserving shortcuts registered
directly through `ShortcutManager`.

### Input focus, modifiers and registration errors

In-app hotkeys observe Flutter key events without consuming text input. Filter a
callback using the relevant `FocusNode.hasFocus` when it should be inactive while
typing. Use Flutter `Shortcuts`/`Actions` for shortcuts that should consume events
or follow focused-widget priority. Modifier-only in-app hotkeys are supported;
use `PhysicalKeyboardKey.shiftLeft` and `PhysicalKeyboardKey.shiftRight` for
independent bindings. Entries in `HotKey.modifiers` intentionally match either
side; a handler can inspect `HardwareKeyboard.instance.physicalKeysPressed` if
it needs to distinguish the side of a modifier in a chord.

`HotKeyScope.system` works regardless of which application is focused. To reserve
a shortcut only in the background, register it when your application becomes
inactive/hidden and unregister it when it becomes active/visible again. This is
an application lifecycle policy rather than another hotkey scope.

Always await registration and handle `PlatformException`: reserved or already
owned combinations fail without replacing another application's shortcut.
Unmodified keys such as Space are subject to the operating system's rules.
Unmapped system keys report `unsupported_hotkey`; supported macOS media keys
follow the permission rules above. System-reserved combinations
(such as the task switcher or Spotlight) must first be disabled or reassigned in
the operating system; this package does not override those reservations.

## Platform Support

| Linux | macOS | Windows | Android |
| :---: | :---: | :-----: | :-----: |
| ✔️ | ✔️ | ✔️ | In-app only |

## Quick Start

### Installation

Add the published package to your `pubspec.yaml`:

```yaml
dependencies:
  hotkey_manager: ^0.3.0
```

#### Upgrading from 0.2.x

Keep importing `package:hotkey_manager/hotkey_manager.dart`: the existing HotKey
models, methods, widgets and JSON remain compatible. Version 0.3.0 requires
Dart 3.13+, Flutter 3.47+ and uses the published nativeapi 0.5.6+ dependency.

#### Linux requirements

Native Wayland additionally requires a running desktop session with a working
`org.freedesktop.portal.GlobalShortcuts` provider. The generic portal package
alone is insufficient. Unsandboxed applications must install a `.desktop` file
whose basename matches their GTK application ID; sandboxed applications use the
identity supplied by their runtime. Unsupported providers, denied permission or
invalid application identity produce a `PlatformException`.

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
  // System key-up: macOS and Wayland providers with release notifications; in-app supports key-up.
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

| Method        | Description                               | Linux | macOS | Windows | Android |
| ------------- | ----------------------------------------- | ----- | ----- | ------- | ------- |
| register      | Register a system/in-app hotkey.           | ✔️    | ✔️    | ✔️      | In-app |
| unregister    | Unregister a hotkey.                       | ✔️    | ✔️    | ✔️      | ✔️ |
| unregisterAll | Unregister all owned hotkeys.              | ✔️    | ✔️    | ✔️      | ✔️ |

### macOS media keys

`PhysicalKeyboardKey.mediaPlayPause` and its logical-key equivalent work with
both `HotKeyScope.system` and `HotKeyScope.inapp`. Track next/previous, brightness
and eject keys use macOS auxiliary-control events. In-app volume keys use the
same AppKit transport; existing global volume shortcuts retain their Carbon
keycodes and permission requirements. App-scope media callbacks use AppKit and do not need global
input access. Native down/up callbacks preserve shared registrations and cleanup.

System media shortcuts require macOS to authorize a Quartz event tap. The app's
privacy permissions and sandbox configuration can restrict this API; failed
registration reports `PlatformException` rather than terminating the app.
Grant the app the required access in System Settings → Privacy & Security.
If access is revoked, affected native global registrations are removed and can
be registered again after access is restored. Ordinary Carbon shortcuts do not
need this media tap.

### Android and Chromebooks

Use `HotKeyScope.inapp` with a hardware keyboard. Callbacks run while your Flutter
application receives keyboard input, including key-up after modifiers are released.
The recorder and virtual-key widgets use the same API as desktop. The Android
example selects in-app scope automatically.

```dart
final save = HotKey(
  key: PhysicalKeyboardKey.keyS,
  modifiers: [HotKeyModifier.control],
  scope: HotKeyScope.inapp,
);
await hotKeyManager.register(save, keyDownHandler: (_) => saveDocument());
```

`HotKeyScope.system` reports `PlatformException(code: 'unsupported_hotkey')` on
Android; nativeapi does not provide system-wide Android registration. Software IME
text entry does not necessarily produce physical keyboard events. ChromeOS may
reserve its own combinations before they reach an Android application; see
[Android's ChromeOS input guidance](https://developer.android.com/develop/devices/chromeos/learn/input-compatibility).
Automated Android coverage uses a real Android emulator and dispatches native
`KeyEvent`s directly to the example Activity, through Flutter's Android embedding.
Physical Chromebook hardware and ChromeOS-reserved shortcuts require device testing.

## Related Links

- [nativeapi](https://github.com/libnativeapi/nativeapi)
- [nativeapi C++ core](https://github.com/libnativeapi/nativeapi-core)

## License

[MIT](./LICENSE)
