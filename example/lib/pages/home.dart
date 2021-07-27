import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:preference_list/preference_list.dart';

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
    return PreferenceList(
      children: <Widget>[
        PreferenceListSection(
          children: [
            PreferenceListItem(
              title: Text('register'),
              onTap: () async {
                await HotKeyManager.instance.register(
                  _hotKey,
                  keyDownHandler: _keyDownHandler,
                  keyUpHandler: _keyUpHandler,
                );
              },
            ),
            PreferenceListItem(
              title: Text('unregister'),
              onTap: () async {
                await HotKeyManager.instance.unregister(_hotKey);
              },
            ),
          ],
        ),
        Container(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 200,
                height: 60,
                margin: EdgeInsets.only(top: 20),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    HotKeyRecorder(),
                  ],
                ),
              ),
            ],
          ),
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
