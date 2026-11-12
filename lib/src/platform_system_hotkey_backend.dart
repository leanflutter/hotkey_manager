import 'dart:async';

import 'package:hotkey_manager/src/hotkey.dart';
import 'package:hotkey_manager/src/hotkey_manager_platform_interface.dart';
import 'package:hotkey_manager/src/system_hotkey_backend.dart';

/// Adapts the original injectable platform API to the manager's registration IDs.
class PlatformSystemHotKeyBackend extends SystemHotKeyBackend {
  final _entries = <int, (HotKeyManagerPlatform, HotKey)>{};
  final _latest = <(HotKeyManagerPlatform, String), int>{};
  final _subscriptions =
      <HotKeyManagerPlatform, StreamSubscription<Map<Object?, Object?>>>{};
  final _pending = <(HotKeyManagerPlatform, HotKey)>{};
  final _lossSubscriptions =
      <HotKeyManagerPlatform, StreamSubscription<String>>{};
  var _nextId = 0;

  @override
  Object get registrationContext => HotKeyManagerPlatform.instance;

  @override
  Future<int> register(HotKey hotKey) async {
    final platform = HotKeyManagerPlatform.instance;
    if (platform is NativeRegistrationEvents) {
      _lossSubscriptions.putIfAbsent(
        platform,
        () => (platform as NativeRegistrationEvents).lostRegistrations.listen((
          identifier,
        ) {
          final id = _latest.remove((platform, identifier));
          if (id == null) return;
          _entries.remove(id);
          onRegistrationLost?.call(id);
        }),
      );
    }
    _subscriptions.putIfAbsent(platform, () {
      return platform.onKeyEventReceiver.listen((event) {
        final data = event['data'];
        if (data is! Map) return;
        final id = _latest[(platform, data['identifier'])];
        if (id == null) return;
        if (event['type'] == 'onKeyDown') onKeyEvent?.call(id, true);
        if (event['type'] == 'onKeyUp') onKeyEvent?.call(id, false);
      }, onDone: () => _subscriptions.remove(platform));
    });
    final request = (platform, hotKey);
    _pending.add(request);
    try {
      await platform.register(hotKey);
    } finally {
      _pending.remove(request);
    }
    final id = ++_nextId;
    _entries[id] = (platform, hotKey);
    _latest[(platform, hotKey.identifier)] = id;
    return id;
  }

  @override
  void cancelPendingRegistration([HotKey? hotKey]) {
    final platforms = {
      for (final entry in _pending)
        if (hotKey == null || entry.$2.identifier == hotKey.identifier)
          entry.$1,
      if (hotKey == null) HotKeyManagerPlatform.instance,
    };
    for (final platform in platforms) {
      if (platform is PendingHotKeyRegistrations) {
        (platform as PendingHotKeyRegistrations).cancelPendingRegistration(
          hotKey,
        );
      }
    }
  }

  @override
  Future<void> unregister(int id) async {
    final entry = _entries[id];
    if (entry == null) return;
    final key = (entry.$1, entry.$2.identifier);
    // A platform registration with the same identifier has already replaced
    // the old one. Never unregister its successor through the old handle.
    if (_latest[key] == id) {
      await entry.$1.unregister(entry.$2);
      _latest.remove(key);
    }
    _entries.remove(id);
  }

  @override
  Future<void> unregisterAll() async {
    final platforms = {
      for (final entry in _entries.values) entry.$1,
      HotKeyManagerPlatform.instance,
    };
    for (final platform in platforms) {
      await platform.unregisterAll();
    }
    _entries.clear();
    _latest.clear();
    // Like the original EventChannel subscription, retain the receiver for the
    // manager's lifetime. Clearing registrations must not interrupt the stream.
  }
}
