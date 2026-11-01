// A console FlutterEngine host: no windows, no OS input, no app activation.
// Loads the same AOT bundle/native asset that a release Flutter app uses.
#import <Cocoa/Cocoa.h>
#import <FlutterMacOS/FlutterMacOS.h>
#import <IOKit/hidsystem/IOLLEvent.h>
#include <iostream>

int main(int argc, const char** argv) {
  @autoreleasepool {
    if (argc < 2 || argc > 3) return 1;
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    auto* assets = [NSBundle bundleWithPath:[NSString stringWithUTF8String:argv[1]]];
    auto* project = [[FlutterDartProject alloc] initWithPrecompiledDartBundle:assets];
    project.dartEntrypointArguments = argc == 3 ? @[[NSString stringWithUTF8String:argv[2]]] : @[];
    auto* engine = [[FlutterEngine alloc] initWithName:@"hotkey-media-aot-probe" project:project allowHeadlessExecution:YES];
    __block bool finished = false;
    __block bool passed = false;
    auto* channel = [FlutterMethodChannel methodChannelWithName:@"hotkey_manager_example/media_probe"
                                                binaryMessenger:engine.binaryMessenger];
    [channel setMethodCallHandler:^(FlutterMethodCall* call, FlutterResult result) {
      if ([call.method isEqualToString:@"media"]) {
        const int code = [call.arguments[@"code"] intValue];
        const bool down = [call.arguments[@"down"] boolValue];
        const bool repeat = [call.arguments[@"repeat"] boolValue];
        const auto flags = static_cast<NSEventModifierFlags>([call.arguments[@"flags"] unsignedLongLongValue]);
        NSEvent* event = [NSEvent otherEventWithType:NSEventTypeSystemDefined location:NSZeroPoint modifierFlags:flags
            timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:0 context:nil
            subtype:NX_SUBTYPE_AUX_CONTROL_BUTTONS data1:(code << 16) | ((down ? NX_KEYDOWN : NX_KEYUP) << 8) | (repeat ? 1 : 0) data2:0];
        [NSApp sendEvent:event]; // Process-local AppKit dispatch, not CGEventPost.
        result(nil);
      } else if ([call.method isEqualToString:@"done"]) {
        passed = [call.arguments[@"passed"] boolValue];
        std::cout << "HOTKEY_MACOS_MEDIA_PROBE " << [call.arguments[@"json"] UTF8String] << std::endl;
        result(nil);
        dispatch_async(dispatch_get_main_queue(), ^{ finished = true; });
      } else result(FlutterMethodNotImplemented);
    }];
    if (![engine runWithEntrypoint:nil]) return 2;
    NSDate* deadline = [NSDate dateWithTimeIntervalSinceNow:30];
    while (!finished && deadline.timeIntervalSinceNow > 0)
      [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    [channel setMethodCallHandler:nil];
    [engine shutDownEngine];
    return finished && passed ? 0 : 3;
  }
}
