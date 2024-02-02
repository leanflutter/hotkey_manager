import 'package:hotkey_manager_platform_interface/src/hotkey.dart';
import 'package:hotkey_manager_platform_interface/src/hotkey_manager_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

abstract class HotkeyManagerPlatform extends PlatformInterface {
  /// Constructs a HotkeyManagerPlatform.
  HotkeyManagerPlatform() : super(token: _token);

  static final Object _token = Object();

  static HotkeyManagerPlatform _instance = MethodChannelHotkeyManager();

  /// The default instance of [HotkeyManagerPlatform] to use.
  ///
  /// Defaults to [MethodChannelHotkeyManager].
  static HotkeyManagerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [HotkeyManagerPlatform] when
  /// they register themselves.
  static set instance(HotkeyManagerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<void> register(
    HotKey hotKey, {
    HotKeyHandler? keyDownHandler,
    HotKeyHandler? keyUpHandler,
  }) async {
    
  }

  Future<void> unregister(HotKey hotKey) async {

  }

  Future<void> unregisterAll() async {
    
  }
}
