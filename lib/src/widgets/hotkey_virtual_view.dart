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
        color: Theme.of(context).canvasColor,
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(3),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            offset: Offset(0.0, 1.0),
          ),
        ],
      ),
      child: Text(
        keyLabel,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyText2?.color,
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
          if (hotKey.keyCode != null)
            _VirtualKeyView(
              keyLabel: hotKey.keyCode!.keyLabel,
            ),
        ],
      ),
    );
  }
}
