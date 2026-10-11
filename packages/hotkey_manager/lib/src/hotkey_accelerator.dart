import 'package:flutter/services.dart';
import 'package:hotkey_manager/src/hotkey.dart';

/// Converts physical keys to the tokens accepted by nativeapi's platform
/// parsers. In particular, keypad keys must not collapse into the digit row.
String hotKeyAccelerator(HotKey hotKey) {
  final modifiers = <String>{};
  for (final modifier in HotKeyModifier.values.where(
    (modifier) => hotKey.modifiers?.contains(modifier) ?? false,
  )) {
    modifiers.add(switch (modifier) {
      HotKeyModifier.alt => 'Alt',
      HotKeyModifier.control => 'Ctrl',
      HotKeyModifier.meta => 'Meta',
      HotKeyModifier.shift => 'Shift',
      HotKeyModifier.capsLock => 'CapsLock',
      HotKeyModifier.fn => 'Fn',
    });
  }
  final key = hotKey.physicalKey;
  final usage = key.usbHidUsage;
  String? token = _keyTokens[key];
  if (usage >= PhysicalKeyboardKey.keyA.usbHidUsage &&
      usage <= PhysicalKeyboardKey.keyZ.usbHidUsage) {
    token = String.fromCharCode(
      65 + usage - PhysicalKeyboardKey.keyA.usbHidUsage,
    );
  } else if (usage >= PhysicalKeyboardKey.digit1.usbHidUsage &&
      usage <= PhysicalKeyboardKey.digit9.usbHidUsage) {
    token = '${1 + usage - PhysicalKeyboardKey.digit1.usbHidUsage}';
  } else if (usage >= PhysicalKeyboardKey.f1.usbHidUsage &&
      usage <= PhysicalKeyboardKey.f12.usbHidUsage) {
    token = 'F${1 + usage - PhysicalKeyboardKey.f1.usbHidUsage}';
  } else if (usage >= PhysicalKeyboardKey.f13.usbHidUsage &&
      usage <= PhysicalKeyboardKey.f24.usbHidUsage) {
    token = 'F${13 + usage - PhysicalKeyboardKey.f13.usbHidUsage}';
  } else if (usage >= PhysicalKeyboardKey.numpad1.usbHidUsage &&
      usage <= PhysicalKeyboardKey.numpad9.usbHidUsage) {
    token = 'Num${1 + usage - PhysicalKeyboardKey.numpad1.usbHidUsage}';
  }
  if (token == null) {
    throw PlatformException(
      code: 'unsupported_hotkey',
      message: 'nativeapi does not support the system key ${key.debugName}.',
    );
  }
  return [...modifiers, token].join('+');
}

final _keyTokens = <PhysicalKeyboardKey, String>{
  PhysicalKeyboardKey.digit0: '0',
  PhysicalKeyboardKey.enter: 'Enter',
  PhysicalKeyboardKey.escape: 'Escape',
  PhysicalKeyboardKey.backspace: 'Backspace',
  PhysicalKeyboardKey.tab: 'Tab',
  PhysicalKeyboardKey.space: 'Space',
  PhysicalKeyboardKey.minus: 'Minus',
  PhysicalKeyboardKey.equal: 'Equal',
  PhysicalKeyboardKey.bracketLeft: 'LeftBracket',
  PhysicalKeyboardKey.bracketRight: 'RightBracket',
  PhysicalKeyboardKey.backslash: 'Backslash',
  PhysicalKeyboardKey.semicolon: 'Semicolon',
  PhysicalKeyboardKey.quote: 'Quote',
  PhysicalKeyboardKey.backquote: 'Grave',
  PhysicalKeyboardKey.comma: 'Comma',
  PhysicalKeyboardKey.period: 'Period',
  PhysicalKeyboardKey.slash: 'Slash',
  PhysicalKeyboardKey.insert: 'Insert',
  PhysicalKeyboardKey.home: 'Home',
  PhysicalKeyboardKey.pageUp: 'PageUp',
  PhysicalKeyboardKey.delete: 'Delete',
  PhysicalKeyboardKey.end: 'End',
  PhysicalKeyboardKey.pageDown: 'PageDown',
  PhysicalKeyboardKey.arrowRight: 'Right',
  PhysicalKeyboardKey.arrowLeft: 'Left',
  PhysicalKeyboardKey.arrowDown: 'Down',
  PhysicalKeyboardKey.arrowUp: 'Up',
  PhysicalKeyboardKey.numpad0: 'Num0',
  PhysicalKeyboardKey.numpadDecimal: 'NumDec',
  PhysicalKeyboardKey.numpadAdd: 'NumAdd',
  PhysicalKeyboardKey.numpadSubtract: 'NumSub',
  PhysicalKeyboardKey.numpadMultiply: 'NumMult',
  PhysicalKeyboardKey.numpadDivide: 'NumDiv',
  PhysicalKeyboardKey.numpadEnter: 'NumEnter',
};
