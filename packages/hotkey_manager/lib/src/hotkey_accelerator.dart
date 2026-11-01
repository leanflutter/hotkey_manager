import 'package:flutter/services.dart';
import 'package:hotkey_manager/src/hotkey.dart';
import 'package:uni_platform/uni_platform.dart';

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
  final keyboardKey = hotKey.key;
  final key = keyboardKey is PhysicalKeyboardKey
      ? keyboardKey
      : keyboardKey is LogicalKeyboardKey
      ? keyboardKey.physicalKey
      : null;
  if (key == null) {
    throw PlatformException(
      code: 'invalid_keyboard_key',
      message: 'No physical key is available.',
    );
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
