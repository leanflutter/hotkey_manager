import 'package:flutter/foundation.dart' show describeEnum;
import 'package:flutter/services.dart';

const Map<KeyModifier, LogicalKeyboardKey> _knownLogicalKeys =
    <KeyModifier, LogicalKeyboardKey>{
  KeyModifier.capsLock: LogicalKeyboardKey.capsLock,
  KeyModifier.shift: LogicalKeyboardKey.shift,
  KeyModifier.control: LogicalKeyboardKey.control,
  KeyModifier.alt: LogicalKeyboardKey.alt,
  KeyModifier.meta: LogicalKeyboardKey.meta,
  KeyModifier.fn: LogicalKeyboardKey.fn,
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

  static KeyModifier fromLogicalKey(LogicalKeyboardKey logicalKey) {
    return _knownLogicalKeys.entries
        .firstWhere((entry) => entry.value.keyId == logicalKey.keyId)
        .key;
  }

  LogicalKeyboardKey get logicalKey {
    return _knownLogicalKeys[this]!;
  }

  String get stringValue => describeEnum(this);
}
