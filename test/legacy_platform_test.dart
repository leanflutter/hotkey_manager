import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:hotkey_manager_platform_interface/hotkey_manager_platform_interface.dart'
    as published;

class _PublishedPlatform extends published.HotKeyManagerPlatform {}

class _Platform extends HotKeyManagerPlatform {
  final events = StreamController<Map<Object?, Object?>>.broadcast(sync: true);
  final registered = <HotKey>[];
  final removed = <HotKey>[];
  Completer<void>? gate;
  bool fail = false;
  int failuresRemaining = 0;

  @override
  Stream<Map<Object?, Object?>> get onKeyEventReceiver => events.stream;
  @override
  Future<String?> getPlatformVersion() async => 'test';
  @override
  Future<void> register(HotKey hotKey) async {
    registered.add(hotKey);
    if (gate != null) await gate!.future;
    if (fail || failuresRemaining > 0) {
      if (failuresRemaining > 0) failuresRemaining--;
      throw PlatformException(code: 'register_failed');
    }
  }

  @override
  Future<void> unregister(HotKey hotKey) async => removed.add(hotKey);
  @override
  Future<void> unregisterAll() async => registered.clear();

  void fire(HotKey key, bool down) => events.add({
    'type': down ? 'onKeyDown' : 'onKeyUp',
    'data': key.toJson(),
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HotKeyManagerPlatform original;
  late _Platform platform;
  setUp(() {
    original = HotKeyManagerPlatform.instance;
    platform = _Platform();
    HotKeyManagerPlatform.instance = platform;
  });
  tearDown(() async {
    await hotKeyManager.unregisterAll();
    HotKeyManagerPlatform.instance = original;
    await platform.events.close();
  });

  test('old exported types coexist with Flutter ShortcutManager', () {
    final manager = ShortcutManager();
    manager.dispose();
    expect(original, isA<MethodChannelHotKeyManager>());
    expect(HotKeyManagerPlatform.instance, same(platform));
  });

  test(
    'published interface models and platform subclasses retain their identity',
    () {
      final HotKey key = published.HotKey(key: PhysicalKeyboardKey.keyQ);
      expect(key, isA<published.HotKey>());
      final legacy = _PublishedPlatform();
      HotKeyManagerPlatform.instance = legacy;
      expect(published.HotKeyManagerPlatform.instance, same(legacy));
      HotKeyManagerPlatform.instance = platform;
    },
  );

  test(
    'platform injection, live list and omitted handlers retain old behavior',
    () async {
      final list = hotKeyManager.registeredHotKeyList;
      final first = HotKey(
        identifier: 'replace',
        key: PhysicalKeyboardKey.keyQ,
      );
      final next = HotKey(identifier: 'replace', key: PhysicalKeyboardKey.keyW);
      final events = <(HotKey, bool)>[];
      await hotKeyManager.register(
        first,
        keyDownHandler: (key) => events.add((key, true)),
        keyUpHandler: (key) => events.add((key, false)),
      );
      expect(list, [first]);
      await hotKeyManager.register(next);
      expect(list, [next]);
      expect(platform.removed, isEmpty);
      platform.fire(next, true);
      platform.fire(next, false);
      expect(events, [(next, true), (next, false)]);
      await hotKeyManager.unregister(first);
      expect(list, isEmpty);
      expect(platform.removed, [next]);
    },
  );

  test(
    'concurrent registrations share a pending platform registration',
    () async {
      platform.gate = Completer<void>();
      final a = HotKey(identifier: 'a', key: PhysicalKeyboardKey.keyQ);
      final b = HotKey(identifier: 'b', key: PhysicalKeyboardKey.keyQ);
      var calls = 0;
      final first = hotKeyManager.register(a, keyDownHandler: (_) => calls++);
      final second = hotKeyManager.register(b, keyDownHandler: (_) => calls++);
      expect(platform.registered, [a]);
      platform.gate!.complete();
      await Future.wait([first, second]);
      expect(platform.registered, [a]);
      platform.fire(a, true);
      expect(calls, 2);
      await hotKeyManager.unregister(a);
      expect(platform.removed, isEmpty);
      platform.fire(a, true);
      expect(calls, 3);
      await hotKeyManager.unregister(b);
      expect(platform.removed, [a]);
    },
  );

  test(
    'a failed asynchronous operation does not poison later registrations',
    () async {
      platform.fail = true;
      final key = HotKey(key: PhysicalKeyboardKey.keyQ);
      await expectLater(
        hotKeyManager.register(key),
        throwsA(isA<PlatformException>()),
      );
      expect(hotKeyManager.registeredHotKeyList, isEmpty);
      platform.fail = false;
      await hotKeyManager.register(key);
      expect(hotKeyManager.registeredHotKeyList, [key]);
    },
  );

  test(
    'a queued operation still runs after an earlier pending failure',
    () async {
      platform.gate = Completer<void>();
      platform.failuresRemaining = 1;
      final failed = hotKeyManager.register(
        HotKey(key: PhysicalKeyboardKey.keyQ),
      );
      final nextKey = HotKey(key: PhysicalKeyboardKey.keyW);
      final next = hotKeyManager.register(nextKey);
      final checked = expectLater(failed, throwsA(isA<PlatformException>()));
      platform.gate!.complete();
      await checked;
      await next;
      expect(hotKeyManager.registeredHotKeyList, [nextKey]);
    },
  );

  test(
    'replacing the platform does not reuse the old platform registration',
    () async {
      final key = HotKey(identifier: 'switch', key: PhysicalKeyboardKey.keyQ);
      var calls = 0;
      await hotKeyManager.register(key, keyDownHandler: (_) => calls++);
      final replacement = _Platform();
      addTearDown(replacement.events.close);
      HotKeyManagerPlatform.instance = replacement;
      await hotKeyManager.register(key);
      expect(platform.removed, [key]);
      expect(replacement.registered, [key]);
      platform.fire(key, true);
      expect(calls, 0);
      replacement.fire(key, true);
      expect(calls, 1);
    },
  );

  test('method-channel adapter retains method names and payloads', () async {
    final channel = MethodChannelHotKeyManager();
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel.methodChannel, (call) async {
      calls.add(call);
      return call.method == 'getPlatformVersion' ? 'test OS' : null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(channel.methodChannel, null),
    );
    final key = HotKey(identifier: 'channel', key: PhysicalKeyboardKey.keyQ);
    expect(await channel.getPlatformVersion(), 'test OS');
    await channel.register(key);
    await channel.unregister(key);
    await channel.unregisterAll();
    expect(calls.map((call) => call.method), [
      'getPlatformVersion',
      'register',
      'unregister',
      'unregisterAll',
    ]);
    expect(calls[1].arguments, containsPair('identifier', 'channel'));
    expect(calls[1].arguments, contains('keyCode'));
    // Explicitly injecting the exact legacy class must also be honored.
    messenger.setMockMethodCallHandler(
      MethodChannel(channel.eventChannel.name),
      (_) async => null,
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        MethodChannel(channel.eventChannel.name),
        null,
      ),
    );
    HotKeyManagerPlatform.instance = channel;
    await hotKeyManager.register(key);
    expect(HotKeyManagerPlatform.instance, same(channel));
    expect(calls.last.method, 'register');
    await hotKeyManager.unregister(key);
    expect(calls.last.method, 'unregister');
    HotKeyManagerPlatform.instance = platform;
  });
}
