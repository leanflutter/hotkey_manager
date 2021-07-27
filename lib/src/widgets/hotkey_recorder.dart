import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import './hotkey_virtual_view.dart';
import '../enums/key_code.dart';
import '../enums/key_modifier.dart';
import '../hotkey.dart';

class HotKeyRecorder extends StatefulWidget {
  @override
  _HotKeyRecorderState createState() => _HotKeyRecorderState();
}

class _HotKeyRecorderState extends State<HotKeyRecorder> {
  HotKey _hotKey = HotKey(KeyCode.none, modifiers: []);
  bool _recorded = false;
  Timer? _recordedTimer;

  @override
  void initState() {
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
    KeyModifier? keyModifier;

    keyCode = KeyCodeParser.fromLogicalKey(value.logicalKey);
    keyModifier = KeyModifierParser.fromLogicalKey(value.logicalKey);

    setState(() {
      if (_recorded) {
        _hotKey.keyCode = KeyCode.none;
        _hotKey.modifiers = [];
        _recorded = false;
      }

      if (keyModifier != null) {
        _hotKey.modifiers!.removeWhere((e) => e == keyModifier);
        _hotKey.modifiers!.add(keyModifier);
      } else if (keyCode != null) {
        _hotKey.keyCode = keyCode;
      }
    });
    if (_recordedTimer != null && _recordedTimer!.isActive) {
      _recordedTimer!.cancel();
    }
    _recordedTimer = Timer.periodic(Duration(milliseconds: 600), (timer) {
      _recordedTimer!.cancel();
      _recordedTimer = null;
      setState(() {
        _recorded = true;
      });
    });
    print(_hotKey.toJson());
  }

  @override
  Widget build(BuildContext context) {
    return HotKeyVirtualView(hotKey: _hotKey);
  }
}
