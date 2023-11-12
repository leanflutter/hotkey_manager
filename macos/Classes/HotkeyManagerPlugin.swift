import Cocoa
import FlutterMacOS
import HotKey
import Carbon

public class HotkeyManagerPlugin: NSObject, FlutterPlugin {
    var channel: FlutterMethodChannel!
    
    var hotKeyDict: Dictionary<String, HotKey> = [:]
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "hotkey_manager", binaryMessenger: registrar.messenger)
        let instance = HotkeyManagerPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "register":
            register(call, result: result)
            break
        case "unregister":
            unregister(call, result: result)
            break
        case "unregisterAll":
            unregisterAll(call, result: result)
            break
        default:
            result(FlutterMethodNotImplemented)
        }
    }

     public func register(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let keyCode = args["keyCode"] as? String,
              let modifiers = args["modifiers"] as? Array<String>,
              let identifier = args["identifier"] as? String else {
            result(
                FlutterError(
                    code: "INVALID_ARGUMENTS",
                    message: "Invalid arguments received for registering hotkey.",
                    details: "Expected 'keyCode', 'modifiers', and 'identifier' in arguments but received: \(call.arguments ?? "nil")"
                )
            )
            return
        }

        guard let key = Key.init(pluginKeyCode: keyCode) else {
            result(
                FlutterError(
                    code: "INVALID_KEY_CODE",
                    message: "Failed to initialize key with provided keyCode.",
                    details: "The keyCode '\(keyCode)' could not be converted into a valid Key. Ensure that the keyCode is valid and corresponds to a recognizable key."
                )
            )
            return
        }

        let hotKey = HotKey(
            key: key,
            modifiers: NSEvent.ModifierFlags.init(pluginModifiers: modifiers)
        )

        hotKey.keyDownHandler = {
            let arguments: NSDictionary = call.arguments as! NSDictionary
            self.channel.invokeMethod("onKeyDown", arguments: arguments, result: nil)
        }
        hotKey.keyUpHandler = {
            let arguments: NSDictionary = call.arguments as! NSDictionary
            self.channel.invokeMethod("onKeyUp", arguments: arguments, result: nil)
        }

        self.hotKeyDict[identifier] = hotKey
        result(true)
    }

    public func unregister(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let identifier = args["identifier"] as? String else {
            result(
                FlutterError(
                    code: "INVALID_ARGUMENTS",
                    message: "Failed to unregister hotkey. Missing or invalid 'identifier' argument.",
                    details: "Expected a valid 'identifier' but received: \(call.arguments ?? "nil")"
                )
            )
            return
        }
        
        self.hotKeyDict[identifier] = nil
        result(true)
    }

    public func unregisterAll(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        self.hotKeyDict.removeAll();
        result(true)
    }
}
