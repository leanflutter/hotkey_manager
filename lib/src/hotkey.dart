import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show describeEnum;

import './enums/key_code.dart';
import './enums/key_modifier.dart';

enum HotKeyScope {
  system,
  inapp,
}

class HotKey {
  KeyCode keyCode;
  List<KeyModifier>? modifiers;
  String identifier = Uuid().v4();
  HotKeyScope scope;

  bool get isSetted => keyCode != KeyCode.none;

  HotKey(
    this.keyCode, {
    this.modifiers,
    String? identifier,
    this.scope = HotKeyScope.system,
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
      scope: HotKeyScope.values.firstWhere(
        (e) => describeEnum(e) == json['scope'],
        orElse: () => HotKeyScope.system,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'keyCode': keyCode.stringValue,
      'modifiers': modifiers?.map((e) => e.stringValue).toList(),
      'identifier': identifier,
      'scope': describeEnum(scope),
    };
  }

  @override
  String toString() {
    return '${modifiers!.map((e) => e.keyLabel).join('+')}${modifiers!.length > 0 ? '+' : ''}${keyCode.keyLabel}';
  }
}
