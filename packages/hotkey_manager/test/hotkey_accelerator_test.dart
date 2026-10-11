import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:hotkey_manager/src/hotkey_accelerator.dart';

void main() {
  test('modifier order and duplicates normalize to one accelerator', () {
    final hotKey = HotKey(
      key: PhysicalKeyboardKey.keyQ,
      modifiers: [
        HotKeyModifier.shift,
        HotKeyModifier.alt,
        HotKeyModifier.shift,
      ],
    );
    expect(hotKeyAccelerator(hotKey), 'Alt+Shift+Q');
  });
  test('physical positions, function keys and keypad keep distinct tokens', () {
    final keys = <KeyboardKey, String>{
      PhysicalKeyboardKey.keyZ: 'Z',
      PhysicalKeyboardKey.digit0: '0',
      PhysicalKeyboardKey.digit9: '9',
      PhysicalKeyboardKey.f12: 'F12',
      PhysicalKeyboardKey.f13: 'F13',
      PhysicalKeyboardKey.f24: 'F24',
      PhysicalKeyboardKey.numpad0: 'Num0',
      PhysicalKeyboardKey.numpad9: 'Num9',
      PhysicalKeyboardKey.numpadEnter: 'NumEnter',
      PhysicalKeyboardKey.numpadAdd: 'NumAdd',
      PhysicalKeyboardKey.comma: 'Comma',
      PhysicalKeyboardKey.equal: 'Equal',
      PhysicalKeyboardKey.backquote: 'Grave',
      PhysicalKeyboardKey.arrowLeft: 'Left',
      PhysicalKeyboardKey.delete: 'Delete',
      PhysicalKeyboardKey.enter: 'Enter',
      LogicalKeyboardKey.keyQ: 'Q',
    };
    for (final entry in keys.entries) {
      expect(hotKeyAccelerator(HotKey(key: entry.key)), entry.value);
    }
  });
  test('unsupported keys fail explicitly instead of using the wrong key', () {
    expect(
      () => hotKeyAccelerator(HotKey(key: PhysicalKeyboardKey.fn)),
      throwsA(isA<PlatformException>()),
    );
  });
}
