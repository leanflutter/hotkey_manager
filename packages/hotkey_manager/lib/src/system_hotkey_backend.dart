import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/src/hotkey.dart';
import 'package:hotkey_manager/src/hotkey_accelerator.dart';
import 'package:hotkey_manager/src/extensions/keyboard_key.dart';
import 'package:nativeapi/nativeapi.dart' as nativeapi;
import 'package:uni_platform/uni_platform.dart';

/// Internal seam for testing registration failures and queued native events.
abstract class SystemHotKeyBackend {
  void Function(int id, bool isKeyDown)? onKeyEvent;
  void Function(int id)? onRegistrationLost;
  Object get registrationContext => this;
  FutureOr<int> register(HotKey hotKey);
  FutureOr<void> unregister(int id);
  FutureOr<void> unregisterAll();
  void cancelPendingRegistration([HotKey? hotKey]) {}
}

/// Internal cancellation bridge; does not change the federated platform API.
abstract interface class PendingHotKeyRegistrations {
  void cancelPendingRegistration([HotKey? hotKey]);
}

abstract interface class NativeRegistrationEvents {
  Stream<String> get lostRegistrations;
}

class NativeSystemHotKeyBackend extends SystemHotKeyBackend {
  static const _ownerPrefix = 'hotkey_manager:';
  NativeSystemHotKeyBackend({nativeapi.ShortcutManager? manager})
    : _manager = manager ?? nativeapi.ShortcutManager.instance;
  final nativeapi.ShortcutManager _manager;
  final _shortcuts = <int, nativeapi.Shortcut>{};
  final _pending = <int, _PendingRegistration>{};
  final _earlyResults = <int, nativeapi.ShortcutEvent>{};
  bool _starting = false;
  nativeapi.ListenerId? _listenerId;

  @override
  FutureOr<int> register(HotKey hotKey) {
    final accelerator = hotKeyAccelerator(hotKey);
    _listenerId ??= _manager.addListener(_onEvent);
    // Subscribe through the async event API: the native platform callback can
    // run on a UI thread other than the Dart isolate's thread.
    _starting = true;
    late final int id;
    try {
      id = _manager.requestRegistration(
        nativeapi.ShortcutOptions(
          accelerator: accelerator,
          description:
              'Hotkey ${[for (final modifier in hotKey.modifiers ?? <HotKeyModifier>[]) modifier.physicalKeys.first.keyLabel, _keyLabel(hotKey)].join('+')}',
          scope: hotKey.scope == HotKeyScope.inapp
              ? nativeapi.ShortcutScope.application
              : nativeapi.ShortcutScope.global,
          enabled: true,
        ),
        // One native registration is shared by every callback using this chord.
        // Its key must survive recreated HotKeys/widgets with generated UUIDs.
        '$_ownerPrefix$accelerator',
      );
    } finally {
      _starting = false;
    }
    final early = _earlyResults.remove(id);
    _earlyResults.clear();
    if (id == 0) {
      _removeListenerIfEmpty();
      throw _failure(accelerator);
    }
    final request = _PendingRegistration(hotKey, accelerator);
    _pending[id] = request;
    if (early != null) {
      _complete(id, early);
    } else {
      // Immediate providers retain the old synchronous path. A Portal request
      // is invisible until approved; its Future waits for this exact request ID.
      final shortcut = _manager.getWithId(id);
      if (shortcut != null) _accept(id, request, shortcut);
    }
    return _shortcuts.containsKey(id) ? id : request.result.future;
  }

  String _keyLabel(HotKey hotKey) {
    final physical = hotKey.physicalKey;
    final label = physical.keyLabel;
    if (label != 'Unknown') return label;
    // Physical debug names are stripped in AOT. Logical labels remain present.
    final key = hotKey.key;
    final logical = key is LogicalKeyboardKey ? key : physical.logicalKey;
    final logicalLabel = logical?.keyLabel;
    return logicalLabel != null && logicalLabel.isNotEmpty
        ? logicalLabel
        : 'Shortcut';
  }

  PlatformException _failure(String accelerator, [String? reason]) =>
      PlatformException(
        code: 'register_failed',
        message:
            reason ??
            'Unable to register system hotkey $accelerator. '
                'It may be in use or unsupported on this platform.',
      );

