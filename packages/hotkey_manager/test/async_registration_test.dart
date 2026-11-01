import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:hotkey_manager/native.dart';
import 'package:hotkey_manager/src/native_hotkey_manager_platform.dart';
import 'package:hotkey_manager/src/platform_system_hotkey_backend.dart';
import 'package:hotkey_manager/src/system_hotkey_backend.dart';
import 'package:nativeapi/nativeapi.dart' as native;

// Models the asynchronous native contract, including synchronous/early events.
// No D-Bus service, desktop, keyboard input or native reservation is needed.
class _Registry implements native.ShortcutManager {
  final requests = <int, (native.ShortcutOptions, String)>{};
  final pending = <int>{};
  final active = <int>{};
  final listeners = <int, FutureOr<void> Function(native.ShortcutEvent)>{};
  final handles = <_Shortcut>[];
  void Function(int)? beforeReturn;
  var nextId = 1;
  var accepted = true;
  var refuseUnregister = false;

  void emit(native.ShortcutEvent event) {
    for (final listener in listeners.values.toList()) {
      listener(event);
    }
  }

  @override
  int addListener(FutureOr<void> Function(native.ShortcutEvent) callback) {
    final id = nextId++;
    listeners[id] = callback;
    return id;
  }

  @override
  bool removeListener(int listenerId) => listeners.remove(listenerId) != null;

  @override
  int requestRegistration(native.ShortcutOptions options, String key) {
    if (!accepted) return 0;
    final id = nextId++;
    requests[id] = (options, key);
    pending.add(id);
    beforeReturn?.call(id);
    return id;
  }

  void approve(int id, {bool notify = true}) {
    pending.remove(id);
    active.add(id);
    if (notify) {
      emit(
        native.ShortcutRegisteredEvent(
          shortcutId: id,
          accelerator: requests[id]!.$1.accelerator,
        ),
      );
    }
  }

  void reject(int id) {
    pending.remove(id);
    emit(
      native.ShortcutRegistrationFailedEvent(
        shortcutId: id,
        accelerator: requests[id]!.$1.accelerator,
        errorMessage: 'Permission denied',
      ),
    );
  }

  @override
  bool cancelRegistration(int id) {
    if (!pending.remove(id)) return false;
    // A completion callback may run before cancellation returns.
    reject(id);
    return true;
  }

  @override
  int cancelPendingRegistrations(String prefix) {
    final ids = pending
        .where((id) => requests[id]!.$2.startsWith(prefix))
        .toList();
    for (final id in ids) {
      cancelRegistration(id);
    }
    return ids.length;
  }

  @override
  native.Shortcut? getWithId(int id) {
    if (!active.contains(id)) return null;
    final (options, key) = requests[id]!;
    final handle = _Shortcut(
      id,
      options.accelerator!,
      options.description!,
      key,
    );
    handles.add(handle);
    return handle;
  }

  @override
  List<native.Shortcut> getAll() => [for (final id in active) getWithId(id)!];

