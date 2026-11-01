// Run in macos_media_host with the real release Flutter framework and SDK asset.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:hotkey_manager/native.dart' as native;

const _host = MethodChannel('hotkey_manager_example/media_probe');
final _checks = <String>[];
void _check(bool ok, String label) {
  if (!ok) throw StateError(label);
  _checks.add(label);
}

Future<void> _until(bool Function() condition) async {
  final end = DateTime.now().add(const Duration(seconds: 3));
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      throw TimeoutException('native media callback');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> _media(
  int code,
  bool down, {
  int flags = 0,
  bool repeat = false,
}) async {
  await _host.invokeMethod<void>('media', {
    'code': code,
    'down': down,
    'flags': flags,
    'repeat': repeat,
  });
  await Future<void>.delayed(const Duration(milliseconds: 50));
}

int _nativeCount() {
  final handles = native.ShortcutManager.instance.getAll();
  try {
    return handles.length;
  } finally {
    for (final handle in handles) {
      handle.dispose();
    }
  }
}

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? failure;
  bool globalAvailable = false;
  String? globalUnavailable;
  try {
    _check(
      Platform.isMacOS && const bool.fromEnvironment('dart.vm.product'),
      'real macOS AOT engine',
    );
    _check(
      HotKeyManagerPlatform.instance is native.NativeHotKeyManagerPlatform,
      'automatic native Dart plugin registration',
    );
    await hotKeyManager.unregisterAll();
    var localDown = 0, localUp = 0, globalDown = 0, globalUp = 0;
    final local = HotKey(
      key: PhysicalKeyboardKey.mediaPlayPause,
      scope: HotKeyScope.inapp,
      modifiers: [HotKeyModifier.control],
    );
    final localLogical = HotKey(
      key: LogicalKeyboardKey.mediaPlayPause,
      scope: HotKeyScope.inapp,
      modifiers: [HotKeyModifier.control],
    );
    final global = HotKey(
      key: LogicalKeyboardKey.mediaPlayPause,
      modifiers: [HotKeyModifier.control],
    );
    for (final key in [local, localLogical]) {
      await hotKeyManager.register(
        key,
        keyDownHandler: (_) => localDown++,
        keyUpHandler: (_) => localUp++,
      );
    }
    _check(
      hotKeyManager.registeredHotKeyList.length == 2,
      'physical/logical app media share one native registration',
    );
    _check(_nativeCount() == 1, 'one application media OS handle');
    try {
      await hotKeyManager.register(
        global,
        keyDownHandler: (_) => globalDown++,
        keyUpHandler: (_) => globalUp++,
      );
      globalAvailable = true;
    } on PlatformException catch (error) {
      if (!arguments.contains('--allow-unavailable-global') ||
          error.code != 'register_failed') {
        rethrow;
      }
      globalUnavailable = error.message;
    }
    _check(
      _nativeCount() == (globalAvailable ? 2 : 1),
      globalAvailable
          ? 'real global media tap registration coexists with app scope'
          : 'denied global tap preserves application registration',
    );
    await _media(16, true, flags: 1 << 18); // Control
    await _until(
      () => localDown == 2 && globalDown == (globalAvailable ? 1 : 0),
    );
    _check(
      localDown == 2 && globalDown == (globalAvailable ? 1 : 0),
      'AppKit media -> SDK/C ABI/Dart -> unchanged legacy down callbacks',
    );
    await _media(16, true, flags: 1 << 18, repeat: true);
    _check(
      localDown == 2 && globalDown == (globalAvailable ? 1 : 0),
      'media autorepeat does not duplicate activation',
    );
    await _media(16, false);
    await _until(() => localUp == 2 && globalUp == (globalAvailable ? 1 : 0));
    _check(
      localUp == 2 && globalUp == (globalAvailable ? 1 : 0),
      'native up reaches both scopes after modifier release',
    );
    await hotKeyManager.unregister(global);
    await _media(16, true, flags: 1 << 18);
    await _media(16, false);
    await _until(() => localDown == 4 && localUp == 4);
    _check(
      globalDown == (globalAvailable ? 1 : 0) &&
          globalUp == (globalAvailable ? 1 : 0),
      'global cleanup preserves app callbacks and removes global callbacks',
    );
    await hotKeyManager.unregister(local);
    await _media(16, true, flags: 1 << 18);
    await _media(16, false);
    await _until(() => localDown == 5 && localUp == 5);
    _check(
      localDown == 5 && localUp == 5,
      'removing one identifier preserves its shared logical-key handler',
    );
    await hotKeyManager.unregisterAll();
    await _media(16, true, flags: 1 << 18);
    await _media(16, false);
    _check(
      localDown == 5 &&
          globalDown == (globalAvailable ? 1 : 0) &&
          _nativeCount() == 0,
      'cleanup removes all owned media resources and callbacks',
    );
    final next = HotKey(
      key: PhysicalKeyboardKey.mediaTrackNext,
      scope: HotKeyScope.inapp,
    );
    var nextDown = 0, nextUp = 0;
    await hotKeyManager.register(
      next,
      keyDownHandler: (_) => nextDown++,
      keyUpHandler: (_) => nextUp++,
    );
    await _media(19, true);
    await _media(19, false); // Apple FAST alias for NEXT
    await _until(() => nextDown == 1 && nextUp == 1);
    _check(
      nextDown == 1 && nextUp == 1,
      'Apple transport-key alias delivers track-next down/up',
    );
    await hotKeyManager.unregisterAll();
    var bareDown = 0, bareUp = 0;
    final bare = <HotKey>[
      for (final key in [
        PhysicalKeyboardKey.mediaPlayPause,
        LogicalKeyboardKey.mediaPlayPause,
      ]) ...[
        HotKey(key: key, modifiers: [], scope: HotKeyScope.inapp),
        if (globalAvailable)
          HotKey(key: key, modifiers: [], scope: HotKeyScope.system),
      ],
    ];
    for (final key in bare) {
      await hotKeyManager.register(
        key,
        keyDownHandler: (_) => bareDown++,
        keyUpHandler: (_) => bareUp++,
      );
    }
    _check(
      _nativeCount() == (globalAvailable ? 2 : 1),
      'original unmodified physical/logical media forms share native handles',
    );
    await _media(16, true);
    await _media(16, false);
    await _until(() => bareDown == bare.length && bareUp == bare.length);
    _check(
      bareDown == bare.length && bareUp == bare.length,
      'original empty-modifier Play/Pause examples receive down/up without a null cast',
    );
    await hotKeyManager.unregisterAll();
  } catch (error, stack) {
    failure = '$error\n$stack';
  }
  final result = {
    'passed': failure == null,
    'checks': _checks,
    'releaseMode': true,
    'globalMediaVerified': globalAvailable,
    'globalUnavailable': ?globalUnavailable,
    'osKeyboardInputGenerated': false,
    'physicalMediaKeyTested': false,
    'delivery':
        'process-local NSEvent -> real SDK native asset -> legacy callbacks',
    if (failure != null) 'error': '$failure',
  };
  await _host.invokeMethod<void>('done', {
    'passed': failure == null,
    'json': jsonEncode(result),
  });
}
