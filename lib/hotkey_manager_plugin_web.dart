import 'dart:async';
// In order to *not* need this ignore, consider extracting the "web" version
// of your plugin as a separate package, instead of inlining it in the same
// package as the core of your plugin.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js' as js;

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// A web implementation of the HotkeyManager plugin.
class HotkeyManagerPlugin {
  static void registerWith(Registrar registrar) {
    final MethodChannel channel = MethodChannel(
      'hotkey_manager',
      const StandardMethodCodec(),
      registrar,
    );

    final pluginInstance = HotkeyManagerPlugin();
    pluginInstance._channel = channel;
    channel.setMethodCallHandler(pluginInstance.handleMethodCall);
  }

  MethodChannel? _channel;
  Stream<html.MessageEvent>? _stream;

  /// Handles method calls over the MethodChannel of this plugin.
  /// Note: Check the "federated" architecture for a new way of doing this:
  /// https://flutter.dev/go/federated-plugins
  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'register':
        return register(call);
      case 'unregister':
        return unregister(call);
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details:
              'hotkey_manager for web doesn\'t implement \'${call.method}\'',
        );
    }
  }

  Future<bool> register(MethodCall call) {
    Map<String, dynamic> args = Map<String, dynamic>.from(call.arguments);
    js.context.callMethod(
      'hotkeyManagerPluginRegister',
      [js.JsObject.jsify(args)],
    );

    if (_stream == null) {
      _stream = html.window.onMessage;
      _stream!.listen(
        (event) {
          Map<String, dynamic> eventData =
              Map<String, dynamic>.from(event.data);
          switch (eventData['eventType']) {
            case 'onKeyDown':
              _channel!.invokeMethod('onKeyDown', eventData['hotKey']);
              break;
            case 'onKeyUp':
              _channel!.invokeMethod('onKeyUp', eventData['hotKey']);
              break;
          }
          print(eventData);
        },
      );
    }

    return Future.value(true);
  }

  Future<bool> unregister(MethodCall call) {
    Map<String, dynamic> args = Map<String, dynamic>.from(call.arguments);
    js.context.callMethod(
      'hotkeyManagerPluginUnregister',
      [js.JsObject.jsify(args)],
    );
    return Future.value(true);
  }
}
