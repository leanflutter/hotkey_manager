# hotkey_manager example

Run `flutter pub get`, then `flutter run -d macos`, `windows` or `linux`.
The nativeapi dependencies resolve from pub.dev without local overrides.

The opening page registers **Ctrl + Alt + H** through `ShortcutManager`, counts
activation and release events, and unregisters the shortcut on disposal.
Release events are available on macOS. The compatibility example demonstrates
`HotKeyManager`, recording, rendering, and Flutter global shortcut widgets.

The web build remains supported for applications that also use the package for
in-app shortcuts; system registration is disabled on the opening page.

Run `flutter analyze` and `flutter test` from the package directory (`..`).
macOS runs all native registration tests. On Windows, set
`HOTKEY_MANAGER_NATIVE_TESTS=1` in a logged-on desktop session to include them;
service sessions cannot register global shortcuts. Linux native tests need X11
or XWayland; `xvfb-run -a flutter test` also runs them on an isolated display.
The tests pump native dispatch where Flutter's headless test runner has no
GTK/Win32 application loop. They do not send mouse or keyboard input.
