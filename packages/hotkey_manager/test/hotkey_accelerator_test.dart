import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:hotkey_manager/src/hotkey_accelerator.dart';
import 'package:uni_platform/uni_platform.dart';

void main() {
  late String system;
  setUp(() => system = UniPlatform.operatingSystem);
  tearDown(() => UniPlatform.operatingSystem = system);

  test('Android system scope reports the supported in-app alternative', () {
    UniPlatform.operatingSystem = 'android';
    expect(
      () => hotKeyAccelerator(HotKey(key: PhysicalKeyboardKey.keyK)),
      throwsA(
        isA<PlatformException>()
            .having((error) => error.code, 'code', 'unsupported_hotkey')
            .having(
              (error) => error.message,
              'message',
              contains('HotKeyScope.inapp'),
            ),
      ),
    );
  });
  test('modifier order and duplicates normalize to one native accelerator', () {
    UniPlatform.operatingSystem = 'macos';
    final hotKey = HotKey(
      key: PhysicalKeyboardKey.keyQ,
      modifiers: [
        HotKeyModifier.shift,
        HotKeyModifier.alt,
        HotKeyModifier.shift,
      ],
    );
    expect(hotKeyAccelerator(hotKey), 'Alt+Shift+NativeKey12');
  });
  test(
    'legacy native keycodes retain keypad, international and media keys',
    () {
      final mappings = <String, Map<PhysicalKeyboardKey, int>>{
        'macos': {
          PhysicalKeyboardKey.keyA: 0,
          PhysicalKeyboardKey.numpadEqual: 81,
          PhysicalKeyboardKey.numLock: 71,
          PhysicalKeyboardKey.intlBackslash: 10,
          PhysicalKeyboardKey.audioVolumeUp: 72,
          PhysicalKeyboardKey.audioVolumeDown: 73,
          PhysicalKeyboardKey.audioVolumeMute: 74,
          PhysicalKeyboardKey.numpad0: 82,
          PhysicalKeyboardKey.digit0: 29,
        },
        'windows': {
          PhysicalKeyboardKey.audioVolumeUp: 175,
          PhysicalKeyboardKey.audioVolumeDown: 174,
          PhysicalKeyboardKey.audioVolumeMute: 173,
          PhysicalKeyboardKey.mediaPlayPause: 179,
          PhysicalKeyboardKey.printScreen: 44,
          PhysicalKeyboardKey.pause: 19,
          PhysicalKeyboardKey.contextMenu: 93,
          PhysicalKeyboardKey.browserBack: 166,
          PhysicalKeyboardKey.numLock: 144,
          PhysicalKeyboardKey.numpadEqual: 146,
          PhysicalKeyboardKey.f24: 135,
        },
        'linux': {
          PhysicalKeyboardKey.audioVolumeUp: 0x1008ff13,
          PhysicalKeyboardKey.audioVolumeDown: 0x1008ff11,
          PhysicalKeyboardKey.numpadEqual: 0xffbd,
          PhysicalKeyboardKey.numLock: 0xff7f,
        },
      };
      for (final platform in mappings.entries) {
        UniPlatform.operatingSystem = platform.key;
        for (final key in platform.value.entries) {
          expect(
            hotKeyAccelerator(HotKey(key: key.key)),
            'NativeKey${key.value}',
            reason: '${platform.key}: ${key.key.debugName}',
          );
        }
      }
    },
  );
  test('legacy platform-specific modifier handling is retained', () {
    final key = HotKey(
      key: PhysicalKeyboardKey.keyQ,
      modifiers: HotKeyModifier.values,
    );
    UniPlatform.operatingSystem = 'macos';
    expect(
      hotKeyAccelerator(key),
      'Alt+CapsLock+Ctrl+Fn+Meta+Shift+NativeKey12',
    );
    UniPlatform.operatingSystem = 'windows';
    expect(hotKeyAccelerator(key), 'Alt+Ctrl+Meta+Shift+NativeKey81');
    UniPlatform.operatingSystem = 'linux';
    expect(hotKeyAccelerator(key), 'Alt+CapsLock+Ctrl+Meta+Shift+NativeKey113');
  });
  test(
    'unmapped keys fail explicitly instead of narrowing a fallback keycode',
    () {
      expect(
        () => hotKeyAccelerator(HotKey(key: const PhysicalKeyboardKey(0xffff))),
        throwsA(isA<PlatformException>()),
      );
      UniPlatform.operatingSystem = 'macos';
      expect(
        () => hotKeyAccelerator(HotKey(key: LogicalKeyboardKey.hyper)),
        throwsA(isA<PlatformException>()),
      );
    },
  );
}
