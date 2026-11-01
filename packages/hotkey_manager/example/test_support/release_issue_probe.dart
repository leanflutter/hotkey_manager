// Runs inside a real release application. Key events are delivered directly to
// this process's Flutter keyboard dispatcher; no OS input is generated.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:nativeapi/nativeapi.dart' as native;

final _checks = <String>[];
final _recorded = <HotKey>[];
final _clock = Stopwatch()..start();
final _recording = ValueNotifier(true);
final _textFocus = FocusNode();

void _check(bool condition, String description) {
  if (!condition) throw StateError(description);
  _checks.add(description);
}

void _key(PhysicalKeyboardKey physical, LogicalKeyboardKey logical, bool down) {
  final keyboard = HardwareKeyboard.instance;
  if (!down && !keyboard.physicalKeysPressed.contains(physical)) return;
  keyboard.handleKeyEvent(
    down
        ? KeyDownEvent(
            physicalKey: physical,
            logicalKey: logical,
            timeStamp: _clock.elapsed,
          )
        : KeyUpEvent(
            physicalKey: physical,
            logicalKey: logical,
            timeStamp: _clock.elapsed,
          ),
  );
}

void _finish(Object? error, [StackTrace? stack]) {
  final result = {
    'passed': error == null,
    'checks': _checks,
    'releaseMode': const bool.fromEnvironment('dart.vm.product'),
    'platform': Platform.operatingSystem,
    'osKeyboardInputGenerated': false,
    if (error != null) 'error': error.toString(),
    if (stack != null) 'stack': stack.toString(),
  };
  final file = File('build/compatibility_audit/release_issue_probe.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
  stdout.writeln('HOTKEY_RELEASE_ISSUE_PROBE ${jsonEncode(result)}');
  exit(error == null ? 0 : 1);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) => _finish(details.exception, details.stack);
  try {
    await hotKeyManager.unregisterAll();
    _check(true, 'automatic Dart plugin registration and cleanup');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: _recording,
            builder: (context, recording, _) => Column(
              children: [
                if (recording) HotKeyRecorder(onHotKeyRecorded: _recorded.add),
                TextField(focusNode: _textFocus),
              ],
            ),
          ),
        ),
      ),
    );
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 400));

    _key(PhysicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftLeft, true);
    _key(PhysicalKeyboardKey.keyA, LogicalKeyboardKey.keyA, true);
    _check(
      _recorded.last.key == PhysicalKeyboardKey.keyA &&
          _recorded.last.modifiers!.contains(HotKeyModifier.shift),
      'release recorder returns a non-null Shift+A hotkey',
    );
    _key(PhysicalKeyboardKey.keyA, LogicalKeyboardKey.keyA, false);
    _key(PhysicalKeyboardKey.altLeft, LogicalKeyboardKey.altLeft, true);
    _key(PhysicalKeyboardKey.keyQ, LogicalKeyboardKey.keyQ, true);
    _check(
      _recorded.last.key == PhysicalKeyboardKey.keyQ &&
          _recorded.last.modifiers!.toSet().containsAll([
            HotKeyModifier.shift,
            HotKeyModifier.alt,
          ]),
      'release recorder returns a non-null Shift+Alt+Q hotkey',
    );
    _key(PhysicalKeyboardKey.keyQ, LogicalKeyboardKey.keyQ, false);
    _key(PhysicalKeyboardKey.altLeft, LogicalKeyboardKey.altLeft, false);
    _key(PhysicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftLeft, false);
    _recording.value = false;
    await WidgetsBinding.instance.endOfFrame;

    final window = native.WindowManager.instance.getCurrent();
    _check(
      window != null && window.isVisible,
      'real application window visible',
    );
    var downs = 0;
    var ups = 0;
    var hiddenInsideCallback = false;
    final modifier = Platform.isMacOS
        ? HotKeyModifier.meta
        : HotKeyModifier.control;
    final modifierPhysical = Platform.isMacOS
        ? PhysicalKeyboardKey.metaLeft
        : PhysicalKeyboardKey.controlLeft;
    final modifierLogical = Platform.isMacOS
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await hotKeyManager.register(
      HotKey(
        key: PhysicalKeyboardKey.keyG,
        modifiers: [modifier],
        scope: HotKeyScope.inapp,
      ),
      keyDownHandler: (_) {
        downs++;
        window!.hide();
        hiddenInsideCallback = !window.isVisible;
      },
      keyUpHandler: (_) => ups++,
    );
    for (var iteration = 1; iteration <= 2; iteration++) {
      _key(modifierPhysical, modifierLogical, true);
      _key(PhysicalKeyboardKey.keyG, LogicalKeyboardKey.keyG, true);
      _check(
        hiddenInsideCallback && downs == iteration,
        'in-app callback hides the real window ($iteration)',
      );
      window!.show();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      _check(window.isVisible, 'real window shows again ($iteration)');
      _key(PhysicalKeyboardKey.keyG, LogicalKeyboardKey.keyG, false);
      _key(modifierPhysical, modifierLogical, false);
      _check(ups == iteration, 'in-app release still arrives ($iteration)');
    }
    _textFocus.requestFocus();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _check(_textFocus.hasFocus, 'real editable text field focused');
    _key(modifierPhysical, modifierLogical, true);
    _key(modifierPhysical, modifierLogical, false);
    _check(
      downs == 2,
      'modifier alone in text field does not repeat the previous chord',
    );
    await hotKeyManager.unregisterAll();
    window!.dispose();
    _finish(null);
  } catch (error, stack) {
    _finish(error, stack);
  }
}
