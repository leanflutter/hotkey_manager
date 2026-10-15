## Unreleased

- Migrate system shortcuts to nativeapi 0.5.3 through Dart FFI; remove the Linux,
  macOS, Windows and platform-interface packages from this repository.
- Export the native Shortcut API while preserving the existing HotKey API,
  Flutter widgets and old JSON format. Add a `legacy.dart` entry point.
- Preserve macOS system key-up events through `ShortcutReleasedEvent`.
- Share native registrations for matching combinations; replace handlers by
  identifier, roll back failed registrations, ignore stale events and reclaim
  this package's registrations after a hot restart.
- Fix in-app release tracking, including multiple matching handlers and
  releasing modifiers before the primary key.
- Report unmapped keyboard keys as platform errors and reclaim the native
  example's shortcut after a hot restart.
- Bundle nativeapi's native assets in the Linux example and cover native
  registrations on Windows and Linux as well as macOS.
- Requires Dart 3.13+, Flutter 3.47+ and nativeapi 0.5.3+.

## 0.2.3

* bug fix that multi eventHandler does not fire (#53)

## 0.2.2

* feat: Add `CallbackGlobalShortcuts` and `GlobalShortcuts` Widgets.

## 0.2.1

* Fixed issue where modifiers do not work #50

## 0.2.0

* feat: Convert to federated plugin
* feat: Use flutter built-in keymap (provided through the `uni_platform` package)
* chore: Use `HardwareKeyboard` to replace the `RawKeyboard` api
* bump flutter to 3.19.2
* fix: crash if toString called with null modifiers (#25)
* Update dependencies & add three keys (#28)

## 0.1.7

* Fixed inapp hotkeys key down event repeat triggering #9
* Fixed inapp hotkeys not matching correctly #11

## 0.1.6

* Fixed `KeyModifierParser.fromModifierKey` Return type.

## 0.1.5

* [windows] Fix escape key mapping error
* [linux] Supplemental key map

## 0.1.4

* export `hotKeyManager`.

## 0.1.3

* `HotKeyVirtualView` Support dark Theme Mode.

## 0.1.2

* Remove web platform implementation

## 0.1.1

* Add `unregisterAll` Method.

## 0.1.0

* Supported Hot Reload.
* #2 Fixed `No element` error.

## 0.0.6

* [linux] Add #include <string> to hotkey_manager_plugin.cc

## 0.0.5

* Supported `linux` platform.

## 0.0.4

* Supported `web` platform, Embed via iframe.
* Adapt flutter master channel.

## 0.0.3

* Supported `windows` platform.

## 0.0.2

* Supported inapp-wide hotkey.
* Add `HotKeyVirtualView`, `HotKeyRecorder` Widgets.

## 0.0.1

* first release.
