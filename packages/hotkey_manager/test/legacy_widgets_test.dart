// ignore_for_file: deprecated_member_use, deprecated_member_use_from_same_package

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart' as hotkey;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'dev.leanflutter.plugins/hotkey_manager',
      'dev.leanflutter.plugins/hotkey_manager_event',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
  });

  testWidgets(
    'recorder records Shift and Shift+Alt combinations without null',
    (tester) async {
      final recorded = <hotkey.HotKey>[];
      await tester.pumpWidget(
        MaterialApp(
          home: hotkey.HotKeyRecorder(onHotKeyRecorded: recorded.add),
        ),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
      expect(recorded.last.key, PhysicalKeyboardKey.keyA);
      expect(recorded.last.modifiers, [hotkey.HotKeyModifier.shift]);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyQ);
      expect(recorded.last.key, PhysicalKeyboardKey.keyQ);
      expect(recorded.last.modifiers, [
        hotkey.HotKeyModifier.alt,
        hotkey.HotKeyModifier.shift,
      ]);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyQ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'legacy enum parsers, labels and modifier conversions remain available',
    () {
      expect(hotkey.KeyCodeParser.parse('keyQ'), hotkey.KeyCode.keyQ);
      expect(hotkey.KeyCode.keyQ.logicalKey, LogicalKeyboardKey.keyQ);
      expect(hotkey.KeyCode.keyQ.stringValue, 'keyQ');
      expect(hotkey.KeyCode.keyQ.keyLabel, 'Q');
      expect(
        hotkey.KeyCodeParser.fromLogicalKey(LogicalKeyboardKey.keyQ),
        hotkey.KeyCode.keyQ,
      );
      for (final modifier in hotkey.KeyModifier.values) {
        expect(hotkey.KeyModifierParser.parse(modifier.stringValue), modifier);
        expect(
          hotkey.KeyModifierParser.fromModifierKey(modifier.modifierKey),
          modifier,
        );
        for (final key in modifier.logicalKeys) {
          expect(hotkey.KeyModifierParser.fromLogicalKey(key), modifier);
        }
        expect(modifier.keyLabel, isNotEmpty);
      }
    },
  );

  for (final scope in hotkey.HotKeyScope.values) {
    for (final key in <KeyboardKey>[
      PhysicalKeyboardKey.keyQ,
      LogicalKeyboardKey.keyQ,
    ]) {
      test(
        'JSON round-trip preserves $scope with ${key.runtimeType} and all modifiers',
        () {
          final original = hotkey.HotKey(
            identifier: 'round-trip',
            key: key,
            scope: scope,
            modifiers: hotkey.HotKeyModifier.values,
          );
          final restored = hotkey.HotKey.fromJson(original.toJson());
          expect(restored.identifier, original.identifier);
          expect(restored.key, original.key);
          expect(restored.scope, scope);
          expect(restored.modifiers, original.modifiers);
          expect(restored.logicalKey, LogicalKeyboardKey.keyQ);
          expect(restored.physicalKey, PhysicalKeyboardKey.keyQ);
          expect(restored.debugName, contains('Key Q'));
        },
      );
    }
  }

  test('JSON defaults preserve generated identifiers, default scope and nullable modifiers', () {
    final first = hotkey.HotKey.fromJson({
      'key': {'usageCode': PhysicalKeyboardKey.keyQ.usbHidUsage},
    });
    final second = hotkey.HotKey(key: PhysicalKeyboardKey.keyQ);
    expect(first.identifier, isNotEmpty);
    expect(first.identifier, isNot(second.identifier));
    expect(first.scope, hotkey.HotKeyScope.system);
    expect(first.modifiers, isNull);
    expect(first.toJson()['modifiers'], isNull);
    expect(hotkey.HotKey.fromJson(first.toJson()).toJson(), first.toJson());
  });

  testWidgets(
    'recorder retains the legacy initalHotKey spelling, identity and scope',
    (tester) async {
      final recorded = <hotkey.HotKey>[];
      final initial = hotkey.HotKey(
        identifier: 'recorded-id',
        key: PhysicalKeyboardKey.keyQ,
        modifiers: [hotkey.HotKeyModifier.control],
        scope: hotkey.HotKeyScope.inapp,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: hotkey.HotKeyRecorder(
            initalHotKey: initial,
            onHotKeyRecorded: recorded.add,
          ),
        ),
      );
      expect(find.text('Q'), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
      await tester.pump();
      final last = recorded.last;
      expect(last.identifier, initial.identifier);
      expect(last.scope, initial.scope);
      expect(last.key, PhysicalKeyboardKey.keyW);
      expect(last.modifiers, [hotkey.HotKeyModifier.control]);
      expect(find.text('W'), findsOneWidget);
      final count = recorded.length;
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(recorded, hasLength(count));
      await tester.pumpWidget(const SizedBox());
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      expect(recorded, hasLength(count));
    },
  );

  testWidgets(
    'recorder excludes its primary modifier key from the modifier list',
    (tester) async {
      hotkey.HotKey? recorded;
      await tester.pumpWidget(
        MaterialApp(
          home: hotkey.HotKeyRecorder(
            onHotKeyRecorded: (value) => recorded = value,
          ),
        ),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftRight);
      expect(recorded?.key, PhysicalKeyboardKey.shiftRight);
      expect(recorded?.modifiers, isEmpty);
      expect(recorded?.scope, hotkey.HotKeyScope.system);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftRight);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('virtual view renders the hotkey in $brightness mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: hotkey.HotKeyVirtualView(
            hotKey: hotkey.HotKey(
              key: PhysicalKeyboardKey.keyQ,
              modifiers: [
                hotkey.HotKeyModifier.shift,
                hotkey.HotKeyModifier.control,
              ],
            ),
          ),
        ),
      );
      expect(find.text('Q'), findsOneWidget);
      expect(find.text('⇧'), findsOneWidget);
      expect(find.text('⌃'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  final modifiers =
      <PhysicalKeyboardKey, (LogicalKeyboardKey, hotkey.HotKeyModifier)>{
        PhysicalKeyboardKey.controlLeft: (
          LogicalKeyboardKey.controlLeft,
          hotkey.HotKeyModifier.control,
        ),
        PhysicalKeyboardKey.controlRight: (
          LogicalKeyboardKey.controlRight,
          hotkey.HotKeyModifier.control,
        ),
        PhysicalKeyboardKey.shiftLeft: (
          LogicalKeyboardKey.shiftLeft,
          hotkey.HotKeyModifier.shift,
        ),
        PhysicalKeyboardKey.shiftRight: (
          LogicalKeyboardKey.shiftRight,
          hotkey.HotKeyModifier.shift,
        ),
        PhysicalKeyboardKey.altLeft: (
          LogicalKeyboardKey.altLeft,
          hotkey.HotKeyModifier.alt,
        ),
        PhysicalKeyboardKey.altRight: (
          LogicalKeyboardKey.altRight,
          hotkey.HotKeyModifier.alt,
        ),
        PhysicalKeyboardKey.metaLeft: (
          LogicalKeyboardKey.metaLeft,
          hotkey.HotKeyModifier.meta,
        ),
        PhysicalKeyboardKey.metaRight: (
          LogicalKeyboardKey.metaRight,
          hotkey.HotKeyModifier.meta,
        ),
        PhysicalKeyboardKey.fn: (
          LogicalKeyboardKey.fn,
          hotkey.HotKeyModifier.fn,
        ),
        PhysicalKeyboardKey.capsLock: (
          LogicalKeyboardKey.capsLock,
          hotkey.HotKeyModifier.capsLock,
        ),
      };
  testWidgets(
    'in-app hotkeys accept all left/right modifiers and preserve both callbacks',
    (tester) async {
      // Keep the singleton in one test: Flutter clears HardwareKeyboard handlers
      // between widget tests, while a real app keeps them for its whole lifetime.
      for (final entry in modifiers.entries) {
        var downs = 0;
        var ups = 0;
        final (logical, modifier) = entry.value;
        await hotkey.hotKeyManager.unregisterAll();
        await hotkey.hotKeyManager.register(
          hotkey.HotKey(
            key: PhysicalKeyboardKey.keyQ,
            scope: hotkey.HotKeyScope.inapp,
            modifiers: [modifier],
          ),
          keyDownHandler: (_) => downs++,
          keyUpHandler: (_) => ups++,
        );
        try {
          await tester.sendKeyDownEvent(logical, physicalKey: entry.key);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
          await tester.sendKeyUpEvent(logical, physicalKey: entry.key);
          expect(downs, 1);
          expect(ups, 1);
        } finally {
          await hotkey.hotKeyManager.unregisterAll();
        }
      }
    },
  );
}
