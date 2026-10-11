import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/src/hotkey.dart';
import 'package:hotkey_manager/src/hotkey_accelerator.dart';
import 'package:nativeapi/nativeapi.dart' as nativeapi;

/// Internal seam for testing registration failures and queued native events.
abstract class SystemHotKeyBackend {
  void Function(int id, bool isKeyDown)? onKeyEvent;
  int register(HotKey hotKey);
  void unregister(int id);
  void unregisterAll();
}

class NativeSystemHotKeyBackend extends SystemHotKeyBackend {
  static const _ownerPrefix = 'hotkey_manager:';
  final _manager = nativeapi.ShortcutManager.instance;
  final _shortcuts = <int, nativeapi.Shortcut>{};
  nativeapi.ListenerId? _listenerId;

  @override
  int register(HotKey hotKey) {
    final accelerator = hotKeyAccelerator(hotKey);
    _listenerId ??= _manager.addListener((event) {
      if (!_shortcuts.containsKey(event.shortcutId)) return;
      if (event is nativeapi.ShortcutActivatedEvent) {
        onKeyEvent?.call(event.shortcutId, true);
      } else if (event is nativeapi.ShortcutReleasedEvent) {
        onKeyEvent?.call(event.shortcutId, false);
      }
    });
    // Subscribe through the async event API: the native platform callback can
    // run on a UI thread other than the Dart isolate's thread.
    final shortcut = _manager.registerWithOptions(
      nativeapi.ShortcutOptions(
        accelerator: accelerator,
        description: '$_ownerPrefix${hotKey.identifier}',
        scope: nativeapi.ShortcutScope.global,
        enabled: true,
      ),
    );
    if (shortcut == null) {
      _removeListenerIfEmpty();
      throw PlatformException(
        code: 'register_failed',
        message:
            'Unable to register system hotkey $accelerator. '
            'It may be in use or unsupported on this platform.',
      );
    }
    final id = shortcut.id;
    _shortcuts[id] = shortcut;
    return id;
  }

  @override
  void unregister(int id) {
    final shortcut = _shortcuts[id];
    if (shortcut == null) return;
    _manager.unregisterWithId(id);
    _shortcuts.remove(id);
    shortcut.dispose();
    _removeListenerIfEmpty();
  }

  @override
  void unregisterAll() {
    // Only release registrations owned by this compatibility manager. Native
    // ShortcutManager callers in the same application keep their shortcuts.
    for (final id in _shortcuts.keys.toList()) {
      unregister(id);
    }
    if (kIsWeb) return;
    // The native singleton survives a Flutter hot restart. Reclaim this
    // package's registrations from the previous isolate as well.
    for (final shortcut in _manager.getAll()) {
      if (shortcut.description?.startsWith(_ownerPrefix) ?? false) {
        _manager.unregisterWithId(shortcut.id);
      }
      shortcut.dispose();
    }
  }

  void _removeListenerIfEmpty() {
    final listenerId = _listenerId;
    if (_shortcuts.isEmpty && listenerId != null) {
      _manager.removeListener(listenerId);
      _listenerId = null;
    }
  }
}
