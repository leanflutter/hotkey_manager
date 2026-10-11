import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart' as hotkey;
import 'package:hotkey_manager_example/pages/home.dart';

class NativeShortcutsPage extends StatefulWidget {
  const NativeShortcutsPage({super.key});

  @override
  State<NativeShortcutsPage> createState() => _NativeShortcutsPageState();
}

class _NativeShortcutsPageState extends State<NativeShortcutsPage> {
  final _manager = hotkey.ShortcutManager.instance;
  hotkey.ListenerId? _listenerId;
  hotkey.Shortcut? _shortcut;
  String _status = kIsWeb
      ? 'System shortcuts require a desktop app.'
      : 'Register Ctrl + Alt + H, then try it in any app.';
  int _presses = 0;
  int _releases = 0;

  void _register() {
    _listenerId ??= _manager.addListener((event) {
      if (!mounted || event.shortcutId != _shortcut?.id) return;
      if (event is hotkey.ShortcutActivatedEvent) {
        setState(() => _presses++);
      } else if (event is hotkey.ShortcutReleasedEvent) {
        setState(() => _releases++);
      }
    });
    final shortcut = _manager.registerWithOptions(
      const hotkey.ShortcutOptions(
        accelerator: 'Ctrl+Alt+H',
        description: 'hotkey_manager native example',
        scope: hotkey.ShortcutScope.global,
        enabled: true,
      ),
    );
    setState(() {
      _shortcut = shortcut;
      _status = shortcut == null
          ? 'Unable to register this shortcut. It may already be in use.'
          : 'Registered Ctrl + Alt + H. Try it while another app has focus.';
    });
  }

  void _unregister() {
    final shortcut = _shortcut;
    if (shortcut != null) {
      _manager.unregisterWithId(shortcut.id);
      shortcut.dispose();
      _shortcut = null;
    }
  }

  @override
  void dispose() {
    _unregister();
    final listenerId = _listenerId;
    if (listenerId != null) _manager.removeListener(listenerId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hotkey Manager')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_status, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Text('Pressed: $_presses    Released: $_releases'),
              const SizedBox(height: 8),
              const Text('System release events are available on macOS.'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: kIsWeb
                    ? null
                    : _shortcut == null
                    ? _register
                    : () {
                        _unregister();
                        setState(() => _status = 'Shortcut unregistered.');
                      },
                child: Text(
                  _shortcut == null
                      ? 'Register shortcut'
                      : 'Unregister shortcut',
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const HomePage()),
                ),
                child: const Text('Open compatibility example'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
