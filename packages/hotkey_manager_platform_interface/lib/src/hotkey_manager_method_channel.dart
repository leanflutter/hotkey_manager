import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager_platform_interface/src/hotkey.dart';
import 'package:hotkey_manager_platform_interface/src/hotkey_manager_platform_interface.dart';

/// An implementation of [HotkeyManagerPlatform] that uses method channels.
class MethodChannelHotkeyManager extends HotkeyManagerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('hotkey_manager');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<void> register(
    HotKey hotKey, {
    HotKeyHandler? keyDownHandler,
    HotKeyHandler? keyUpHandler,
  }) async {
    await methodChannel.invokeMethod('register', hotKey.toJson());
  }

  @override
  Future<void> unregister(HotKey hotKey) async {
    await methodChannel.invokeMethod('unregister', hotKey.toJson());
  }

  @override
  Future<void> unregisterAll() async {
    await methodChannel.invokeMethod('unregisterAll');
  }
}
