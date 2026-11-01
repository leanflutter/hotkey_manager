import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:hotkey_manager/src/system_hotkey_backend.dart';

class FakeBackend extends SystemHotKeyBackend {
  int nextId = 0;
  bool fail = false;
  final registered = <int>{};
  final removed = <int>[];

  @override
  int register(HotKey hotKey) {
    if (fail) throw PlatformException(code: 'register_failed');
    final id = ++nextId;
    registered.add(id);
    return id;
  }

  @override
  void unregister(int id) {
    registered.remove(id);
    removed.add(id);
  }

  @override
  void unregisterAll() {
    registered.clear();
  }

  void emit(int id, bool down) => onKeyEvent?.call(id, down);
}

HotKey key(
  String id, {
  PhysicalKeyboardKey key = PhysicalKeyboardKey.keyQ,
  HotKeyScope scope = HotKeyScope.system,
  List<HotKeyModifier>? modifiers,
}) => HotKey(identifier: id, key: key, scope: scope, modifiers: modifiers);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeBackend backend;
  late HotKeyManager manager;
  setUp(() {
    backend = FakeBackend();
    manager = HotKeyManager.withBackend(backend);
  });
  tearDown(() => manager.dispose());

  test(
    'one system registration fans out down and up to all identifiers',
    () async {
      final a = key(
        'a',
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
      );
      final b = key(
        'b',
        modifiers: [HotKeyModifier.shift, HotKeyModifier.control],
      );
      final events = <String>[];
      for (final hotKey in [a, b]) {
        await manager.register(
          hotKey,
          keyDownHandler: (key) => events.add('${key.identifier}:down'),
          keyUpHandler: (key) => events.add('${key.identifier}:up'),
        );
      }
      expect(backend.registered, {1});
      backend.emit(1, true);
      backend.emit(1, false);
      expect(events, ['a:down', 'b:down', 'a:up', 'b:up']);
      await manager.unregister(a);
      expect(backend.registered, {1});
      await manager.unregister(b);
      expect(backend.registered, isEmpty);
      backend.emit(1, true);
      expect(events, hasLength(4));
    },
  );

  test(
    'same identifier updates handlers without duplicate registrations',
    () async {
      var oldCalls = 0;
      var newCalls = 0;
      final hotKey = key('a');
      await manager.register(hotKey, keyDownHandler: (_) => oldCalls++);
      await manager.register(hotKey, keyDownHandler: (_) => newCalls++);
      backend.emit(1, true);
      expect(oldCalls, 0);
      expect(newCalls, 1);
      expect(manager.registeredHotKeyList, [hotKey]);
      expect(backend.nextId, 1);
      await manager.register(hotKey);
      backend.emit(1, true);
      expect(newCalls, 2);
    },
  );

  test(
    'failed registration or replacement preserves current registration',
    () async {
      var calls = 0;
      final original = key('a');
      await manager.register(original, keyDownHandler: (_) => calls++);
      backend.fail = true;
      await expectLater(
        manager.register(key('b', key: PhysicalKeyboardKey.keyW)),
        throwsA(isA<PlatformException>()),
      );
      await expectLater(
        manager.register(key('a', key: PhysicalKeyboardKey.keyE)),
        throwsA(isA<PlatformException>()),
      );
      expect(manager.registeredHotKeyList, [original]);
      expect(backend.registered, {1});
      backend.emit(1, true);
      expect(calls, 1);
    },
  );

  test(
    'replacement removes the old system shortcut and rejects its stale events',
    () async {
      var calls = 0;
      await manager.register(key('a'), keyDownHandler: (_) => calls++);
      final replacement = key('a', key: PhysicalKeyboardKey.keyW);
      await manager.register(replacement, keyDownHandler: (_) => calls++);
      expect(backend.registered, {2});
      expect(backend.removed, [1]);
      backend.emit(1, true);
      expect(calls, 0);
      backend.emit(2, true);
      expect(calls, 1);
      // Unregistration uses the identifier even if the caller holds the old model.
      await manager.unregister(key('a'));
      expect(manager.registeredHotKeyList, isEmpty);
      expect(backend.registered, isEmpty);
    },
  );

  test('unregistering during delivery skips handlers removed by an earlier handler', () async {
    final a = key('a');
    final b = key('b');
    var bCalls = 0;
    await manager.register(
      a,
      keyDownHandler: (_) {
        manager.unregister(b);
      },
    );
    await manager.register(b, keyDownHandler: (_) => bCalls++);
    backend.emit(1, true);
    expect(bCalls, 0);
    expect(manager.registeredHotKeyList, [a]);
  });

  test(
    'unregisterAll ignores queued native events and permits re-registration',
    () async {
      var calls = 0;
      await manager.register(key('a'), keyDownHandler: (_) => calls++);
      await manager.unregisterAll();
      backend.emit(1, true);
      expect(calls, 0);
      await manager.register(key('a'), keyDownHandler: (_) => calls++);
      backend.emit(1, true);
      backend.emit(2, true);
      expect(calls, 1);
      final live = manager.registeredHotKeyList;
      expect(live, hasLength(1));
      await manager.unregisterAll();
      expect(live, isEmpty);
      await manager.register(key('b'));
      expect(live, hasLength(1));
      live.clear();
      expect(manager.registeredHotKeyList, isEmpty);
    },
  );

  testWidgets(
    'in-app shortcuts release only on their own key and suppress repeats',
    (tester) async {
      var downs = 0;
      var ups = 0;
      final hotKey = key(
        'inapp',
        scope: HotKeyScope.inapp,
        modifiers: [HotKeyModifier.control],
      );
      await manager.register(
        hotKey,
        keyDownHandler: (_) => downs++,
        keyUpHandler: (_) => ups++,
      );
      expect(backend.registered, isEmpty);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyQ);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyQ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(downs, 1);
      expect(ups, 0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyQ);
      expect(ups, 1);
    },
  );

  testWidgets(
    'in-app matching requires exact modifiers and handles all matching releases',
    (tester) async {
      var downs = 0;
      var ups = 0;
      for (final id in ['a', 'b']) {
        await manager.register(
          key(id, scope: HotKeyScope.inapp),
          keyDownHandler: (_) => downs++,
          keyUpHandler: (_) => ups++,
        );
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
      expect(downs, 0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyQ);
      expect(downs, 2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyQ);
      expect(ups, 2);
    },
  );

  testWidgets('unregisterAll clears held in-app keys', (tester) async {
    var ups = 0;
    await manager.register(
      key('a', scope: HotKeyScope.inapp),
      keyUpHandler: (_) => ups++,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyQ);
    await manager.unregisterAll();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyQ);
    expect(ups, 0);
  });
}
