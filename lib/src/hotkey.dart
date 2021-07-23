import 'package:uuid/uuid.dart';

import './enums/key_code.dart';
import './enums/key_modifier.dart';

class HotKey {
  final KeyCode keyCode;
  final List<KeyModifier>? modifiers;
  String identifier = Uuid().v4();

  HotKey(
    this.keyCode, {
    this.modifiers,
    String? identifier,
  }) {
    if (identifier != null) this.identifier = identifier;
  }

  factory HotKey.fromJson(Map<String, dynamic> json) {
    return HotKey(
      json['keyCode'],
      modifiers: List<String>.from(json['modifiers'])
          .map((e) => KeyModifierParser.parse(e))
          .toList(),
      identifier: json['identifier'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'keyCode': keyCode.stringValue,
      'modifiers': modifiers?.map((e) => e.stringValue).toList(),
      'identifier': identifier,
    };
  }
}
