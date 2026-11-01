// Real Wayland application probe. The host harness activates only this app's
// compositor action; neither component generates OS keyboard/mouse input.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:nativeapi/nativeapi.dart' as native;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await hotKeyManager.unregisterAll();
    runApp(
      const MaterialApp(
        home: Scaffold(body: Text('Wayland shortcut verification')),
      ),
    );
    await WidgetsBinding.instance.endOfFrame;
    for (var round = 1; round <= 2; round++) {
      final activated = Completer<void>();
      final key = HotKey(
        key: PhysicalKeyboardKey.f19,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
      );
      await hotKeyManager
          .register(
            key,
            keyDownHandler: (_) {
              if (!activated.isCompleted) activated.complete();
            },
          )
          .timeout(const Duration(seconds: 15));
      final shortcuts = native.ShortcutManager.instance.getAll();
      try {
        final shortcut = shortcuts.singleWhere(
          (s) => s.registrationKey?.startsWith('hotkey_manager:') ?? false,
        );
        stdout.writeln(
          'WAYLAND_PORTAL_READY ${jsonEncode({'registrationKey': shortcut.registrationKey, 'requestedAccelerator': shortcut.accelerator, 'triggerDescription': shortcut.triggerDescription, 'description': shortcut.description, 'round': round})}',
        );
      } finally {
        for (final shortcut in shortcuts) {
          shortcut.dispose();
        }
      }
      await activated.future.timeout(const Duration(seconds: 15));
      await hotKeyManager.unregisterAll();
      final remaining = native.ShortcutManager.instance.getAll();
      try {
        if (remaining.any(
          (s) => s.registrationKey?.startsWith('hotkey_manager:') ?? false,
        )) {
          throw StateError('Owned native registration survived cleanup');
        }
      } finally {
        for (final shortcut in remaining) {
          shortcut.dispose();
        }
      }
    }
    stdout.writeln(
      'WAYLAND_PORTAL_RESULT ${jsonEncode({'passed': true, 'realPortal': true, 'realCompositorActivation': true, 'releaseMode': const bool.fromEnvironment('dart.vm.product'), 'osKeyboardInputGenerated': false})}',
    );
    exit(0);
  } catch (error, stack) {
    await hotKeyManager.unregisterAll();
    stderr.writeln('$error\n$stack');
    exit(1);
  }
}
