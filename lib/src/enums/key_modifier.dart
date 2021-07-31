import 'package:flutter/foundation.dart' show describeEnum;
import 'package:flutter/services.dart';

const Map<KeyModifier, List<LogicalKeyboardKey>> _knownLogicalKeys =
    <KeyModifier, List<LogicalKeyboardKey>>{
  KeyModifier.capsLock: [
    LogicalKeyboardKey.capsLock,
  ],
  KeyModifier.shift: [
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
  ],
  KeyModifier.control: [
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
  ],
  KeyModifier.alt: [
    LogicalKeyboardKey.alt,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
  ],
  KeyModifier.meta: [
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
  ],
  KeyModifier.fn: [
    LogicalKeyboardKey.fn,
  ],
};

const Map<KeyModifier, String> _knownLogicalKeyLabels = <KeyModifier, String>{
  KeyModifier.capsLock: '⇪',
  KeyModifier.shift: '⇧',
  KeyModifier.control: '⌃',
  KeyModifier.alt: '⌥',
  KeyModifier.meta: '⌘',
  KeyModifier.fn: 'fn',
};

enum KeyModifier {
  capsLock,
  shift,
  control,
  alt, // Alt / Option key
  meta, // Command / Win key
  fn,
}

extension KeyModifierParser on KeyModifier {
  static KeyModifier parse(String string) {
    return KeyModifier.values.firstWhere((e) => describeEnum(e) == string);
  }

  static KeyModifier? fromLogicalKey(LogicalKeyboardKey logicalKey) {
    List<int> logicalKeyIdList = [];

    for (List<LogicalKeyboardKey> item in _knownLogicalKeys.values) {
      logicalKeyIdList.addAll(item.map((e) => e.keyId).toList());
    }
    if (!logicalKeyIdList.contains(logicalKey.keyId)) return null;

    return _knownLogicalKeys.entries
        .firstWhere((entry) =>
            entry.value.map((e) => e.keyId).contains(logicalKey.keyId))
        .key;
  }

  LogicalKeyboardKey get logicalKey {
    return _knownLogicalKeys[this]!.first;
  }

  List<LogicalKeyboardKey> get logicalKeys {
    return _knownLogicalKeys[this]!;
  }

  String get stringValue => describeEnum(this);

  int get keyId {
    return logicalKey.keyId;
  }

  String get keyLabel {
    return _knownLogicalKeyLabels[this] ?? logicalKey.keyLabel;
  }
}
