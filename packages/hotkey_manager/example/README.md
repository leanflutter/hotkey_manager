# hotkey_manager example

Run `flutter pub get`, then `flutter run -d macos`, `windows` or `linux`.
The nativeapi 0.5.3 dependency must be available; before publication, add local
`nativeapi` and `cnativeapi` overrides in both the package and this example.

The opening page registers **Ctrl + Alt + H** through `ShortcutManager`, counts
activation and release events, and unregisters the shortcut on disposal.
Release events are available on macOS. The compatibility example demonstrates
`HotKeyManager`, recording, rendering, and Flutter global shortcut widgets.

The web build remains supported for applications that also use the package for
in-app shortcuts; system registration is disabled on the opening page.
