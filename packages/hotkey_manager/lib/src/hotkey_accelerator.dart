import 'package:flutter/services.dart';
import 'package:hotkey_manager/src/hotkey.dart';
import 'package:uni_platform/uni_platform.dart';

// macOS auxiliary-control events have a separate code space from Carbon keys.
final _macMediaKeys = <PhysicalKeyboardKey, (int, String)>{
  PhysicalKeyboardKey.mediaPlayPause: (16, 'MediaPlayPause'),
  PhysicalKeyboardKey.mediaTrackNext: (17, 'MediaNextTrack'),
  PhysicalKeyboardKey.mediaTrackPrevious: (18, 'MediaPreviousTrack'),
  PhysicalKeyboardKey.mediaFastForward: (19, 'MediaFastForward'),
  PhysicalKeyboardKey.mediaRewind: (20, 'MediaRewind'),
  PhysicalKeyboardKey.audioVolumeUp: (0, 'VolumeUp'),
  PhysicalKeyboardKey.audioVolumeDown: (1, 'VolumeDown'),
  PhysicalKeyboardKey.audioVolumeMute: (7, 'VolumeMute'),
  PhysicalKeyboardKey.brightnessUp: (2, 'BrightnessUp'),
  PhysicalKeyboardKey.brightnessDown: (3, 'BrightnessDown'),
  PhysicalKeyboardKey.eject: (14, 'Eject'),
};

PhysicalKeyboardKey? _physicalKey(HotKey hotKey) {
  final key = hotKey.key;
  return key is PhysicalKeyboardKey
      ? key
      : key is LogicalKeyboardKey
      ? key.physicalKey
      : null;
}

/// AppKit media events do not enter Flutter's HardwareKeyboard dispatcher.
bool usesNativeHotKeyEvents(HotKey hotKey) =>
    hotKey.scope == HotKeyScope.system ||
    (UniPlatform.isMacOS && _macMediaKeys.containsKey(_physicalKey(hotKey)));

/// Retains the original platform keycodes, including media and international
/// keys that do not have portable nativeapi accelerator names.
String hotKeyAccelerator(HotKey hotKey) {
  if (UniPlatform.isAndroid) {
    throw PlatformException(
      code: 'unsupported_hotkey',
      message:
          'Android supports HotKeyScope.inapp hardware-keyboard shortcuts. '
          'System-wide registration is unavailable.',
    );
  }
  final modifiers = <String>{};
  for (final modifier in HotKeyModifier.values) {
    if (!(hotKey.modifiers?.contains(modifier) ?? false)) continue;
    // The old Windows adapter ignored CapsLock/Fn; Linux ignored Fn.
    if (UniPlatform.isWindows &&
        (modifier == HotKeyModifier.capsLock ||
            modifier == HotKeyModifier.fn)) {
      continue;
    }
    if (UniPlatform.isLinux && modifier == HotKeyModifier.fn) continue;
    modifiers.add(switch (modifier) {
      HotKeyModifier.alt => 'Alt',
      HotKeyModifier.control => 'Ctrl',
      HotKeyModifier.meta => 'Meta',
      HotKeyModifier.shift => 'Shift',
      HotKeyModifier.capsLock => 'CapsLock',
      HotKeyModifier.fn => 'Fn',
    });
  }
  final key = _physicalKey(hotKey);
  if (key == null) {
    throw PlatformException(
      code: 'invalid_keyboard_key',
      message: 'No physical key is available.',
    );
  }
  if (UniPlatform.isMacOS) {
    final media = _macMediaKeys[key];
    // Preserve the original permission-free Carbon volume registrations.
    final legacyGlobalVolume =
        hotKey.scope == HotKeyScope.system &&
        (key == PhysicalKeyboardKey.audioVolumeUp ||
            key == PhysicalKeyboardKey.audioVolumeDown ||
            key == PhysicalKeyboardKey.audioVolumeMute);
    if (media != null && !legacyGlobalVolume) {
      // Distinct native aliases let one physical chord serve global and app
      // scopes concurrently; the manager's accelerator identity stays unique.
      final token = hotKey.scope == HotKeyScope.inapp
          ? 'NativeMediaKey${media.$1}'
          : media.$2;
      return [...modifiers, token].join('+');
    }
  }
  final code = key.keyCode;
  final maximum = UniPlatform.isMacOS
      ? 0x7f
      : UniPlatform.isWindows
      ? 0xff
      : 0x7fffffff;
  if (code == null ||
      code < 0 ||
      code > maximum ||
      (!UniPlatform.isMacOS && code == 0)) {
    throw PlatformException(
      code: 'unsupported_hotkey',
      message: 'No native system keycode is available for ${key.debugName}.',
    );
  }
  return [...modifiers, 'NativeKey$code'].join('+');
}
