import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../enums/key_code.dart';
import '../enums/key_modifier.dart';
import '../hotkey.dart';
import './hotkey_virtual_view.dart';

class HotKeyRecorder extends StatefulWidget {
  final HotKey? initalHotKey;
  final ValueChanged<HotKey> onHotKeyRecorded;

  const HotKeyRecorder({
    Key? key,
    this.initalHotKey,
    required this.onHotKeyRecorded,
  }) : super(key: key);

  @override
  _HotKeyRecorderState createState() => _HotKeyRecorderState();
}

class _HotKeyRecorderState extends State<HotKeyRecorder> {
  HotKey? _hotKey;

  @override
  void initState() {
    if (widget.initalHotKey != null) {
      _hotKey = widget.initalHotKey!;
    }
    RawKeyboard.instance.addListener(this._handleRawKeyEvent);
    super.initState();
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(this._handleRawKeyEvent);
    super.dispose();
  }

  _handleRawKeyEvent(RawKeyEvent value) {
    if (!(value is RawKeyDownEvent)) return;
    if (Platform.isMacOS && value.character == null) return;

    KeyCode? keyCode;
    List<KeyModifier>? keyModifiers;

    keyCode = KeyCode.values.firstWhereOrNull(
      (kc) {
        if (Platform.isMacOS) {
          if (value.logicalKey != kc.logicalKey) return false;
        } else {
          if (!value.isKeyPressed(kc.logicalKey)) return false;
        }
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
