import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/src/hotkey.dart';
import 'package:hotkey_manager/src/hotkey_accelerator.dart';
import 'package:hotkey_manager/src/system_hotkey_backend.dart';
import 'package:hotkey_manager/src/platform_system_hotkey_backend.dart';

class HotKeyManager {
  HotKeyManager._() : this.withBackend(PlatformSystemHotKeyBackend());

  @visibleForTesting
  HotKeyManager.withBackend(this._backend) {
    _backend.onKeyEvent = _handleSystemHotKeyEvent;
    _backend.onRegistrationLost = _handleSystemRegistrationLost;
    HardwareKeyboard.instance.addHandler(_handleInAppHotKeyEvent);
  }

  /// The shared instance of [HotKeyManager].
  static final HotKeyManager instance = HotKeyManager._();

  final SystemHotKeyBackend _backend;
  final _registrations = <String, _Registration>{};
  final _systemRegistrations = <(Object, String), int>{};
  final _hotKeyList = <HotKey>[];
  Future<void>? _pending;
  final _registrationAttempts = <_RegistrationAttempt>{};

  void _cancelPending([HotKey? hotKey]) {
    for (final attempt in _registrationAttempts) {
      if (hotKey == null || attempt.hotKey.identifier == hotKey.identifier) {
        attempt.cancelled = true;
      }
    }
    _backend.cancelPendingRegistration(hotKey);
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result =
        _pending?.then(
          (_) => operation(),
          onError: (Object error, StackTrace stack) => operation(),
        ) ??
        operation();
    _pending = result;
    void complete() {
      if (identical(_pending, result)) _pending = null;
    }

    result.then<void>(
      (_) => complete(),
      onError: (Object error, StackTrace stack) => complete(),
    );
    return result;
  }

  final _pressedInApp = <PhysicalKeyboardKey, List<_Registration>>{};

  void _handleSystemRegistrationLost(int id) {
    final identifiers = {
      for (final entry in _registrations.values)
        if (entry.nativeId == id) entry.hotKey.identifier,
    };
    _hotKeyList.removeWhere((key) => identifiers.contains(key.identifier));
    _systemRegistrations.removeWhere((key, value) => value == id);
    // Retain handler history for a caller re-registering after service loss.
  }

  /// The live registered hotkey list, retained for legacy API compatibility.
  List<HotKey> get registeredHotKeyList => _hotKeyList;

  void _handleSystemHotKeyEvent(int id, bool isKeyDown) {
    for (final hotKey in _hotKeyList.toList()) {
      final entry = _registrations[hotKey.identifier];
      if (entry == null) continue;
      if (entry.nativeId != id ||
          !_hotKeyList.contains(hotKey) ||
          !identical(_registrations[entry.hotKey.identifier], entry)) {
        continue;
      }
      (isKeyDown ? entry.keyDownHandler : entry.keyUpHandler)?.call(hotKey);
    }
  }

  bool _handleInAppHotKeyEvent(KeyEvent event) {
    if (event is KeyUpEvent) {
      final pressed = _pressedInApp.remove(event.physicalKey);
      if (pressed == null) return false;
      for (final entry in pressed) {
        if (identical(_registrations[entry.hotKey.identifier], entry) &&
            _hotKeyList.contains(entry.hotKey)) {
          entry.keyUpHandler?.call(entry.hotKey);
        }
      }
      return false;
    }
    // Observe in-app keys without consuming Flutter text input. Callers may
    // filter their callbacks by focus; use Shortcuts/Actions to consume a key.
    // Focus recovery can synthesize held keys without a new user key press.
    if (event is! KeyDownEvent || event.synthesized) return false;

    final modifiers = HotKeyModifier.values
        .where(
          (modifier) =>
              modifier.isModifierPressed &&
              !modifier.physicalKeys.contains(event.physicalKey),
        )
        .toSet();
    final matches = _hotKeyList
        .where((hotKey) {
          final required =
              hotKey.modifiers
                  ?.where(
                    (modifier) =>
                        !modifier.physicalKeys.contains(event.physicalKey),
                  )
                  .toSet() ??
              <HotKeyModifier>{};
          return hotKey.scope == HotKeyScope.inapp &&
              event.logicalKey == hotKey.logicalKey &&
              modifiers.length == required.length &&
              modifiers.containsAll(required);
        })
        .map((hotKey) => _registrations[hotKey.identifier])
        .whereType<_Registration>()
        .toList();
    if (matches.isEmpty) return false;

    _pressedInApp[event.physicalKey] = matches;
    for (final entry in matches) {
      if (identical(_registrations[entry.hotKey.identifier], entry)) {
        entry.keyDownHandler?.call(entry.hotKey);
      }
    }
    return false;
  }

