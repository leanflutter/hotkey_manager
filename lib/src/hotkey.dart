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
  HotKeyScope scope = HotKeyScope.system;

  HotKey(
    this.keyCode, {
    this.modifiers,
    String? identifier,
    HotKeyScope? scope,
  }) {
    if (identifier != null) this.identifier = identifier;
    if (scope != null) this.scope = scope;
  }

  factory HotKey.fromJson(Map<String, dynamic> json) {
    return HotKey(
      KeyCodeParser.parse(json['keyCode']),
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
      'modifiers': modifiers?.map((e) => e.stringValue).toList() ?? [],
      'identifier': identifier,
      'scope': describeEnum(scope),
    };
  }

  @override
  String toString() {
    return '${modifiers!.map((e) => e.keyLabel).join('')}${keyCode.keyLabel}';
  }
}