  void _onEvent(nativeapi.ShortcutEvent event) {
    final id = event.shortcutId;
    if (event is nativeapi.ShortcutRegisteredEvent ||
        event is nativeapi.ShortcutRegistrationFailedEvent) {
      if (_pending.containsKey(id)) {
        _complete(id, event);
      } else if (_starting && id != 0) {
        _earlyResults[id] = event;
      }
      return;
    }
    if (!_shortcuts.containsKey(id)) return;
    if (event is nativeapi.ShortcutActivatedEvent) {
      onKeyEvent?.call(id, true);
    } else if (event is nativeapi.ShortcutReleasedEvent) {
      onKeyEvent?.call(id, false);
    } else if (event is nativeapi.ShortcutUnregisteredEvent) {
      _shortcuts.remove(id)?.dispose();
      onRegistrationLost?.call(id);
      _removeListenerIfEmpty();
    }
  }

  void _complete(int id, nativeapi.ShortcutEvent event) {
    final request = _pending[id];
    if (request == null) return;
    if (event is nativeapi.ShortcutRegisteredEvent) {
      final shortcut = _manager.getWithId(id);
      if (shortcut != null) {
        _accept(id, request, shortcut);
        return;
      }
    }
    _pending.remove(id);
    request.result.completeError(
      _failure(
        request.accelerator,
        event is nativeapi.ShortcutRegistrationFailedEvent
            ? event.errorMessage
            : null,
      ),
    );
    _removeListenerIfEmpty();
  }

  void _accept(
    int id,
    _PendingRegistration request,
    nativeapi.Shortcut shortcut,
  ) {
    _pending.remove(id);
    _shortcuts[id] = shortcut;
    request.result.complete(id);
  }

  @override
  void cancelPendingRegistration([HotKey? hotKey]) {
    for (final entry in _pending.entries.toList()) {
      if (hotKey != null &&
          entry.value.hotKey.identifier != hotKey.identifier) {
        continue;
      }
      final id = entry.key;
      _pending.remove(id);
      if (!_manager.cancelRegistration(id)) {
        // Approval can precede delivery of its queued event to Dart.
        if (!_manager.unregisterWithId(id)) {
          final retained = _manager.getWithId(id);
          if (retained != null) {
            // Preserve ownership so a later cleanup can retry an OS refusal.
            _shortcuts[id] = retained;
            entry.value.result.completeError(
              PlatformException(
                code: 'unregister_failed',
                message: 'Unable to cancel system hotkey $id.',
              ),
            );
            continue;
          }
        }
      }
      if (!entry.value.result.isCompleted) {
        entry.value.result.completeError(
          PlatformException(
            code: 'registration_cancelled',
            message: 'Hotkey registration was cancelled.',
          ),
        );
      }
    }
    _removeListenerIfEmpty();
  }

  @override
  void unregister(int id) {
    final shortcut = _shortcuts[id];
    if (shortcut == null) return;
    if (!_manager.unregisterWithId(id)) {
      final retained = _manager.getWithId(id);
      if (retained != null) {
        retained.dispose();
        throw PlatformException(
          code: 'unregister_failed',
          message: 'Unable to release system hotkey $id.',
        );
      }
    }
    _shortcuts.remove(id);
    shortcut.dispose();
    _removeListenerIfEmpty();
  }

  @override
  void unregisterAll() {
    cancelPendingRegistration();
    // Only release registrations owned by this compatibility manager. Native
    // ShortcutManager callers in the same application keep their shortcuts.
    for (final id in _shortcuts.keys.toList()) {
      unregister(id);
    }
    if (kIsWeb) return;
    // The native singleton survives a Flutter hot restart. Reclaim this
    // package's registrations from the previous isolate as well.
    _manager.cancelPendingRegistrations(_ownerPrefix);
    var failed = false;
    for (final shortcut in _manager.getAll()) {
      try {
        if ((shortcut.registrationKey?.startsWith(_ownerPrefix) ?? false) ||
            (shortcut.description?.startsWith(_ownerPrefix) ?? false)) {
          if (!_manager.unregisterWithId(shortcut.id)) failed = true;
        }
      } finally {
        shortcut.dispose();
      }
    }
    if (failed) {
      throw PlatformException(
        code: 'unregister_failed',
        message: 'Unable to release previous hotkey registrations.',
      );
    }
  }

  void _removeListenerIfEmpty() {
    final listenerId = _listenerId;
    if (_shortcuts.isEmpty && _pending.isEmpty && listenerId != null) {
      _manager.removeListener(listenerId);
      _listenerId = null;
    }
  }
}

class _PendingRegistration {
  _PendingRegistration(this.hotKey, this.accelerator);
  final HotKey hotKey;
  final String accelerator;
  final result = Completer<int>();
}
