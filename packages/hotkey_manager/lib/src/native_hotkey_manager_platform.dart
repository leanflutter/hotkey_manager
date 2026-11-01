import 'dart:async';
import 'dart:io';

import 'package:hotkey_manager_platform_interface/hotkey_manager_platform_interface.dart';
import 'package:hotkey_manager/src/system_hotkey_backend.dart';
import 'package:hotkey_manager/src/hotkey_accelerator.dart';

// Keep the federated interface and channel adapter usable by existing embedders
// and mocks. Normal desktop applications use nativeapi without per-platform native plugins or method channels.
class NativeHotKeyManagerPlatform extends MethodChannelHotKeyManager {
  static void registerWith() {
    HotKeyManagerPlatform.instance = NativeHotKeyManagerPlatform();
  }

  final _backend = NativeSystemHotKeyBackend();
  final _events = StreamController<Map<Object?, Object?>>.broadcast(sync: true);
  final _hotKeys = <String, (HotKey, int, String)>{};
  final _accelerators = <String, int>{};

  NativeHotKeyManagerPlatform() {
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
  Future<String?> getPlatformVersion() async =>
      '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';

  @override
  Future<void> register(HotKey hotKey) async {
    final accelerator = hotKeyAccelerator(hotKey);
    final previous = _hotKeys[hotKey.identifier];
    final id = _accelerators[accelerator] ?? _backend.register(hotKey);
    _accelerators[accelerator] = id;
    _hotKeys[hotKey.identifier] = (hotKey, id, accelerator);
    if (previous != null) _release(previous);
  }

  void _release((HotKey, int, String) entry) {
    if (_hotKeys.values.any((other) => other.$2 == entry.$2)) return;
    _backend.unregister(entry.$2);
    _accelerators.remove(entry.$3);
  }

  @override
  Future<void> unregister(HotKey hotKey) async {
    final entry = _hotKeys.remove(hotKey.identifier);
    if (entry != null) _release(entry);
  }

  @override
  Future<void> unregisterAll() async {
    _backend.unregisterAll();
    _hotKeys.clear();
    _accelerators.clear();
  }
}
