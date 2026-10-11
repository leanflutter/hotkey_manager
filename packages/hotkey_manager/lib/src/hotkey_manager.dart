import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/src/hotkey.dart';
import 'package:hotkey_manager/src/hotkey_accelerator.dart';
import 'package:hotkey_manager/src/system_hotkey_backend.dart';

class HotKeyManager {
  HotKeyManager._() : this.withBackend(NativeSystemHotKeyBackend());

  @visibleForTesting
  HotKeyManager.withBackend(this._backend) {
    _backend.onKeyEvent = _handleSystemHotKeyEvent;
    HardwareKeyboard.instance.addHandler(_handleInAppHotKeyEvent);
  }

  /// The shared instance of [HotKeyManager].
  static final HotKeyManager instance = HotKeyManager._();

  final SystemHotKeyBackend _backend;
  final _registrations = <String, _Registration>{};
  final _systemRegistrations = <String, int>{};
  final _pressedInApp = <PhysicalKeyboardKey, List<_Registration>>{};

  /// A snapshot of the registered hotkeys, in registration order.
  List<HotKey> get registeredHotKeyList =>
      _registrations.values.map((entry) => entry.hotKey).toList();

  void _handleSystemHotKeyEvent(int id, bool isKeyDown) {
    for (final entry in _registrations.values.toList()) {
      if (entry.nativeId != id ||
          !identical(_registrations[entry.hotKey.identifier], entry)) {
        continue;
      }
      (isKeyDown ? entry.keyDownHandler : entry.keyUpHandler)?.call(
        entry.hotKey,
      );
    }
  }

  bool _handleInAppHotKeyEvent(KeyEvent event) {
    if (event is KeyUpEvent) {
      final pressed = _pressedInApp.remove(event.physicalKey);
      if (pressed == null) return false;
      for (final entry in pressed) {
        if (identical(_registrations[entry.hotKey.identifier], entry)) {
          entry.keyUpHandler?.call(entry.hotKey);
        }
      }
      return true;
    }
    if (event is KeyRepeatEvent) {
      return _pressedInApp.containsKey(event.physicalKey);
    }
    if (event is! KeyDownEvent) return false;

    final modifiers = HotKeyModifier.values
        .where((modifier) => modifier.isModifierPressed)
        .toSet();
    final matches = _registrations.values.where((entry) {
      final hotKey = entry.hotKey;
      final required = hotKey.modifiers?.toSet() ?? <HotKeyModifier>{};
      return hotKey.scope == HotKeyScope.inapp &&
          event.logicalKey == hotKey.logicalKey &&
          modifiers.length == required.length &&
          modifiers.containsAll(required);
    }).toList();
    if (matches.isEmpty) return false;

    _pressedInApp[event.physicalKey] = matches;
    for (final entry in matches) {
      if (identical(_registrations[entry.hotKey.identifier], entry)) {
        entry.keyDownHandler?.call(entry.hotKey);
      }
    }
    return true;
  }

  /// Registers a hotkey. Registering an existing identifier replaces its
  /// handlers; different identifiers for one combination each receive events.
  ///
  /// System key-up events are supported on macOS. In-app key-up events work
  /// on every Flutter platform. Registration failure leaves existing state intact.
  Future<void> register(
    HotKey hotKey, {
    HotKeyHandler? keyDownHandler,
    HotKeyHandler? keyUpHandler,
  }) async {
    final previous = _registrations[hotKey.identifier];
    String? accelerator;
    int? nativeId;
    if (hotKey.scope == HotKeyScope.system) {
      accelerator = hotKeyAccelerator(hotKey);
      nativeId = _systemRegistrations[accelerator];
      if (nativeId == null) {
        nativeId = _backend.register(hotKey);
        _systemRegistrations[accelerator] = nativeId;
      }
    }
    final entry = _Registration(
      hotKey,
      keyDownHandler,
      keyUpHandler,
      accelerator: accelerator,
      nativeId: nativeId,
    );
    _registrations[hotKey.identifier] = entry;
    if (previous != null) _releaseIfUnused(previous);
  }

  Future<void> unregister(HotKey hotKey) async {
    final entry = _registrations.remove(hotKey.identifier);
    if (entry == null) return;
    _releaseIfUnused(entry);
    for (final pressed in _pressedInApp.values) {
      pressed.remove(entry);
    }
  }

  void _releaseIfUnused(_Registration entry) {
    final accelerator = entry.accelerator;
    final nativeId = entry.nativeId;
    if (accelerator == null || nativeId == null) return;
    if (_registrations.values.any((other) => other.nativeId == nativeId)) {
      return;
    }
    _backend.unregister(nativeId);
    _systemRegistrations.remove(accelerator);
  }

  /// Unregisters the hotkeys owned by this manager. Shortcuts registered
  /// directly with nativeapi's ShortcutManager are unaffected.
  Future<void> unregisterAll() async {
    _backend.unregisterAll();
    _registrations.clear();
    _systemRegistrations.clear();
    _pressedInApp.clear();
  }

  @visibleForTesting
  void dispose() {
    _backend.unregisterAll();
    _backend.onKeyEvent = null;
    HardwareKeyboard.instance.removeHandler(_handleInAppHotKeyEvent);
    _registrations.clear();
    _systemRegistrations.clear();
    _pressedInApp.clear();
  }
}

class _Registration {
  _Registration(
    this.hotKey,
    this.keyDownHandler,
    this.keyUpHandler, {
    this.accelerator,
    this.nativeId,
  });

  final HotKey hotKey;
  final HotKeyHandler? keyDownHandler;
  final HotKeyHandler? keyUpHandler;
  final String? accelerator;
  final int? nativeId;
}

final hotKeyManager = HotKeyManager.instance;
