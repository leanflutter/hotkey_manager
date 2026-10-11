import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide ShortcutManager;
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:hotkey_manager/src/system_hotkey_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native backend registers, forwards events and cleans up only its shortcuts',
    (tester) async {
      final native = ShortcutManager.instance;
      final backend = NativeSystemHotKeyBackend();
      final events = <(int, bool)>[];
      backend.onKeyEvent = (id, down) => events.add((id, down));
      final unrelated = native.registerWithOptions(
        const ShortcutOptions(
          accelerator: 'Ctrl+Shift+F18',
          description: 'another package',
          scope: ShortcutScope.global,
          enabled: true,
        ),
      );
      expect(unrelated, isNotNull);
      try {
        final hotKey = HotKey(
          key: PhysicalKeyboardKey.f19,
          modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
        );
        final id = backend.register(hotKey);
        final registered = native.getWithId(id);
        expect(registered?.accelerator, 'Ctrl+Shift+F19');
        registered?.dispose();
        native.emitShortcutActivated(id, 'Ctrl+Shift+F19');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        expect(events, [(id, true)]);
        backend.unregisterAll();
        expect(native.getWithId(id), isNull);
        final retained = native.getWithId(unrelated!.id);
        expect(retained, isNotNull);
        retained?.dispose();
        native.emitShortcutActivated(id, 'Ctrl+Shift+F19');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        expect(events, hasLength(1));
      } finally {
        backend.unregisterAll();
        if (unrelated != null) {
          native.unregisterWithId(unrelated.id);
          unrelated.dispose();
        }
      }
    },
    skip: !Platform.isMacOS,
  );

  test(
    'hot restart cleanup reclaims tagged shortcuts from an earlier isolate',
    () {
      final native = ShortcutManager.instance;
      final stale = native.registerWithOptions(
        const ShortcutOptions(
          accelerator: 'Ctrl+Shift+F19',
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
    skip: !Platform.isMacOS,
  );
  testWidgets(
    'global widgets sharing a key survive updates and independent disposal',
    (tester) async {
      var first = 0;
      var second = 0;
      const activator = SingleActivator(
        LogicalKeyboardKey.f19,
        control: true,
        shift: true,
      );
      const updated = SingleActivator(
        LogicalKeyboardKey.f18,
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
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
      }

      await tester.pumpWidget(widget());
      await activate('Ctrl+Shift+F19');
      expect((first, second), (1, 1));
      await tester.pumpWidget(widget(showFirst: false));
      await activate('Ctrl+Shift+F19');
      expect((first, second), (1, 2));
      await tester.pumpWidget(widget(showFirst: false, changeSecond: true));
      expect(native.getWithAccelerator('Ctrl+Shift+F19'), isNull);
      await activate('Ctrl+Shift+F18');
      expect((first, second), (1, 3));
      await tester.pumpWidget(const SizedBox());
      expect(native.getWithAccelerator('Ctrl+Shift+F18'), isNull);
    },
    skip: !Platform.isMacOS,
  );
}
