
import 'dart:async';

import 'package:flutter/services.dart';

class HotkeyManager {
  static const MethodChannel _channel =
      const MethodChannel('hotkey_manager');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
