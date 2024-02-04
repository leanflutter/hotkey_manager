import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final Map<ModifierKey, String> _knownModifierKeyLabels = <ModifierKey, String>{
  ModifierKey.capsLockModifier: '⇪',
  ModifierKey.shiftModifier: '⇧',
  ModifierKey.controlModifier: (!kIsWeb && Platform.isMacOS) ? '⌃' : 'Ctrl',
  ModifierKey.altModifier: (!kIsWeb && Platform.isMacOS) ? '⌥' : 'Alt',
  ModifierKey.metaModifier: (!kIsWeb && Platform.isMacOS) ? '⌘' : '⊞',
  ModifierKey.functionModifier: 'fn',
};

const _modifierKeyMap = <ModifierKey, List<PhysicalKeyboardKey>>{
  ModifierKey.capsLockModifier: [
    PhysicalKeyboardKey.capsLock,
  ],
  ModifierKey.shiftModifier: [
    PhysicalKeyboardKey.shiftLeft,
    PhysicalKeyboardKey.shiftRight,
  ],
  ModifierKey.controlModifier: [
    PhysicalKeyboardKey.controlLeft,
    PhysicalKeyboardKey.controlRight,
  ],
  ModifierKey.altModifier: [
    PhysicalKeyboardKey.altLeft,
    PhysicalKeyboardKey.altRight,
  ],
  ModifierKey.metaModifier: [
    PhysicalKeyboardKey.metaLeft,
    PhysicalKeyboardKey.metaRight,
  ],
  ModifierKey.functionModifier: [
    PhysicalKeyboardKey.fn,
  ],
};

extension ModifierKeyExt on ModifierKey {
  String get keyLabel => _knownModifierKeyLabels[this] ?? '';

  bool get isModifierPressed {
    final physicalKeysPressed = HardwareKeyboard.instance.physicalKeysPressed;
    if (_modifierKeyMap[this] != null) {
      return _modifierKeyMap[this]!.any(physicalKeysPressed.contains);
    }
    return false;
  }

  List<PhysicalKeyboardKey> get physicalKeys {
    return _modifierKeyMap[this] ?? <PhysicalKeyboardKey>[];
  }
}
