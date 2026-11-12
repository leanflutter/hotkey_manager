import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

void _registerGlobalHotKey(HotKey hotKey, HotKeyHandler handler) {
  unawaited(
    hotKeyManager.register(hotKey, keyDownHandler: handler).catchError((
      Object error,
      StackTrace stack,
    ) {
      // Disposing or updating a widget can cancel its permission request.
      if (error is PlatformException &&
          error.code == 'registration_cancelled') {
        return;
      }
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'hotkey_manager',
          context: ErrorDescription('while registering a global shortcut'),
        ),
      );
    }),
  );
}

extension _SingleActivatorExtension on SingleActivator {
  HotKey _toHotKey() {
    List<HotKeyModifier> modifiers = [
      if (control) HotKeyModifier.control,
      if (shift) HotKeyModifier.shift,
      if (alt) HotKeyModifier.alt,
      if (meta) HotKeyModifier.meta,
    ];
    return HotKey(
      key: trigger,
      modifiers: modifiers,
      scope: HotKeyScope.system,
    );
  }
}

class GlobalShortcuts extends StatefulWidget {
  const GlobalShortcuts({
    super.key,
    required this.shortcuts,
    required this.child,
  });

  final Map<SingleActivator, Intent> shortcuts;

  final Widget child;

  @override
  State<GlobalShortcuts> createState() => _GlobalShortcutsState();
}

class _GlobalShortcutsState extends State<GlobalShortcuts> {
  final List<HotKey> _registeredHotKeys = [];
  final Map<String, SingleActivator> _activatorsById = {};

  @override
  void initState() {
    super.initState();
    _registerShortcuts();
  }

  void _registerShortcuts() {
    for (final entry in widget.shortcuts.entries) {
      final hotKey = entry.key._toHotKey();
      _registerGlobalHotKey(hotKey, _onKeyDown);
      _registeredHotKeys.add(hotKey);
      _activatorsById[hotKey.identifier] = entry.key;
    }
  }

  void _unregisterShortcuts() {
    for (final hotKey in _registeredHotKeys) {
      hotKeyManager.unregister(hotKey);
    }
    _registeredHotKeys.clear();
    _activatorsById.clear();
  }

  @override
  void didUpdateWidget(covariant GlobalShortcuts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shortcuts != widget.shortcuts) {
      _unregisterShortcuts();
      _registerShortcuts();
    }
  }

  @override
  void dispose() {
    _unregisterShortcuts();
    super.dispose();
  }

  void _onKeyDown(HotKey hotKey) {
    if (!mounted) return;
    final activator = _activatorsById[hotKey.identifier];
    final Intent? matchedIntent = widget.shortcuts[activator];
    if (matchedIntent != null) {
      final Action<Intent>? action = Actions.maybeFind<Intent>(
        context,
        intent: matchedIntent,
      );
      if (action != null) {
        final (bool enabled, Object? invokeResult) = Actions.of(context)
            .invokeActionIfEnabled(action, matchedIntent, context);
        if (enabled) {
          action.toKeyEventResult(matchedIntent, invokeResult);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class CallbackGlobalShortcuts extends StatefulWidget {
  const CallbackGlobalShortcuts({
    super.key,
    required this.bindings,
    required this.child,
  });

  final Map<SingleActivator, VoidCallback> bindings;

  final Widget child;

  @override
  State<CallbackGlobalShortcuts> createState() =>
      _CallbackGlobalShortcutsState();
}

class _CallbackGlobalShortcutsState extends State<CallbackGlobalShortcuts> {
  final List<HotKey> _registeredHotKeys = [];
  final Map<String, SingleActivator> _activatorsById = {};

  Map<SingleActivator, VoidCallback> get bindings => widget.bindings;

  @override
  void initState() {
    super.initState();
    _registerShortcuts();
  }

  void _registerShortcuts() {
    for (final entry in widget.bindings.entries) {
      final hotKey = entry.key._toHotKey();
      _registerGlobalHotKey(hotKey, _onKeyDown);
      _registeredHotKeys.add(hotKey);
      _activatorsById[hotKey.identifier] = entry.key;
    }
  }

  void _unregisterShortcuts() {
    for (final hotKey in _registeredHotKeys) {
      hotKeyManager.unregister(hotKey);
    }
    _registeredHotKeys.clear();
    _activatorsById.clear();
  }

  @override
  void didUpdateWidget(covariant CallbackGlobalShortcuts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bindings != widget.bindings) {
      _unregisterShortcuts();
      _registerShortcuts();
    }
  }

  @override
  void dispose() {
    _unregisterShortcuts();
    super.dispose();
  }

  void _onKeyDown(HotKey hotKey) {
    if (!mounted) return;
    final activator = _activatorsById[hotKey.identifier];
    bindings[activator]?.call();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