  /// Registers a hotkey. Registering an existing identifier retains handlers
  /// that are not supplied again; different identifiers for one combination each receive events.
  ///
  /// System key-up events are supported on macOS and Wayland Portal providers
  /// that send release notifications. In-app key-up events work
  /// on every Flutter platform. Registration failure leaves existing state intact.
  /// In-app callbacks observe keys without consuming text input. A callback can
  /// check its text field's focus before acting; Flutter Shortcuts/Actions can
  /// be used when key consumption or focus-dependent shortcut priority is needed.
  Future<void> register(
    HotKey hotKey, {
    HotKeyHandler? keyDownHandler,
    HotKeyHandler? keyUpHandler,
  }) {
    final attempt = _RegistrationAttempt(hotKey);
    _registrationAttempts.add(attempt);
    return _enqueue(() async {
      try {
        if (attempt.cancelled) {
          throw PlatformException(
            code: 'registration_cancelled',
            message: 'Hotkey registration was cancelled.',
          );
        }
        final previous = _registrations[hotKey.identifier];
        final previousIndex = _hotKeyList.indexWhere(
          (key) => key.identifier == hotKey.identifier,
        );
        String? accelerator;
        int? nativeId;
        final context = _backend.registrationContext;
        if (hotKey.scope == HotKeyScope.system) {
          accelerator = hotKeyAccelerator(hotKey);
          nativeId = _systemRegistrations[(context, accelerator)];
          if (nativeId == null) {
            nativeId = await _backend.register(hotKey);
            _systemRegistrations[(context, accelerator)] = nativeId;
          }
        }
        final entry = _Registration(
          hotKey,
          keyDownHandler ?? previous?.keyDownHandler,
          keyUpHandler ?? previous?.keyUpHandler,
          context: context,
          accelerator: accelerator,
          nativeId: nativeId,
        );
        _registrations[hotKey.identifier] = entry;
        final index = _hotKeyList.indexWhere(
          (key) => key.identifier == hotKey.identifier,
        );
        // If native completion won cancellation, the internal entry remains
        // available to queued cleanup while callbacks stay hidden.
        if (!attempt.cancelled) {
          if (index < 0) {
            _hotKeyList.add(hotKey);
          } else {
            _hotKeyList[index] = hotKey;
          }
        }
        if (previous != null) {
          try {
            await _releaseIfUnused(previous);
          } catch (_) {
            _registrations[hotKey.identifier] = previous;
            _hotKeyList.removeWhere(
              (key) => key.identifier == hotKey.identifier,
            );
            if (previousIndex >= 0 && !attempt.cancelled) {
              _hotKeyList.insert(
                previousIndex.clamp(0, _hotKeyList.length),
                previous.hotKey,
              );
            }
            if (nativeId != null &&
                nativeId != previous.nativeId &&
                !_registrations.values.any(
                  (other) => other.nativeId == nativeId,
                )) {
              _systemRegistrations.remove((context, accelerator));
              try {
                await _backend.unregister(nativeId);
              } catch (_) {
                // Backend ownership survives until unregisterAll can retry.
              }
            }
            rethrow;
          }
        }
      } finally {
        _registrationAttempts.remove(attempt);
      }
    });
  }

  Future<void> unregister(HotKey hotKey) {
    _cancelPending(hotKey);
    // Remove visibility immediately, including when called from another
    // hotkey's callback. Native cleanup remains ordered behind pending work.
    _hotKeyList.removeWhere((key) => key.identifier == hotKey.identifier);
    return _enqueue(() async {
      final entry = _registrations.remove(hotKey.identifier);
      if (entry == null) return;
      _hotKeyList.removeWhere((key) => key.identifier == hotKey.identifier);
      try {
        await _releaseIfUnused(entry);
      } catch (_) {
        // Keep cleanup ownership for retry while callbacks remain hidden.
        _registrations[hotKey.identifier] = entry;
        rethrow;
      }
      for (final pressed in _pressedInApp.values) {
        pressed.remove(entry);
      }
    });
  }

  Future<void> _releaseIfUnused(_Registration entry) async {
    final accelerator = entry.accelerator;
    final nativeId = entry.nativeId;
    if (accelerator == null || nativeId == null) return;
    if (_registrations.values.any((other) => other.nativeId == nativeId)) {
      return;
    }
    await _backend.unregister(nativeId);
    if (_systemRegistrations[(entry.context, accelerator)] == nativeId) {
      _systemRegistrations.remove((entry.context, accelerator));
    }
  }

  /// Unregisters the hotkeys owned by this manager. Shortcuts registered
  /// directly with nativeapi's ShortcutManager are unaffected.
  Future<void> unregisterAll() {
    _cancelPending();
    _hotKeyList.clear();
    return _enqueue(() async {
      try {
        await _backend.unregisterAll();
      } finally {
        _hotKeyList.clear();
        _registrations.clear();
        _systemRegistrations.clear();
        _pressedInApp.clear();
      }
    });
  }

  @visibleForTesting
  Future<void> dispose() async {
    HardwareKeyboard.instance.removeHandler(_handleInAppHotKeyEvent);
    await unregisterAll();
    _backend.onKeyEvent = null;
    _backend.onRegistrationLost = null;
  }
}

class _RegistrationAttempt {
  _RegistrationAttempt(this.hotKey);
  final HotKey hotKey;
  bool cancelled = false;
}

class _Registration {
  _Registration(
    this.hotKey,
    this.keyDownHandler,
    this.keyUpHandler, {
    required this.context,
    this.accelerator,
    this.nativeId,
  });

  final HotKey hotKey;
  final HotKeyHandler? keyDownHandler;
  final HotKeyHandler? keyUpHandler;
  final Object context;
  final String? accelerator;
  final int? nativeId;
}

final hotKeyManager = HotKeyManager.instance;
