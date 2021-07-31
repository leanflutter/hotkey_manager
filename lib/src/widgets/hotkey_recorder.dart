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
    KeyCode? keyCode;
    List<KeyModifier>? keyModifiers;

    try {
      keyCode = KeyCode.values.firstWhere(
        (kc) =>
            value.isKeyPressed(kc.logicalKey) &&
            KeyModifier.values
                .every((km) => !km.logicalKeys.contains(kc.logicalKey)),
      );
    } catch (error) {
      //skip
    }
    keyModifiers = KeyModifier.values
        .where((km) =>
            km.logicalKeys.map((lk) => value.isKeyPressed(lk)).contains(true))
        .toList();
    _hotKey.keyCode = keyCode ?? KeyCode.none;
    _hotKey.modifiers = keyModifiers;

    widget.onHotKeyRecorded(_hotKey);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return HotKeyVirtualView(hotKey: _hotKey);
  }
}
