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

## Android hardware keyboards

Run the example with `flutter run -d <android-device>`. It opens the compatibility
page and records in-app shortcuts. Android system-wide registration is unavailable.

The AOT regression probe uses native Android `KeyEvent`s dispatched only to this
example Activity. Start an Android emulator, then run from this directory:

```sh
python3 test_support/run_android_keyboard_probe.py --serial emulator-5554
```

The script builds both the Release application and its matching instrumentation
APK, installs them, and requires a fresh structured passing result. The Java driver
uses Android's hardware input mode, waits for the example's keyboard focus, and
coordinates through its private code cache so R8 can optimize Flutter normally.
Results and build/runtime logs are in `build/compatibility_audit/android/`.
This verifies Android input translation; it does not inject OS keys or certify
physical Chromebook hardware or ChromeOS-reserved combinations.

## macOS media keys

```sh
python3 test_support/run_macos_media_probe.py
```

This builds the release bundle, then uses its actual AOT Flutter engine and
native asset in a console host without activating windows. The default run
requires a real global media registration as well as in-app callbacks. It sends
`NSEvent`s only to that process, and records native down/up delivery, sharing,
repeat handling, transport-key aliases and cleanup. No OS keys are injected.
Global tap access is controlled by macOS; CI can explicitly pass
`--allow-unavailable-global`, which records denial separately and still requires
in-app checks. Such a result does not certify global registration.
Logs and the structured report are in `build/compatibility_audit/macos-media/`.
