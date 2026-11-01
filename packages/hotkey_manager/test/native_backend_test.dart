import 'dart:io';

import 'package:cnativeapi/cnativeapi.dart' as native_loop;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide ShortcutManager;
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:hotkey_manager/src/system_hotkey_backend.dart';

import 'support/carbon_hotkeys.dart';

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
  setUpAll(() {
    if (_supportsNativeTests && !Platform.isMacOS) {
      native_loop.cnativeapi_start_event_loop();
    }
  });
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
        final id = backend.register(hotKey);
        final registered = native.getWithId(id);
        expect(registered?.accelerator, 'Ctrl+Shift+F10');
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
      expect(native.getWithAccelerator('Ctrl+Shift+F10'), isNull);
      await activate('Ctrl+Shift+F9');
      expect((first, second), (1, 3));
      await tester.pumpWidget(const SizedBox());
      expect(native.getWithAccelerator('Ctrl+Shift+F9'), isNull);
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
        final shortcut = native.getWithAccelerator('Ctrl+Shift+F9');
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
      expect(native.getWithAccelerator('Ctrl+Shift+F9'), isNull);
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
    final shortcut = native.getWithAccelerator('Ctrl+Shift+F10');
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
}
