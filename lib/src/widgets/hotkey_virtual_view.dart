import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

class _VirtualKeyView extends StatelessWidget {
  final String keyLabel;

  const _VirtualKeyView({
    Key? key,
    required this.keyLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 5, right: 5, top: 3, bottom: 3),
      decoration: BoxDecoration(
        color: Color(0xfffafbfc),
        border: Border(
          left: BorderSide(color: const Color(0xffc6cbd1), width: 1),
          right: BorderSide(color: const Color(0xffc6cbd1), width: 1),
          top: BorderSide(color: const Color(0xffc6cbd1), width: 1),
          bottom: BorderSide(color: const Color(0xffc6cbd1), width: 1),
        ),
        // border: Border.all(color: Color(0xffc6cbd1), width: 1),
        borderRadius: BorderRadius.circular(3),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xff959da5),
            offset: Offset(0.0, 1.0),
          ),
        ],
      ),
      child: Text(
        keyLabel,
        style: TextStyle(
          fontSize: 12,
        ),
      ),
    );
  }
}

class HotKeyVirtualView extends StatelessWidget {
  final HotKey hotKey;

  const HotKeyVirtualView({
    Key? key,
    required this.hotKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Wrap(
        spacing: 8,
        children: [
          for (KeyModifier keyModifier in hotKey.modifiers ?? [])
            _VirtualKeyView(
              keyLabel: keyModifier.keyLabel,
            ),
          if (hotKey.keyCode != KeyCode.none)
            _VirtualKeyView(
              keyLabel: hotKey.keyCode.keyLabel,
            ),
        ],
      ),
    );
  }
}
