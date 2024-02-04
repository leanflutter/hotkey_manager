import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager_platform_interface/hotkey_manager_platform_interface.dart';

class HotKeyManager {
  HotKeyManager._();

  /// The shared instance of [HotKeyManager].
  static final HotKeyManager instance = HotKeyManager._();

  HotKeyManagerPlatform get _platform => HotKeyManagerPlatform.instance;

  bool _inited = false;
  final List<HotKey> _hotKeyList = [];
  final Map<String, HotKeyHandler> _keyDownHandlerMap = {};
  final Map<String, HotKeyHandler> _keyUpHandlerMap = {};

  // 最后按下的快捷键
  HotKey? _lastPressedHotKey;

  void _init() {
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _platform.onKeyEventReceiver.listen((event) {
      if (kDebugMode) {
        print(event);
      }
      String type = event['type'] as String;
      Map<Object?, Object?> data = event['data'] as Map;
      String identifier = data['identifier'] as String;
      HotKey? hotKey = _hotKeyList.firstWhereOrNull(
        (e) => e.identifier == identifier,
      );
      if (hotKey != null) {
        switch (type) {
          case 'onKeyDown':
            if (_keyDownHandlerMap.containsKey(identifier)) {
              _keyDownHandlerMap[identifier]!(hotKey);
            }
            break;
          case 'onKeyUp':
            if (_keyUpHandlerMap.containsKey(identifier)) {
              _keyUpHandlerMap[identifier]!(hotKey);
            }
            break;
          default:
            UnimplementedError();
        }
      }
    });
    _inited = true;
  }

  bool _handleKeyEvent(KeyEvent keyEvent) {
    if (keyEvent is KeyUpEvent && _lastPressedHotKey != null) {
      HotKeyHandler? handler = _keyUpHandlerMap[_lastPressedHotKey!.identifier];
      if (handler != null) handler(_lastPressedHotKey!);
      _lastPressedHotKey = null;
      return true;
    }

    if (keyEvent is KeyDownEvent) {
      HotKey? hotKey = _hotKeyList.firstWhereOrNull(
        (e) {
          List<ModifierKey>? pressedModifierKeys =
              ModifierKey.values // pressed modifier keys
                  .where((e) => e.isModifierPressed)
                  .toList();
          return e.scope == HotKeyScope.inapp &&
              keyEvent.logicalKey == e.logicalKey &&
              pressedModifierKeys.every(
                (modifierKey) => (e.modifiers ?? []).contains(modifierKey),
              );
        },
      );

      if (hotKey != null) {
        HotKeyHandler? handler = _keyDownHandlerMap[hotKey.identifier];
        if (handler != null) handler(hotKey);
        _lastPressedHotKey = hotKey;
      }
    }
    return true;
  }

  List<HotKey> get registeredHotKeyList => _hotKeyList;

  Future<void> register(
    HotKey hotKey, {
    HotKeyHandler? keyDownHandler,
    HotKeyHandler? keyUpHandler,
  }) async {
    if (!_inited) _init();

    if (hotKey.scope == HotKeyScope.system) {
      await _platform.register(hotKey);
    }
    if (keyDownHandler != null) {
      _keyDownHandlerMap.update(
        hotKey.identifier,
        (_) => keyDownHandler,
        ifAbsent: () => keyDownHandler,
      );
    }
    if (keyUpHandler != null) {
      _keyUpHandlerMap.update(
        hotKey.identifier,
        (_) => keyUpHandler,
        ifAbsent: () => keyUpHandler,
      );
    }

    _hotKeyList.add(hotKey);
  }

  Future<void> unregister(HotKey hotKey) async {
    if (!_inited) _init();

    if (hotKey.scope == HotKeyScope.system) {
      await _platform.unregister(hotKey);
    }
    if (_keyDownHandlerMap.containsKey(hotKey.identifier)) {
      _keyDownHandlerMap.remove(hotKey.identifier);
    }
    if (_keyUpHandlerMap.containsKey(hotKey.identifier)) {
      _keyUpHandlerMap.remove(hotKey.identifier);
    }

    _hotKeyList.removeWhere((e) => e.identifier == hotKey.identifier);
  }

  Future<void> unregisterAll() async {
    if (!_inited) _init();

    await _platform.unregisterAll();

    _keyDownHandlerMap.clear();
    _keyUpHandlerMap.clear();
    _hotKeyList.clear();
  }
}

final hotKeyManager = HotKeyManager.instance;
