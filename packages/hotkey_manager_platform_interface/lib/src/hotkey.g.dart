// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hotkey.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HotKey _$HotKeyFromJson(Map<String, dynamic> json) => HotKey(
      identifier: json['identifier'] as String?,
      key: const _KeyboardKeyConverter().fromJson(json['key'] as Map),
      modifiers: (json['modifiers'] as List<dynamic>?)
          ?.map((e) => $enumDecode(_$ModifierKeyEnumMap, e))
          .toList(),
      scope: $enumDecodeNullable(_$HotKeyScopeEnumMap, json['scope']) ??
          HotKeyScope.system,
    );

Map<String, dynamic> _$HotKeyToJson(HotKey instance) => <String, dynamic>{
      'identifier': instance.identifier,
      'key': const _KeyboardKeyConverter().toJson(instance.key),
      'modifiers':
          instance.modifiers?.map((e) => _$ModifierKeyEnumMap[e]!).toList(),
      'scope': _$HotKeyScopeEnumMap[instance.scope]!,
    };

const _$ModifierKeyEnumMap = {
  ModifierKey.controlModifier: 'controlModifier',
  ModifierKey.shiftModifier: 'shiftModifier',
  ModifierKey.altModifier: 'altModifier',
  ModifierKey.metaModifier: 'metaModifier',
  ModifierKey.capsLockModifier: 'capsLockModifier',
  ModifierKey.numLockModifier: 'numLockModifier',
  ModifierKey.scrollLockModifier: 'scrollLockModifier',
  ModifierKey.functionModifier: 'functionModifier',
  ModifierKey.symbolModifier: 'symbolModifier',
};

const _$HotKeyScopeEnumMap = {
  HotKeyScope.system: 'system',
  HotKeyScope.inapp: 'inapp',
};
