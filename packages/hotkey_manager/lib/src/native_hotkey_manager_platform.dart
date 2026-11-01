import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:hotkey_manager_platform_interface/hotkey_manager_platform_interface.dart';
import 'package:hotkey_manager/src/system_hotkey_backend.dart';
import 'package:hotkey_manager/src/hotkey_accelerator.dart';

// Keep the federated interface and channel adapter usable by existing embedders
// and mocks. Normal desktop applications use nativeapi without per-platform native plugins or method channels.
class NativeHotKeyManagerPlatform extends MethodChannelHotKeyManager
    implements PendingHotKeyRegistrations, NativeRegistrationEvents {
  static void registerWith() {
    HotKeyManagerPlatform.instance = NativeHotKeyManagerPlatform();
  }

  NativeHotKeyManagerPlatform({NativeSystemHotKeyBackend? backend})
    : _backend = backend ?? NativeSystemHotKeyBackend() {
    _initializeEvents();
  }

  final NativeSystemHotKeyBackend _backend;
  final _events = StreamController<Map<Object?, Object?>>.broadcast(sync: true);
  final _lost = StreamController<String>.broadcast(sync: true);
  final _hotKeys = <String, (HotKey, int, String)>{};
  final _accelerators = <String, int>{};

  void _initializeEvents() {
    _backend.onRegistrationLost = (id) {
      for (final entry in _hotKeys.values.toList()) {
        if (entry.$2 != id || _hotKeys[entry.$1.identifier] != entry) continue;
        _hotKeys.remove(entry.$1.identifier);
        if (_accelerators[entry.$3] == id) _accelerators.remove(entry.$3);
        _lost.add(entry.$1.identifier);
      }
    };
    _backend.onKeyEvent = (id, down) {
      for (final entry in _hotKeys.values.toList()) {
        if (entry.$2 == id && _hotKeys[entry.$1.identifier] == entry) {
          _events.add({
            'type': down ? 'onKeyDown' : 'onKeyUp',
            'data': entry.$1.toJson(),
          });
        }
      }
    };
  }

  @override
  Stream<Map<Object?, Object?>> get onKeyEventReceiver => _events.stream;

  @override
  Stream<String> get lostRegistrations => _lost.stream;

  @override
  Future<String?> getPlatformVersion() async =>
      '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';

  Future<void>? _pendingWork;
  final _attempts = <_PlatformRegistrationAttempt>{};

  Future<void> _enqueue(Future<void> Function() operation) {
    final result =
        _pendingWork?.then(
          (_) => operation(),
          onError: (Object error, StackTrace stack) => operation(),
        ) ??
        operation();
    _pendingWork = result;
    void done() {
      if (identical(_pendingWork, result)) _pendingWork = null;
    }

    result.then<void>(
      (_) => done(),
      onError: (Object error, StackTrace stack) => done(),
    );
    return result;
  }

  @override
  void cancelPendingRegistration([HotKey? hotKey]) {
    for (final attempt in _attempts) {
      if (hotKey == null || attempt.hotKey.identifier == hotKey.identifier) {
        attempt.cancelled = true;
      }
    }
    _backend.cancelPendingRegistration(hotKey);
  }

  @override
  Future<void> register(HotKey hotKey) {
    final attempt = _PlatformRegistrationAttempt(hotKey);
    _attempts.add(attempt);
    return _enqueue(() async {
      try {
        if (attempt.cancelled) {
          throw PlatformException(
            code: 'registration_cancelled',
            message: 'Hotkey registration was cancelled.',
          );
        }
        final accelerator = hotKeyAccelerator(hotKey);
        final previous = _hotKeys[hotKey.identifier];
        final registration =
            _accelerators[accelerator] ?? _backend.register(hotKey);
        final id = registration is Future<int>
            ? await registration
            : registration;
        _accelerators[accelerator] = id;
        _hotKeys[hotKey.identifier] = (hotKey, id, accelerator);
        if (previous != null) {
          try {
            _release(previous);
          } catch (_) {
            _hotKeys[hotKey.identifier] = previous;
            if (id != previous.$2 &&
                !_hotKeys.values.any((other) => other.$2 == id)) {
              _accelerators.remove(accelerator);
              try {
                _backend.unregister(id);
              } catch (_) {
                // Backend ownership survives until unregisterAll can retry.
              }
            }
            rethrow;
          }
        }
      } finally {
        _attempts.remove(attempt);
      }
    });
  }

  void _release((HotKey, int, String) entry) {
    if (_hotKeys.values.any((other) => other.$2 == entry.$2)) return;
    _backend.unregister(entry.$2);
    _accelerators.remove(entry.$3);
  }

  @override
  Future<void> unregister(HotKey hotKey) {
    cancelPendingRegistration(hotKey);
    return _enqueue(() async {
      final entry = _hotKeys.remove(hotKey.identifier);
      if (entry != null) {
        try {
          _release(entry);
        } catch (_) {
          _hotKeys[hotKey.identifier] = entry;
          rethrow;
        }
      }
    });
  }

  @override
  Future<void> unregisterAll() {
    cancelPendingRegistration();
    return _enqueue(() async {
      try {
        _backend.unregisterAll();
      } finally {
        // Failed native resources remain owned by the backend for retry. Do
        // not reuse IDs for resources already released by a partial cleanup.
        _hotKeys.clear();
        _accelerators.clear();
      }
    });
  }
}

class _PlatformRegistrationAttempt {
  _PlatformRegistrationAttempt(this.hotKey);
  final HotKey hotKey;
  bool cancelled = false;
}
