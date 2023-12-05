import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

class KeyPressRecorder extends StatefulWidget {
  const KeyPressRecorder({
    Key? key,
    this.initalHotKey,
    required this.onHotKeyRecorded,
  }) : super(key: key);
  final HotKey? initalHotKey;
  final ValueChanged<HotKey> onHotKeyRecorded;

  @override
  State<KeyPressRecorder> createState() => _KeyPressRecorderState();
}

class _KeyPressRecorderState extends State<KeyPressRecorder> {
  HotKey? _hotKey;
  bool _toReset = false;
  final Set<KeyModifier> _keyModifiers = {};
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    if (widget.initalHotKey != null) {
      _hotKey = widget.initalHotKey!;
    }
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(KeyEvent keyEvent) {
    KeyCode keyCode = KeyCode.empty;
    KeyModifier? keyModifier =
        KeyModifierParser.fromLogicalKey(keyEvent.logicalKey);

    if (keyEvent is KeyDownEvent) {
      if (_toReset) {
        setState(() {
          _toReset = false;
          _hotKey = null;
          _keyModifiers.clear();
        });
      }

      // Only set keyCode if the key pressed is not a modifier key.
      // Because we don't want to display two modifier keys in the widget.
      if (keyModifier == null) {
        keyCode =
            KeyCodeParser.fromLogicalKey(keyEvent.logicalKey) ?? KeyCode.empty;
      } else {
        _keyModifiers.add(keyModifier);
      }
    } else if (keyEvent is KeyUpEvent) {
      if (keyModifier != null) {
        _keyModifiers.remove(keyModifier);
      }
    }

    // _hotkey is set in every key event so the widget display can respond
    // immediately to the user's input.
    _hotKey = HotKey(
      keyCode,
      modifiers: _keyModifiers.toList(),
    );

    // Remove the 'placeholder' empty block when no modifier keys are pressed.
    if (_keyModifiers.isEmpty && keyCode == KeyCode.empty) {
      _hotKey = null;
    }

    // We use non-modifier keys as the 'trigger key' for onHotKeyRecorded.
    if (keyCode != KeyCode.empty && _hotKey != null) {
      widget.onHotKeyRecorded(_hotKey!);
      _focusNode.unfocus();
    }

    setState(() {});

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional.center,
      children: [
        if (_hotKey == null)
          Container()
        else
          HotKeyVirtualView(hotKey: _hotKey!),
        Focus(
          onFocusChange: (hasFocus) {
            if (hasFocus) {
              _toReset = true;
            }
          },
          focusNode: _focusNode,
          onKeyEvent: (focusNode, keyEvent) {
            return _handleKeyEvent(keyEvent);
          },
          child: const TextField(
              cursorHeight: 0,
              cursorWidth: 0,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(10),
                isDense: true,
              )),
        ),
      ],
    );
  }
}