  @override
  bool unregisterWithId(int id) {
    if (refuseUnregister) return false;
    if (!active.remove(id)) return false;
    emit(
      native.ShortcutUnregisteredEvent(
        shortcutId: id,
        accelerator: requests[id]!.$1.accelerator,
      ),
    );
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Shortcut implements native.Shortcut {
  _Shortcut(this.id, this.accelerator, this.description, this.registrationKey);
  @override
  final int id;
  @override
  final String accelerator;
  @override
  final String description;
  @override
  final String registrationKey;
  bool disposed = false;
  @override
  void dispose() {
    disposed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

HotKey _key(String id, [PhysicalKeyboardKey key = PhysicalKeyboardKey.f19]) =>
    HotKey(identifier: id, key: key, modifiers: [HotKeyModifier.control]);

Matcher get _cancelled => isA<PlatformException>().having(
  (e) => e.code,
  'code',
  'registration_cancelled',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('approval correlates by request ID and forwards down/up only after approval', () async {
    final registry = _Registry();
    final backend = NativeSystemHotKeyBackend(manager: registry);
    final events = <(int, bool)>[];
    backend.onKeyEvent = (id, down) => events.add((id, down));
    var completed = false;
    final registration = Future<int>.value(backend.register(_key('first')))
      ..then((_) => completed = true);
    final id = registry.pending.single;
    registry.emit(
      native.ShortcutRegistrationFailedEvent(
        shortcutId: 0,
        accelerator: registry.requests[id]!.$1.accelerator,
        errorMessage: 'Different rejected request',
      ),
    );
    registry.emit(
      native.ShortcutActivatedEvent(shortcutId: id, accelerator: 'ignored'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    expect(events, isEmpty);
    registry.approve(id);
    expect(await registration, id);
    registry.emit(
      native.ShortcutActivatedEvent(
        shortcutId: id,
        accelerator: 'desktop choice',
      ),
    );
    registry.emit(
      native.ShortcutReleasedEvent(
        shortcutId: id,
        accelerator: 'desktop choice',
      ),
    );
    expect(events, [(id, true), (id, false)]);
    backend.unregisterAll();
    expect(registry.active, isEmpty);
    expect(registry.listeners, isEmpty);
    expect(registry.handles.every((h) => h.disposed), isTrue);
  });

  test('denial and rejected starts recover without listener leaks', () async {
    final registry = _Registry();
    final backend = NativeSystemHotKeyBackend(manager: registry);
    final registration = Future<int>.value(backend.register(_key('first')));
    final denied = expectLater(
      registration,
      throwsA(
        isA<PlatformException>().having(
          (e) => e.message,
          'reason',
          'Permission denied',
        ),
      ),
    );
    registry.reject(registry.pending.single);
    await denied;
    expect(registry.listeners, isEmpty);
    registry.accepted = false;
    expect(
      () => backend.register(_key('second')),
      throwsA(isA<PlatformException>()),
    );
    expect(registry.listeners, isEmpty);
    registry.accepted = true;
    registry.beforeReturn = registry.approve;
    expect(backend.register(_key('recovery')), isA<int>());
    backend.unregisterAll();
  });

  test(
    'early failure before request returns is retained and reported once',
    () async {
      final registry = _Registry()..beforeReturn = null;
      registry.beforeReturn = registry.reject;
      final backend = NativeSystemHotKeyBackend(manager: registry);
      await expectLater(
        Future<int>.value(backend.register(_key('early'))),
        throwsA(isA<PlatformException>()),
      );
      expect(registry.listeners, isEmpty);
    },
  );

  test(
    'cancellation also releases approval whose notification is still queued',
    () async {
      final registry = _Registry();
      final backend = NativeSystemHotKeyBackend(manager: registry);
      final key = _key('first');
      final registration = Future<int>.value(backend.register(key));
      final cancelled = expectLater(registration, throwsA(_cancelled));
      final id = registry.pending.single;
      registry.approve(id, notify: false);
      backend.cancelPendingRegistration(key);
      await cancelled;
      expect(registry.active, isEmpty);
      expect(registry.listeners, isEmpty);
    },
  );

  test(
    'failed cancellation retains ownership for a later cleanup retry',
    () async {
      final registry = _Registry();
      final backend = NativeSystemHotKeyBackend(manager: registry);
      final key = _key('first');
      final registration = Future<int>.value(backend.register(key));
      final failed = expectLater(
        registration,
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'unregister_failed',
          ),
        ),
      );
      final id = registry.pending.single;
      registry.approve(id, notify: false);
      registry.refuseUnregister = true;
      backend.cancelPendingRegistration(key);
      await failed;
      expect(registry.active, {id});
      registry.refuseUnregister = false;
      backend.unregisterAll();
      expect(registry.active, isEmpty);
      expect(registry.listeners, isEmpty);
      expect(registry.handles.every((h) => h.disposed), isTrue);
    },
  );

  test('recreated HotKey UUIDs retain the same desktop binding key and readable label', () {
    final registry = _Registry();
    registry.beforeReturn = registry.approve;
    final backend = NativeSystemHotKeyBackend(manager: registry);
    backend.register(_key('uuid-1'));
    final firstKey = registry.requests.values.single.$2;
    backend.unregisterAll();
    backend.register(_key('uuid-2'));
    expect(registry.requests.values.last.$2, firstKey);
    final label = registry.requests.values.last.$1.description!;
    expect(label, contains('F19'));
    expect(label, isNot(contains('NativeKey')));
    expect(label, isNot(contains('hotkey_manager:')));
    backend.unregisterAll();
  });

  test('restart cleanup reclaims only this module pending and active keys', () {
    final registry = _Registry();
    const options = native.ShortcutOptions(
      accelerator: 'Ctrl+F19',
      description: 'Readable action',
      scope: native.ShortcutScope.global,
      enabled: true,
    );
    final stale = registry.requestRegistration(options, 'hotkey_manager:stale');
    final peer = registry.requestRegistration(options, 'peer:pending');
    final old = registry.requestRegistration(options, 'hotkey_manager:active');
    final other = registry.requestRegistration(options, 'peer:active');
    registry.approve(old);
    registry.approve(other);
    NativeSystemHotKeyBackend(manager: registry).unregisterAll();
    expect(registry.pending, {peer});
    expect(registry.pending, isNot(contains(stale)));
    expect(registry.active, {other});
    expect(registry.handles.every((h) => h.disposed), isTrue);
  });

  test('platform serializes concurrent shared-chord registrations and independent disposal', () async {
    final registry = _Registry();
    final platform = NativeHotKeyManagerPlatform(
      backend: NativeSystemHotKeyBackend(manager: registry),
    );
    final first = platform.register(_key('first'));
    final second = platform.register(_key('second'));
    expect(registry.requests, hasLength(1));
    registry.approve(registry.pending.single);
    await Future.wait([first, second]);
    expect(registry.requests, hasLength(1));
    await platform.unregister(_key('first'));
    expect(registry.active, hasLength(1));
    await platform.unregister(_key('second'));
    expect(registry.active, isEmpty);
  });

  test('public unregister can retry failure and unregisterAll clears partially released IDs', () async {
    final previous = HotKeyManagerPlatform.instance;
    final registry = _Registry();
    registry.beforeReturn = registry.approve;
    HotKeyManagerPlatform.instance = NativeHotKeyManagerPlatform(
      backend: NativeSystemHotKeyBackend(manager: registry),
    );
    final manager = HotKeyManager.withBackend(PlatformSystemHotKeyBackend());
    final key = _key('retry');
    try {
      await manager.register(key);
      registry.refuseUnregister = true;
      await expectLater(
        manager.unregister(key),
        throwsA(isA<PlatformException>()),
      );
      expect(registry.active, hasLength(1));
      registry.refuseUnregister = false;
      await manager.unregister(key);
      expect(registry.active, isEmpty);
      await manager.register(key);
      registry.refuseUnregister = true;
      await expectLater(
        manager.unregisterAll(),
        throwsA(isA<PlatformException>()),
      );
      expect(manager.registeredHotKeyList, isEmpty);
      registry.refuseUnregister = false;
      await manager.unregisterAll();
      expect(registry.active, isEmpty);
      await manager.register(key);
      expect(manager.registeredHotKeyList, [key]);
    } finally {
      registry.refuseUnregister = false;
      await manager.dispose();
      HotKeyManagerPlatform.instance = previous;
    }
  });

  test('service loss invalidates shared caches and re-registration retains handlers', () async {
    final previous = HotKeyManagerPlatform.instance;
    final registry = _Registry();
    registry.beforeReturn = registry.approve;
    HotKeyManagerPlatform.instance = NativeHotKeyManagerPlatform(
      backend: NativeSystemHotKeyBackend(manager: registry),
    );
    final manager = HotKeyManager.withBackend(PlatformSystemHotKeyBackend());
    final key = _key('recover');
    var calls = 0;
    try {
      await manager.register(key, keyDownHandler: (_) => calls++);
      final old = registry.active.single;
      registry.unregisterWithId(old); // Portal/session revoked outside the app.
      expect(manager.registeredHotKeyList, isEmpty);
      await manager.register(key);
      final fresh = registry.active.single;
      expect(fresh, isNot(old));
      expect(registry.requests, hasLength(2));
      registry.emit(
        native.ShortcutActivatedEvent(shortcutId: fresh, accelerator: 'chosen'),
      );
      expect(calls, 1);
      registry.emit(
        native.ShortcutActivatedEvent(shortcutId: old, accelerator: 'stale'),
      );
      expect(calls, 1);
    } finally {
      await manager.dispose();
      HotKeyManagerPlatform.instance = previous;
    }
  });

  test(
    'failed replacement preserves the prior binding and cleanup ownership',
    () async {
      final previous = HotKeyManagerPlatform.instance;
      final registry = _Registry();
      registry.beforeReturn = registry.approve;
      HotKeyManagerPlatform.instance = NativeHotKeyManagerPlatform(
        backend: NativeSystemHotKeyBackend(manager: registry),
      );
      final manager = HotKeyManager.withBackend(PlatformSystemHotKeyBackend());
      final original = _key('replace');
      final replacement = _key('replace', PhysicalKeyboardKey.f20);
      var calls = 0;
      try {
        await manager.register(original, keyDownHandler: (_) => calls++);
        final oldId = registry.active.single;
        registry.refuseUnregister = true;
        await expectLater(
          manager.register(replacement),
          throwsA(isA<PlatformException>()),
        );
        expect(manager.registeredHotKeyList, [original]);
        registry.emit(
          native.ShortcutActivatedEvent(
            shortcutId: oldId,
            accelerator: 'original',
          ),
        );
        expect(calls, 1);
        registry.refuseUnregister = false;
        await manager.unregisterAll();
        expect(registry.active, isEmpty);
      } finally {
        registry.refuseUnregister = false;
        await manager.dispose();
        HotKeyManagerPlatform.instance = previous;
      }
    },
  );

  testWidgets(
    'cleanup suppresses held in-app releases while native work is queued',
    (tester) async {
      final registry = _Registry();
      final manager = HotKeyManager.withBackend(
        NativeSystemHotKeyBackend(manager: registry),
      );
      var releases = 0;
      try {
        await manager.register(
          HotKey(key: PhysicalKeyboardKey.keyA, scope: HotKeyScope.inapp),
          keyUpHandler: (_) => releases++,
        );
        HardwareKeyboard.instance.handleKeyEvent(
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.keyA,
            logicalKey: LogicalKeyboardKey.keyA,
            timeStamp: Duration.zero,
          ),
        );
        final pending = manager.register(_key('pending'));
        final cancelled = expectLater(pending, throwsA(_cancelled));
        final cleanup = manager.unregisterAll();
        HardwareKeyboard.instance.handleKeyEvent(
          const KeyUpEvent(
            physicalKey: PhysicalKeyboardKey.keyA,
            logicalKey: LogicalKeyboardKey.keyA,
            timeStamp: Duration.zero,
          ),
        );
        expect(releases, 0);
        await cleanup;
        await cancelled;
      } finally {
        await manager.dispose();
      }
    },
  );

  test('public manager cancels pending and queued approvals without blocking behind them', () async {
    final previous = HotKeyManagerPlatform.instance;
    final registry = _Registry();
    HotKeyManagerPlatform.instance = NativeHotKeyManagerPlatform(
      backend: NativeSystemHotKeyBackend(manager: registry),
    );
    final manager = HotKeyManager.withBackend(PlatformSystemHotKeyBackend());
    try {
      final first = manager.register(_key('first'));
      final second = manager.register(_key('second', PhysicalKeyboardKey.f20));
      final expectations = [
        expectLater(first, throwsA(_cancelled)),
        expectLater(second, throwsA(_cancelled)),
      ];
      await manager.unregisterAll().timeout(const Duration(seconds: 2));
      await Future.wait(expectations);
      expect(registry.pending, isEmpty);
      expect(registry.requests, hasLength(1));
      expect(manager.registeredHotKeyList, isEmpty);
    } finally {
      await manager.dispose();
      HotKeyManagerPlatform.instance = previous;
    }
  });

  testWidgets(
    'disposing a global widget cancels its pending approval without an unhandled error',
    (tester) async {
      final previous = HotKeyManagerPlatform.instance;
      final registry = _Registry();
      HotKeyManagerPlatform.instance = NativeHotKeyManagerPlatform(
        backend: NativeSystemHotKeyBackend(manager: registry),
      );
      try {
        await tester.pumpWidget(
          CallbackGlobalShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.f19, control: true):
                  () {},
            },
            child: const SizedBox(),
          ),
        );
        expect(registry.pending, hasLength(1));
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(registry.pending, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() => hotKeyManager.unregisterAll());
      } finally {
        HotKeyManagerPlatform.instance = previous;
      }
    },
  );
}
