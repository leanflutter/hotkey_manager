import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:hotkey_manager_example/widgets/record_hotkey_dialog.dart';
import 'package:preference_list/preference_list.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<HotKey> _registeredHotKeyList = [];

  void _keyDownHandler(HotKey hotKey) {
    String log = 'keyDown ${hotKey.debugName} (${hotKey.scope})';
    BotToast.showText(text: log);
    if (kDebugMode) {
      print(log);
    }
  }

  void _keyUpHandler(HotKey hotKey) {
    String log = 'keyUp   ${hotKey.debugName} (${hotKey.scope})';
    BotToast.showText(text: log);
    if (kDebugMode) {
      print(log);
    }
  }

  Future<void> _handleHotKeyRegister(HotKey hotKey) async {
    await hotKeyManager.register(
      hotKey,
      keyDownHandler: _keyDownHandler,
      keyUpHandler: _keyUpHandler,
    );
    setState(() {
      _registeredHotKeyList = hotKeyManager.registeredHotKeyList;
    });
  }

  Future<void> _handleHotKeyUnregister(HotKey hotKey) async {
    await hotKeyManager.unregister(hotKey);
    setState(() {
      _registeredHotKeyList = hotKeyManager.registeredHotKeyList;
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
          title: const Text('REGISTERED HOTKEY LIST'),
          children: [
            for (var registeredHotKey in _registeredHotKeyList)
              PreferenceListItem(
                padding: const EdgeInsets.all(12),
                title: Row(
                  children: [
                    HotKeyVirtualView(hotKey: registeredHotKey),
                    const SizedBox(width: 10),
                    Text(
                      registeredHotKey.scope.toString(),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                accessoryView: SizedBox(
                  width: 40,
                  height: 40,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Stack(
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
                await hotKeyManager.unregisterAll();
                _registeredHotKeyList = hotKeyManager.registeredHotKeyList;
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
