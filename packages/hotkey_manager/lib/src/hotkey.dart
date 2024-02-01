import 'package:hotkey_manager/src/enums/key_code.dart';
import 'package:hotkey_manager/src/enums/key_modifier.dart';
import 'package:uuid/uuid.dart';

enum HotKeyScope {
  system,
  inapp,
}

class HotKey {
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
        (e) => e.name == json['scope'],
        orElse: () => HotKeyScope.system,
      ),
    );
  }

  KeyCode keyCode;
  List<KeyModifier>? modifiers;
  String identifier = const Uuid().v4();
  HotKeyScope scope = HotKeyScope.system;

  Map<String, dynamic> toJson() {
    return {
      'keyCode': keyCode.stringValue,
      'modifiers': modifiers?.map((e) => e.stringValue).toList() ?? [],
      'identifier': identifier,
      'scope': scope.name,
    };
  }

  @override
  String toString() {
    return '${modifiers?.map((e) => e.keyLabel).join('')}${keyCode.keyLabel}';
  }
}
