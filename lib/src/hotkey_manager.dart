import 'dart:async';
import 'package:flutter/services.dart';

import './hotkey.dart';

typedef HotKeyHandler = void Function();

class HotKeyManager {
  HotKeyManager._();

  /// The shared instance of [HotKeyManager].
  static final HotKeyManager instance = HotKeyManager._();

  final MethodChannel _channel = const MethodChannel('hotkey_manager');

  bool _inited = false;
  List<HotKey> _hotKeyList = [];
  Map<String, HotKeyHandler> _keyDownHandlerMap = {};
  Map<String, HotKeyHandler> _keyUpHandlerMap = {};

  void _init() {
    _channel.setMethodCallHandler(_methodCallHandler);
    _inited = true;
  }

  Future<void> _methodCallHandler(MethodCall call) async {
    String identifier = call.arguments['identifier'];

    switch (call.method) {
      case 'onKeyDown':
        HotKeyHandler handler = _keyDownHandlerMap[identifier]!;
        handler();
        break;
      case 'onKeyUp':
        HotKeyHandler handler = _keyUpHandlerMap[identifier]!;
        handler();
        break;
      default:
        UnimplementedError();
    }
  }

  Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  Future<void> record() async {
    if (!_inited) this._init();

    final Map<String, dynamic> arguments = {};
    await _channel.invokeMethod('record', arguments);
  }

  Future<void> register(
    HotKey hotKey, {
    HotKeyHandler? keyDownHandler,
    HotKeyHandler? keyUpHandler,
  }) async {
    if (!_inited) this._init();

    await _channel.invokeMethod('register', hotKey.toJson());
    if (keyDownHandler != null)
      _keyDownHandlerMap.update(
        hotKey.identifier,
        (_) => keyDownHandler,
        ifAbsent: () => keyDownHandler,
      );
    if (keyUpHandler != null)
      _keyUpHandlerMap.update(
        hotKey.identifier,
        (_) => keyUpHandler,
        ifAbsent: () => keyUpHandler,
      );

    _hotKeyList.add(hotKey);
  }

  Future<void> unregister(HotKey hotKey) async {
    if (!_inited) this._init();

    await _channel.invokeMethod('unregister', hotKey.toJson());
    if (_keyDownHandlerMap.containsKey(hotKey.identifier))
      _keyDownHandlerMap.remove(hotKey.identifier);
    if (_keyUpHandlerMap.containsKey(hotKey.identifier))
      _keyUpHandlerMap.remove(hotKey.identifier);

    _hotKeyList.removeWhere((e) => e.identifier == hotKey.identifier);
  }
}
