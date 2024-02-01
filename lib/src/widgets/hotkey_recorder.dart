import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hotkey_manager/src/enums/key_code.dart';
import 'package:hotkey_manager/src/enums/key_modifier.dart';
import 'package:hotkey_manager/src/hotkey.dart';
import 'package:hotkey_manager/src/widgets/hotkey_virtual_view.dart';

class HotKeyRecorder extends StatefulWidget {
  const HotKeyRecorder({
    super.key,
    this.initalHotKey,
    required this.onHotKeyRecorded,
  });

  final HotKey? initalHotKey;
  final ValueChanged<HotKey> onHotKeyRecorded;

  @override
  State<HotKeyRecorder> createState() => _HotKeyRecorderState();
}

class _HotKeyRecorderState extends State<HotKeyRecorder> {
  HotKey? _hotKey;

  @override
  void initState() {
    if (widget.initalHotKey != null) {
      _hotKey = widget.initalHotKey!;
    }
    RawKeyboard.instance.addListener(_handleRawKeyEvent);
    super.initState();
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(_handleRawKeyEvent);
    super.dispose();
  }

  _handleRawKeyEvent(RawKeyEvent value) {
    if (value is! RawKeyDownEvent) return;

    KeyCode? keyCode;
    List<KeyModifier>? keyModifiers;

    keyCode = KeyCode.values.firstWhereOrNull(
      (kc) {
        if (!value.isKeyPressed(kc.logicalKey)) return false;
        KeyModifier? keyModifier =
            KeyModifierParser.fromLogicalKey(kc.logicalKey);

        if (keyModifier != null &&
            value.data.isModifierPressed(keyModifier.modifierKey)) {
          return false;
        }

        return true;
      },
    );
    keyModifiers = KeyModifier.values
        .where((km) => value.data.isModifierPressed(km.modifierKey))
        .toList();

    if (keyCode != null) {
      _hotKey = HotKey(
        keyCode,
        modifiers: keyModifiers,
      );
      if (widget.initalHotKey != null) {
        _hotKey?.identifier = widget.initalHotKey!.identifier;
        _hotKey?.scope = widget.initalHotKey!.scope;
      }

      widget.onHotKeyRecorded(_hotKey!);

      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hotKey == null) {
      return Container();
    }
    return HotKeyVirtualView(hotKey: _hotKey!);
  }
}
