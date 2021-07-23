import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

class _ListItem extends StatelessWidget {
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _ListItem({
    Key? key,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: BoxConstraints(minHeight: 48),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 8,
        ),
        alignment: Alignment.centerLeft,
        child: Column(
          children: [
            Row(
              children: [
                DefaultTextStyle(
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                  ),
                  child: title!,
                ),
                Expanded(child: Container()),
                if (trailing != null) SizedBox(height: 34, child: trailing),
              ],
            ),
            if (subtitle != null) Container(child: subtitle),
          ],
        ),
      ),
      onTap: this.onTap,
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HotKey _hotKey = HotKey(
    KeyCode.keyS,
    modifiers: [KeyModifier.meta, KeyModifier.alt],
  );

  @override
  void initState() {
    super.initState();
  }

  void _keyDownHandler() {
    print('keyDownHandler');
    BotToast.showText(text: 'onKeyDown+${_hotKey.toJson()}');
  }

  void _keyUpHandler() {
    print('keyUpHandler');
    BotToast.showText(text: 'onKeyUp+${_hotKey.toJson()}');
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      children: <Widget>[
        _ListItem(
          title: Text('register'),
          onTap: () async {
            await HotKeyManager.instance.register(
              _hotKey,
              keyDownHandler: _keyDownHandler,
              keyUpHandler: _keyUpHandler,
            );
          },
        ),
        _ListItem(
          title: Text('unregister'),
          onTap: () async {
            await HotKeyManager.instance.unregister(_hotKey);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugin example app'),
      ),
      body: _buildBody(context),
    );
  }
}
