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
        let args:[String: Any] = call.arguments as! [String: Any]
        
        let keyCode = args["keyCode"] as! String
        let modifiers = args["modifiers"] as! Array<String>
        let identifier = args["identifier"] as! String
        
        self.hotKeyDict[identifier] = HotKey(
            key: Key.init(pluginKeyCode: keyCode)!,
            modifiers: NSEvent.ModifierFlags.init(pluginModifiers: modifiers)
        )
        self.hotKeyDict[identifier]!.keyDownHandler = {
            let arguments: NSDictionary = call.arguments as! NSDictionary
            self.channel.invokeMethod("onKeyDown", arguments: arguments, result: nil)
        }
        self.hotKeyDict[identifier]!.keyUpHandler = {
            let arguments: NSDictionary = call.arguments as! NSDictionary
            self.channel.invokeMethod("onKeyUp", arguments: arguments, result: nil)
        }
        result(true)
    }
    
    public func unregister(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args:[String: Any] = call.arguments as! [String: Any]
        
        let identifier = args["identifier"] as! String
        
        self.hotKeyDict[identifier] = nil;
        
        result(true)
    }
    
    public func unregisterAll(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        self.hotKeyDict.removeAll();
        result(true)
    }
}
