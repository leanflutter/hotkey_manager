import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cnativeapi/cnativeapi.dart' as native_loop;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide ShortcutManager;
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:hotkey_manager/native.dart';
import 'package:hotkey_manager/src/system_hotkey_backend.dart';

import 'support/carbon_hotkeys.dart';
import 'support/x11_keys.dart';

import 'package:hotkey_manager/src/hotkey_accelerator.dart';

String _legacyAccelerator(String portable) => hotKeyAccelerator(
  HotKey(
    key: portable.endsWith('F9')
        ? PhysicalKeyboardKey.f9
        : PhysicalKeyboardKey.f10,
    modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
  ),
);

class _AuditIntent extends Intent {
  const _AuditIntent();
}

class _AuditAction extends Action<_AuditIntent> {
  _AuditAction(this.callback, {required this.enabled});
  final VoidCallback callback;
  final bool enabled;
  @override
  bool isEnabled(_AuditIntent intent) => enabled;
  @override
  Object? invoke(_AuditIntent intent) {
    callback();
    return null;
  }
}

// Windows native tests need a logged-on desktop, unlike service/SSH session 0.
// Linux native registration needs a reachable X11 display, including XWayland.
final _supportsNativeTests =
    Platform.isMacOS ||
    (Platform.isWindows &&
        Platform.environment['HOTKEY_MANAGER_NATIVE_TESTS'] == '1') ||
    (Platform.isLinux &&
        (Platform.environment['DISPLAY']?.isNotEmpty ?? false));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Timer? nativePump;
  setUpAll(() {
    NativeHotKeyManagerPlatform.registerWith();
    if (_supportsNativeTests && !Platform.isMacOS) {
      native_loop.cnativeapi_start_event_loop();
      // flutter_tester owns no GTK/Win32 application loop. Keep native async
      // registration-failure notifications moving even while a plain test is
      // awaiting its result (there is no widget frame to pump them).
      nativePump = Timer.periodic(const Duration(milliseconds: 10), (_) {
        native_loop.cnativeapi_pump_event_loop(0);
      });
    }
  });
  tearDownAll(() => nativePump?.cancel());
  // flutter_tester has no GTK/Win32 application loop. Process deferred native
  // dispatch before waiting for the async Dart listener to receive its payload.
  Future<void> deliverNativeEvents() async {
    for (var i = 0; i < 10; i++) {
      if (!Platform.isMacOS) native_loop.cnativeapi_pump_event_loop(0);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  testWidgets(
    'native backend registers, forwards events and cleans up only its shortcuts',
    (tester) async {
      final native = ShortcutManager.instance;
      final backend = NativeSystemHotKeyBackend();
      final events = <(int, bool)>[];
      backend.onKeyEvent = (id, down) => events.add((id, down));
      final unrelated = native.registerWithOptions(
        const ShortcutOptions(
          accelerator: 'Ctrl+Shift+F9',
          description: 'another package',
          scope: ShortcutScope.global,
          enabled: true,
        ),
      );
      expect(unrelated, isNotNull);
      try {
        final hotKey = HotKey(
          key: PhysicalKeyboardKey.f10,
          modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
        );
        final id = await backend.register(hotKey);
        final registered = native.getWithId(id);
        expect(registered?.accelerator, hotKeyAccelerator(hotKey));
        registered?.dispose();
        native.emitShortcutActivated(id, 'Ctrl+Shift+F10');
        await tester.runAsync(deliverNativeEvents);
        expect(events, [(id, true)]);
        backend.unregisterAll();
        expect(native.getWithId(id), isNull);
        final retained = native.getWithId(unrelated!.id);
        expect(retained, isNotNull);
        retained?.dispose();
        native.emitShortcutActivated(id, 'Ctrl+Shift+F10');
        await tester.runAsync(deliverNativeEvents);
        expect(events, hasLength(1));
      } finally {
        backend.unregisterAll();
        if (unrelated != null) {
          native.unregisterWithId(unrelated.id);
          unrelated.dispose();
        }
      }
    },
    skip: !_supportsNativeTests,
  );

  test(
    'hot restart cleanup reclaims tagged shortcuts from an earlier isolate',
    () {
      final native = ShortcutManager.instance;
      final stale = native.registerWithOptions(
        const ShortcutOptions(
          accelerator: 'Ctrl+Shift+F10',
          description: 'hotkey_manager:previous-isolate',
          scope: ShortcutScope.global,
          enabled: true,
        ),
      );
      expect(stale, isNotNull);
      try {
        NativeSystemHotKeyBackend().unregisterAll();
        expect(native.getWithId(stale!.id), isNull);
      } finally {
        if (stale != null) {
          native.unregisterWithId(stale.id);
          stale.dispose();
        }
      }
    },
    skip: !_supportsNativeTests,
  );
  testWidgets(
    'global widgets sharing a key survive updates and independent disposal',
    (tester) async {
      var first = 0;
      var second = 0;
      const activator = SingleActivator(
        LogicalKeyboardKey.f10,
        control: true,
        shift: true,
      );
      const updated = SingleActivator(
        LogicalKeyboardKey.f9,
        control: true,
        shift: true,
      );
      final native = ShortcutManager.instance;
      Widget widget({bool showFirst = true, bool changeSecond = false}) =>
          Column(
            children: [
              if (showFirst)
                CallbackGlobalShortcuts(
                  key: const ValueKey('first'),
                  bindings: {activator: () => first++},
                  child: const SizedBox(),
                ),
              CallbackGlobalShortcuts(
                key: const ValueKey('second'),
                bindings: {changeSecond ? updated : activator: () => second++},
                child: const SizedBox(),
              ),
            ],
          );
      Future<void> activate(String accelerator) async {
        accelerator = _legacyAccelerator(accelerator);
        final shortcut = native.getWithAccelerator(accelerator);
        expect(shortcut, isNotNull);
        native.emitShortcutActivated(shortcut!.id, accelerator);
        shortcut.dispose();
        await tester.runAsync(deliverNativeEvents);
      }

      await tester.pumpWidget(widget());
      await activate('Ctrl+Shift+F10');
      expect((first, second), (1, 1));
      await tester.pumpWidget(widget(showFirst: false));
      await activate('Ctrl+Shift+F10');
      expect((first, second), (1, 2));
      await tester.pumpWidget(widget(showFirst: false, changeSecond: true));
      expect(
        native.getWithAccelerator(_legacyAccelerator('Ctrl+Shift+F10')),
        isNull,
      );
      await activate('Ctrl+Shift+F9');
      expect((first, second), (1, 3));
      await tester.pumpWidget(const SizedBox());
      expect(
        native.getWithAccelerator(_legacyAccelerator('Ctrl+Shift+F9')),
        isNull,
      );
    },
    skip: !_supportsNativeTests,
  );

  testWidgets(
    'GlobalShortcuts dispatches Actions and respects disabled actions',
    (tester) async {
      var calls = 0;
      const activator = SingleActivator(
        LogicalKeyboardKey.f9,
        control: true,
        shift: true,
      );
      Widget widget(bool enabled) => Actions(
        actions: <Type, Action<Intent>>{
          _AuditIntent: _AuditAction(() => calls++, enabled: enabled),
        },
        child: const GlobalShortcuts(
          shortcuts: {activator: _AuditIntent()},
          child: SizedBox(),
        ),
      );
      final native = ShortcutManager.instance;
      Future<void> activate() async {
        final shortcut = native.getWithAccelerator(
          _legacyAccelerator('Ctrl+Shift+F9'),
        );
        expect(shortcut, isNotNull);
        try {
          native.emitShortcutActivated(shortcut!.id, 'Ctrl+Shift+F9');
          await tester.runAsync(deliverNativeEvents);
        } finally {
          shortcut?.dispose();
        }
      }

      await tester.pumpWidget(widget(true));
      await activate();
      expect(calls, 1);
      await tester.pumpWidget(widget(false));
      await activate();
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox());
      expect(
        native.getWithAccelerator(_legacyAccelerator('Ctrl+Shift+F9')),
        isNull,
      );
    },
    skip: !_supportsNativeTests,
  );

  test('failed legacy registration preserves a directly registered native shortcut', () async {
    final native = ShortcutManager.instance;
    final shortcut = native.registerWithOptions(
      const ShortcutOptions(
        accelerator: 'Ctrl+Shift+F9',
        description: 'another package',
        scope: ShortcutScope.global,
        enabled: true,
      ),
    );
    expect(shortcut, isNotNull);
    try {
      await expectLater(
        hotKeyManager.register(
          HotKey(
            key: PhysicalKeyboardKey.f9,
            modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
          ),
        ),
        throwsA(isA<PlatformException>()),
      );
      expect(hotKeyManager.registeredHotKeyList, isEmpty);
      final retained = native.getWithId(shortcut!.id);
      expect(retained, isNotNull);
      retained?.dispose();
    } finally {
      await hotKeyManager.unregisterAll();
      if (shortcut != null) {
        native.unregisterWithId(shortcut.id);
        shortcut.dispose();
      }
    }
  }, skip: !_supportsNativeTests);

  testWidgets('legacy special keys register, deliver events and unregister', (
    tester,
  ) async {
    final keys = Platform.isMacOS
        ? [
            PhysicalKeyboardKey.numpadEqual,
            PhysicalKeyboardKey.numLock,
            PhysicalKeyboardKey.intlBackslash,
            PhysicalKeyboardKey.audioVolumeUp,
            PhysicalKeyboardKey.audioVolumeDown,
            PhysicalKeyboardKey.audioVolumeMute,
          ]
        : Platform.isWindows
        ? [
            PhysicalKeyboardKey.audioVolumeUp,
            PhysicalKeyboardKey.audioVolumeDown,
            PhysicalKeyboardKey.audioVolumeMute,
            PhysicalKeyboardKey.mediaPlayPause,
            PhysicalKeyboardKey.printScreen,
            PhysicalKeyboardKey.pause,
            PhysicalKeyboardKey.contextMenu,
            PhysicalKeyboardKey.browserBack,
            PhysicalKeyboardKey.numLock,
            PhysicalKeyboardKey.numpadEqual,
          ]
        : [
            PhysicalKeyboardKey.numpadEqual,
            PhysicalKeyboardKey.numLock,
            PhysicalKeyboardKey.audioVolumeUp,
            PhysicalKeyboardKey.audioVolumeDown,
          ];
    var tested = 0;
    for (final key in keys) {
      final hotKey = HotKey(
        key: key,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
      );
      final accelerator = hotKeyAccelerator(hotKey);
      if (Platform.isLinux &&
          !x11HasKey(int.parse(accelerator.split('NativeKey').last))) {
        continue;
      }
      var downs = 0;
      var ups = 0;
      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (_) => downs++,
        keyUpHandler: (_) => ups++,
      );
      final native = ShortcutManager.instance;
      final shortcut = native.getWithAccelerator(accelerator);
      expect(shortcut, isNotNull, reason: key.debugName);
      try {
        if (Platform.isMacOS) {
          final carbon = CarbonHotKeys();
          expect(carbon.send(shortcut!.id, down: true), 0);
          expect(carbon.send(shortcut.id, down: false), 0);
        } else {
          native.emitShortcutActivated(shortcut!.id, accelerator);
        }
        await tester.runAsync(deliverNativeEvents);
        expect(downs, 1, reason: key.debugName);
        expect(ups, Platform.isMacOS ? 1 : 0, reason: key.debugName);
        await hotKeyManager.unregister(hotKey);
        expect(native.getWithId(shortcut.id), isNull);
        tested++;
      } finally {
        shortcut?.dispose();
        await hotKeyManager.unregisterAll();
      }
    }
    expect(tested, greaterThan(0));
  }, skip: !_supportsNativeTests);

  testWidgets('macOS Carbon down and release reach every legacy handler', (
    tester,
  ) async {
    final events = <String>[];
    final native = ShortcutManager.instance;
    for (final id in ['first', 'second']) {
      await hotKeyManager.register(
        HotKey(
          identifier: id,
          key: PhysicalKeyboardKey.f10,
          modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
        ),
        keyDownHandler: (key) => events.add('${key.identifier}:down'),
        keyUpHandler: (key) => events.add('${key.identifier}:up'),
      );
    }
    final shortcut = native.getWithAccelerator(
      _legacyAccelerator('Ctrl+Shift+F10'),
    );
    expect(shortcut, isNotNull);
    try {
      final carbon = CarbonHotKeys();
      expect(carbon.send(shortcut!.id, down: true), 0);
      expect(carbon.send(shortcut.id, down: false), 0);
      await tester.runAsync(deliverNativeEvents);
      expect(events, ['first:down', 'second:down', 'first:up', 'second:up']);
    } finally {
      shortcut?.dispose();
      await hotKeyManager.unregisterAll();
    }
  }, skip: !Platform.isMacOS);

  test(
    'unmodified space and unsupported media keys fail recoverably',
    () async {
      for (final key in [
        PhysicalKeyboardKey.space,
        PhysicalKeyboardKey.mediaPlayPause,
      ]) {
        final hotKey = HotKey(key: key);
        try {
          await hotKeyManager.register(hotKey);
          expect(hotKeyManager.registeredHotKeyList, contains(hotKey));
        } on PlatformException catch (error) {
          // The OS can reserve bare keys; media keys without a native keycode
          // are unsupported. Neither case may abort the native process or
          // leave the serialized registration queue unusable.
          expect(error.code, anyOf('register_failed', 'unsupported_hotkey'));
          expect(hotKeyManager.registeredHotKeyList, isNot(contains(hotKey)));
        } finally {
          await hotKeyManager.unregister(hotKey);
        }
      }
      final recovery = HotKey(
        key: PhysicalKeyboardKey.f8,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
      );
      var calls = 0;
      await hotKeyManager.register(recovery, keyDownHandler: (_) => calls++);
      final native = ShortcutManager.instance;
      final shortcut = native.getWithAccelerator(hotKeyAccelerator(recovery));
      expect(shortcut, isNotNull);
      try {
        if (Platform.isMacOS) {
          expect(CarbonHotKeys().send(shortcut!.id, down: true), 0);
        } else {
          native.emitShortcutActivated(
            shortcut!.id,
            hotKeyAccelerator(recovery),
          );
        }
        await deliverNativeEvents();
        expect(calls, 1);
      } finally {
        shortcut?.dispose();
        await hotKeyManager.unregisterAll();
      }
    },
    skip: !_supportsNativeTests,
  );

  test(
    'Windows rejects an externally owned chord without stealing it',
    () async {
      final owner = await Process.start('python', [
        File('test/support/windows_grab.py').absolute.path,
      ]);
      final hotKey = HotKey(
        key: PhysicalKeyboardKey.f19,
        modifiers: [
          HotKeyModifier.control,
          HotKeyModifier.alt,
          HotKeyModifier.shift,
        ],
      );
      try {
        final line = await owner.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first
            .timeout(const Duration(seconds: 10));
        expect(jsonDecode(line)['registered'], isTrue);
        await expectLater(
          hotKeyManager.register(hotKey),
          throwsA(isA<PlatformException>()),
        );
        expect(hotKeyManager.registeredHotKeyList, isNot(contains(hotKey)));
      } finally {
        await owner.stdin.close();
        expect(await owner.exitCode.timeout(const Duration(seconds: 10)), 0);
      }
      try {
        await hotKeyManager.register(hotKey);
        expect(hotKeyManager.registeredHotKeyList, contains(hotKey));
      } finally {
        await hotKeyManager.unregister(hotKey);
      }
    },
    skip: !Platform.isWindows || !_supportsNativeTests,
  );
}
