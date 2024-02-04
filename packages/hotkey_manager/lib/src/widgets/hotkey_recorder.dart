import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/src/widgets/hotkey_virtual_view.dart';
import 'package:hotkey_manager_platform_interface/hotkey_manager_platform_interface.dart';

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
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    super.initState();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent keyEvent) {
    if (keyEvent is KeyUpEvent) return false;
    PhysicalKeyboardKey? key = keyEvent.physicalKey;
    List<ModifierKey>? pressedModifierKeys = ModifierKey.values
        .where((e) => e.isModifierPressed) // pressed modifier keys
        .toList();
    if (pressedModifierKeys.isNotEmpty) {
      // Remove the modifier keys from the list of pressed keys
      pressedModifierKeys = pressedModifierKeys
          .where((e) => !e.physicalKeys.contains(key)) // linewrap
          .toList();
    }
    _hotKey = HotKey(
      identifier: widget.initalHotKey?.identifier,
      key: key,
      modifiers: pressedModifierKeys,
      scope: widget.initalHotKey?.scope ?? HotKeyScope.system,
    );
    widget.onHotKeyRecorded(_hotKey!);
    setState(() {});
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_hotKey == null) {
      return Container();
    }
    return HotKeyVirtualView(hotKey: _hotKey!);
  }
}
