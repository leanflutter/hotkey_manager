// Android instrumentation dispatches only to this Activity, through the real
// Android embedding. No keyboard input is injected into the operating system.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:hotkey_manager/native.dart' as native;

final _cache = Directory(
  '${Directory.systemTemp.path}/hotkey_manager_keyboard_probe',
);
var _requestId = 0;
final _checks = <String>[];
final _observed = <String>[];
final _recording = ValueNotifier(true);
final _focus = FocusNode();
final _text = TextEditingController();
HotKey? _recorded;
bool _finished = false;

void _check(bool value, String message) {
  if (!value) throw StateError(message);
  _checks.add(message);
}

Future<void> _until(bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Android key delivery');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

Future<void> _key(
  int code,
  int scan,
  bool down, {
  int meta = 0,
  int repeat = 0,
}) async {
  final id = ++_requestId;
  final temporary = File('${_cache.path}/request.tmp');
  temporary.writeAsStringSync(
    jsonEncode({
      'id': id,
      'code': code,
      'scan': scan,
      'action': down ? 0 : 1,
      'meta': meta,
      'repeat': repeat,
    }),
  );
  temporary.renameSync('${_cache.path}/request.json');
  await _until(() {
    final reply = File('${_cache.path}/reply.json');
    return reply.existsSync() &&
        (jsonDecode(reply.readAsStringSync()) as Map)['id'] == id;
  });
  await Future<void>.delayed(const Duration(milliseconds: 60));
}

Future<void> _finish(Object? error, [StackTrace? stack]) async {
  if (_finished) return;
  _finished = true;
  final report = jsonEncode({
    'passed': error == null,
    'platform': Platform.operatingSystem,
    'releaseMode': const bool.fromEnvironment('dart.vm.product'),
    'delivery': 'Activity.dispatchKeyEvent -> Android embedding -> Flutter',
    'osKeyboardInputGenerated': false,
    'checks': _checks,
    'observedNativeKeys': _observed,
    if (error != null) 'error': '$error',
    if (stack != null) 'stack': '$stack',
  });
  debugPrintSynchronously('HOTKEY_ANDROID_PROBE $report');
  _cache.createSync(recursive: true);
  final temporary = File('${_cache.path}/report.tmp');
  temporary.writeAsStringSync(report);
  temporary.renameSync('${_cache.path}/report.json');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HardwareKeyboard.instance.addHandler((event) {
    _observed.add(
      '${event.runtimeType}:physical=${event.physicalKey.usbHidUsage}:logical=${event.logicalKey.keyId}',
    );
    return false;
  });
  FlutterError.onError = (details) =>
      unawaited(_finish(details.exception, details.stack));
  runApp(
    MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: _recording,
          builder: (_, recording, _) => Column(
            children: [
              const Text('Android hardware-keyboard probe'),
              if (recording)
                HotKeyRecorder(
                  initalHotKey: HotKey(
                    key: PhysicalKeyboardKey.keyA,
                    scope: HotKeyScope.inapp,
                  ),
                  onHotKeyRecorded: (value) => _recorded = value,
                ),
              TextField(focusNode: _focus, controller: _text),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    await WidgetsBinding.instance.endOfFrame;
    await _until(() => File('${_cache.path}/ready.json').existsSync());
    _check(Platform.isAndroid, 'running in Android');
    _check(
      HotKeyManagerPlatform.instance is native.NativeHotKeyManagerPlatform,
      'automatic Android Dart plugin registration',
    );
    _check(
      (await HotKeyManagerPlatform.instance.getPlatformVersion())!.startsWith(
        'android',
      ),
      'platform API without a missing method channel',
    );
    await hotKeyManager.unregisterAll();
    _check(
      hotKeyManager.registeredHotKeyList.isEmpty,
      'startup native cleanup succeeds',
    );
    _check(
      !native.ShortcutManager.instance.isSupported(),
      'native global shortcuts unavailable',
    );
    try {
      await hotKeyManager.register(HotKey(key: PhysicalKeyboardKey.keyK));
      throw StateError('system registration unexpectedly succeeded');
    } on PlatformException catch (error) {
      _check(
        error.code == 'unsupported_hotkey',
        'system scope fails explicitly and recoverably',
      );
    }
    await _key(59, 42, true, meta: 1); // Shift
    await _key(29, 30, true, meta: 1); // A
    await _until(() => _recorded?.physicalKey == PhysicalKeyboardKey.keyA);
    _check(
      _recorded!.modifiers!.contains(HotKeyModifier.shift),
      'recorder retains Shift+A',
    );
    _check(
      _recorded!.scope == HotKeyScope.inapp,
      'recorder preserves requested in-app scope',
    );
    await _key(29, 30, false, meta: 1);
    await _key(59, 42, false);
    _recording.value = false;
    await WidgetsBinding.instance.endOfFrame;
    var downs = 0;
    var ups = 0;
    final first = HotKey(
      key: PhysicalKeyboardKey.keyK,
      modifiers: [HotKeyModifier.control],
      scope: HotKeyScope.inapp,
    );
    final second = HotKey(
      key: LogicalKeyboardKey.keyK,
      modifiers: [HotKeyModifier.control],
      scope: HotKeyScope.inapp,
    );
    await hotKeyManager.register(
      first,
      keyDownHandler: (_) => downs++,
      keyUpHandler: (_) => ups++,
    );
    await hotKeyManager.register(
      second,
      keyDownHandler: (_) => downs++,
      keyUpHandler: (_) => ups++,
    );
    await _key(113, 29, true, meta: 0x1000); // Ctrl
    await _key(39, 37, true, meta: 0x1000); // K
    await _until(() => downs == 2);
    _check(downs == 2, 'physical/logical shared chord receives both callbacks');
    await _key(39, 37, true, meta: 0x1000, repeat: 1);
    _check(downs == 2, 'held-key repeat does not duplicate key-down callbacks');
    await _key(113, 29, false);
    await _key(39, 37, false);
    await _until(() => ups == 2);
    _check(ups == 2, 'key-up survives releasing Ctrl before the primary key');
    await hotKeyManager.unregister(first);
    await _key(113, 29, true, meta: 0x1000);
    await _key(39, 37, true, meta: 0x1000);
    await _until(() => downs == 3);
    await hotKeyManager.unregisterAll();
    await _key(39, 37, false, meta: 0x1000);
    await _key(113, 29, false);
    _check(
      downs == 3 && ups == 2,
      'unregister and cleanup suppress stale held-key callbacks',
    );
    _check(
      hotKeyManager.registeredHotKeyList.isEmpty,
      'cleanup leaves no registrations',
    );
    var typed = 0;
    final plain = HotKey(
      key: PhysicalKeyboardKey.keyA,
      scope: HotKeyScope.inapp,
    );
    await hotKeyManager.register(plain, keyDownHandler: (_) => typed++);
    _focus.requestFocus();
    await _until(() => _focus.hasFocus);
    await _key(29, 30, true);
    await _key(29, 30, false);
    await _until(() => typed == 1 && _text.text == 'a');
    _check(
      typed == 1 && _text.text == 'a',
      'in-app shortcut preserves editable Android text input',
    );
    await hotKeyManager.unregisterAll();
    await _finish(null);
  } catch (error, stack) {
    await _finish(error, stack);
  }
}
