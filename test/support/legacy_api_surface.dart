import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart' as h;

h.HotKeyManagerPlatform get platform => h.HotKeyManagerPlatform.instance;
h.MethodChannelHotKeyManager createMethodChannel() =>
    h.MethodChannelHotKeyManager();
Future<void> legacyPlatformCalls(h.HotKey hotKey) async {
  final p = platform;
  final Stream<Map<Object?, Object?>> events = p.onKeyEventReceiver;
  await p.getPlatformVersion();
  await p.register(hotKey);
  await p.unregister(hotKey);
  await p.unregisterAll();
  h.HotKeyManagerPlatform.instance = createMethodChannel();
  createMethodChannel().methodChannel.setMethodCallHandler((_) async => null);
  createMethodChannel().eventChannel.receiveBroadcastStream();
  events.listen((_) {});
}

h.HotKey makeHotKey() => h.HotKey(key: PhysicalKeyboardKey.keyQ);
