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
  HotKey _hotKey = HotKey(KeyCode.none, modifiers: []);

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

    KeyCode keyCode = KeyCode.none;
    List<KeyModifier>? keyModifiers;

    keyCode = KeyCode.values.firstWhere(
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
      orElse: () => KeyCode.none,
    );
    keyModifiers = KeyModifier.values
        .where((km) => value.data.isModifierPressed(km.modifierKey))
        .toList();
    _hotKey.keyCode = keyCode;
    _hotKey.modifiers = keyModifiers;

    if (!_hotKey.isSetted) return;

    widget.onHotKeyRecorded(_hotKey);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return HotKeyVirtualView(hotKey: _hotKey);
  }
}
