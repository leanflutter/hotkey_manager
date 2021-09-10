import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:preference_list/preference_list.dart';

import '../widgets/record_hotkey_dialog.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<HotKey> _registeredHotKeyList = [];

  @override
  void initState() {
    super.initState();
    HotKeyManager.instance.unregisterAll();
  }

  void _keyDownHandler(HotKey hotKey) {
    String log = 'keyDown ${hotKey.toString()} (${hotKey.scope})';
    BotToast.showText(text: log);
    print(log);
  }

  void _keyUpHandler(HotKey hotKey) {
    String log = 'keyUp   ${hotKey.toString()} (${hotKey.scope})';
    BotToast.showText(text: log);
    print(log);
  }

  void _handleHotKeyRegister(HotKey hotKey) async {
    await HotKeyManager.instance.register(
      hotKey,
      keyDownHandler: _keyDownHandler,
      keyUpHandler: _keyUpHandler,
    );
    setState(() {
      _registeredHotKeyList = HotKeyManager.instance.registeredHotKeyList;
    });
  }

  void _handleHotKeyUnregister(HotKey hotKey) async {
    await HotKeyManager.instance.unregister(hotKey);
    setState(() {
      _registeredHotKeyList = HotKeyManager.instance.registeredHotKeyList;
    });
  }

  Future<void> _handleClickRegisterNewHotKey() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return RecordHotKeyDialog(
          onHotKeyRecorded: (newHotKey) => _handleHotKeyRegister(newHotKey),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    return PreferenceList(
      children: <Widget>[
        PreferenceListSection(
          title: Text('REGISTERED HOTKEY LIST'),
          children: [
            for (var registeredHotKey in _registeredHotKeyList)
              PreferenceListItem(
                padding: EdgeInsets.all(12),
                title: Row(
                  children: [
                    HotKeyVirtualView(hotKey: registeredHotKey),
                    SizedBox(width: 10),
                    Text(
                      registeredHotKey.scope.toString(),
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                accessoryView: Container(
                  width: 40,
                  height: 40,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.delete,
                          size: 18,
                          color: Colors.red,
                        ),
                      ],
                    ),
                    onPressed: () => _handleHotKeyUnregister(registeredHotKey),
                  ),
                ),
              ),
            PreferenceListItem(
              title: Text(
                'Register a new HotKey',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                ),
              ),
              accessoryView: Container(),
              onTap: () {
                _handleClickRegisterNewHotKey();
              },
            ),
          ],
        ),
        PreferenceListSection(
          children: [
            PreferenceListItem(
              title: Text(
                'Unregister all HotKeys',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                ),
              ),
              accessoryView: Container(),
              onTap: () async {
                await HotKeyManager.instance.unregisterAll();
                _registeredHotKeyList =
                    HotKeyManager.instance.registeredHotKeyList;
                setState(() {});
              },
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Example'),
      ),
      body: _buildBody(context),
    );
  }
}
