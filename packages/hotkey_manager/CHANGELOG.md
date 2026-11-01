## 0.2.4

- Migrate desktop shortcuts to nativeapi 0.5.6 through Dart FFI and native assets; remove the platform native packages and Swift HotKey dependency.
- Preserve the published HotKey models, methods, JSON, platform-interface identity, widgets and injectable backend. Keep additional native shortcut types in `native.dart` and provide `legacy.dart`.
- Support native Wayland GlobalShortcuts Portal registration, desktop-selected bindings, stable shared action keys and cancellation on supported providers (#12, #21, PR #72).
- Support macOS Play/Pause and other media keys in system and application scope, including down/up delivery and permission-loss cleanup (#62). Preserve existing Carbon volume-key registrations.
- Add Android/Chromebook in-app hardware-keyboard support and an Android example (#14). System-wide Android shortcuts remain unavailable.
- Share matching native registrations; preserve omitted handlers, serialize cleanup, ignore stale callbacks and reclaim owned registrations after hot restart. Preserve desktop native keycodes and OS conflict failures.
- Fix standalone left/right application modifiers, modifier-first release and focus recovery; observe in-app keys without consuming editable text (#19, #20, #22, #29, #51, #54).
- Fix Shift/Alt recorder combinations and non-null recordings in release builds (#42, #61). Cover plugin registration, unmodified Space, native grab conflicts and real window hide/show recovery (#10, #63, #65).
- **Breaking:** requires Dart 3.13+, Flutter 3.47+ and nativeapi 0.5.6+.

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
