import 'package:flutter/services.dart';
import 'package:json_annotation/json_annotation.dart';
// ignore: implementation_imports
import 'package:uni_platform/src/extensions/keyboard_key.dart';
import 'package:uuid/uuid.dart';

part 'hotkey.g.dart';

const _uuid = Uuid();

typedef HotKeyHandler = void Function(HotKey hotKey);

enum HotKeyScope {
  system,
  inapp,
}

@JsonSerializable(
  converters: [_KeyboardKeyConverter()],
)
class HotKey {
  HotKey({
    String? identifier,
    required this.key,
    this.modifiers,
    this.scope = HotKeyScope.system,
  }) : identifier = identifier ?? _uuid.v4();

  factory HotKey.fromJson(Map<String, dynamic> json) => _$HotKeyFromJson(json);

  final String identifier;
  final KeyboardKey key;
  final List<ModifierKey>? modifiers;
  final HotKeyScope scope;

  LogicalKeyboardKey get logicalKey {
    if (key is LogicalKeyboardKey) {
      return key as LogicalKeyboardKey;
    } else if (key is PhysicalKeyboardKey) {
      return (key as PhysicalKeyboardKey).logicalKey!;
    }
    throw PlatformException(
      code: 'invalid_keyboard_key',
      message: 'Invalid keyboard key',
    );
  }

  PhysicalKeyboardKey get physicalKey {
    if (key is PhysicalKeyboardKey) {
      return key as PhysicalKeyboardKey;
    } else if (key is LogicalKeyboardKey) {
      return (key as LogicalKeyboardKey).physicalKey!;
    }
    throw PlatformException(
      code: 'invalid_keyboard_key',
      message: 'Invalid keyboard key',
    );
  }

  @override
  String toString() {
    return '${modifiers?.map((e) => e.name).join('')}${key.hashCode}';
  }

  Map<String, dynamic> toJson() => _$HotKeyToJson(this);
}

// Convert KeyboardKey to/from Map<Object?, Object?>
class _KeyboardKeyConverter
    extends JsonConverter<KeyboardKey, Map<Object?, Object?>> {
  const _KeyboardKeyConverter();

  @override
  KeyboardKey fromJson(json) {
    final map = json.cast<String, dynamic>();
    int? keyId = map['keyId'];
    int? usageCode = map['usageCode'];
    if (keyId != null) {
      final logicalKey = LogicalKeyboardKey.findKeyByKeyId(keyId);
      if (logicalKey != null) {
        return logicalKey;
      }
    }
    if (usageCode != null) {
      final physicalKey = PhysicalKeyboardKey.findKeyByCode(usageCode);
      if (physicalKey != null) {
        return physicalKey;
      }
    }
    throw PlatformException(
      code: 'invalid_keyboard_key',
      message: 'Invalid keyboard key',
    );
  }

  @override
  Map<String, dynamic> toJson(KeyboardKey object) {
    int? keyId = object is LogicalKeyboardKey ? object.keyId : null;
    int? usageCode = object is PhysicalKeyboardKey ? object.usbHidUsage : null;
    return {
      'keyId': keyId,
      'usageCode': usageCode,
    }..removeWhere((key, value) => value == null);
  }
}
