//
//  HotKeyExtension+NSEventModifierFlags.swift
//  hotkey_manager
//
//  Created by Lijy91 on 2021/7/23.
//

extension NSEvent.ModifierFlags {
    public init(pluginModifiers: Array<String>) {
        self.init()
        if (pluginModifiers.contains("capsLockModifier")) {
            insert(.capsLock)
        }
        if (pluginModifiers.contains("shiftModifier")) {
            insert(.shift)
        }
        if (pluginModifiers.contains("controlModifier")) {
            insert(.control)
        }
        if (pluginModifiers.contains("altModifier")) {
            insert(.option)
        }
        if (pluginModifiers.contains("metaModifier")) {
            insert(.command)
        }
        if (pluginModifiers.contains("functionModifier")) {
            insert(.function)
        }
    }
}
