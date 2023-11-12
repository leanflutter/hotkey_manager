//
//  HotKeyExtension+Key.swift
//  hotkey_manager
//
//  Created by Lijy91 on 2021/7/23.
//

import HotKey

extension Key {
    public init?(pluginKeyCode: String) {
        switch pluginKeyCode {
        // MARK: - Letters
        case "keyA": self = .a
        case "keyB": self = .b
        case "keyC": self = .c
        case "keyD": self = .d
        case "keyE": self = .e
        case "keyF": self = .f
        case "keyG": self = .g
        case "keyH": self = .h
        case "keyI": self = .i
        case "keyJ": self = .j
        case "keyK": self = .k
        case "keyL": self = .l
        case "keyM": self = .m
        case "keyN": self = .n
        case "keyO": self = .o
        case "keyP": self = .p
        case "keyQ": self = .q
        case "keyR": self = .r
        case "keyS": self = .s
        case "keyT": self = .t
        case "keyU": self = .u
        case "keyV": self = .v
        case "keyW": self = .w
        case "keyX": self = .x
        case "keyY": self = .y
        case "keyZ": self = .z

        // MARK: - Numbers
        case "digit0": self = .zero
        case "digit1": self = .one
        case "digit2": self = .two
        case "digit3": self = .three
        case "digit4": self = .four
        case "digit5": self = .five
        case "digit6": self = .six
        case "digit7": self = .seven
        case "digit8": self = .eight
        case "digit9": self = .nine

        // MARK: - Symbols
        case "period": self = .period
        case "quote": self = .quote
        case "bracketRight": self = .rightBracket
        case "semicolon": self = .semicolon
        case "slash": self = .slash
        case "backslash": self = .backslash
        case "comma": self = .comma
        case "equal": self = .equal
        case "grave": self = .grave // Backtick
        case "bracketLeft": self = .leftBracket
        case "minus": self = .minus
            
        // MARK: - Whitespace
        case "space": self = .space
        case "tab": self = .tab
        case "enter": self = .return
            
        // MARK: - Modifiers
        case "meta": self = .command
        case "metaLeft": self = .command
        case "metaRight": self = .rightCommand
        case "alt": self = .option
        case "altLeft": self = .option
        case "altRight": self = .rightOption
        case "control": self = .control
        case "controlLeft": self = .control
        case "controlRight": self = .rightControl
        case "shift": self = .shift
        case "shiftLeft": self = .shift
        case "shiftRight": self = .rightShift
        case "fn": self = .function
        case "capsLock": self = .capsLock
            
        // MARK: - Navigation
        case "pageUp": self = .pageUp
        case "pageDown": self = .pageDown
        case "home": self = .home
        case "end": self = .end
        case "arrowUp": self = .upArrow
        case "arrowRight": self = .rightArrow
        case "arrowDown": self = .downArrow
        case "arrowLeft": self = .leftArrow
            
        // MARK: - Functions
        case "f1": self = .f1
        case "f2": self = .f2
        case "f3": self = .f3
        case "f4": self = .f4
        case "f5": self = .f5
        case "f6": self = .f6
        case "f7": self = .f7
        case "f8": self = .f8
        case "f9": self = .f9
        case "f10": self = .f10
        case "f11": self = .f11
        case "f12": self = .f12
        case "f13": self = .f13
        case "f14": self = .f14
        case "f15": self = .f15
        case "f16": self = .f16
        case "f17": self = .f17
        case "f18": self = .f18
        case "f19": self = .f19
        case "f20": self = .f20
            
        // MARK: - Keypad
        case "numpad0": self = .keypad0
        case "numpad1": self = .keypad1
        case "numpad2": self = .keypad2
        case "numpad3": self = .keypad3
        case "numpad4": self = .keypad4
        case "numpad5": self = .keypad5
        case "numpad6": self = .keypad6
        case "numpad7": self = .keypad7
        case "numpad8": self = .keypad8
        case "numpad9": self = .keypad9
        case "numpadClear": self = .keypadClear
        case "numpadDecimal": self = .keypadDecimal
        case "numpadDivide": self = .keypadDivide
        case "numpadEnter": self = .keypadEnter
        case "numpadEquals": self = .keypadEquals
        case "numpadMinus": self = .keypadMinus
        case "numpadMultiply": self = .keypadMultiply
        case "numpadAdd": self = .keypadPlus
            
        // MARK: - Misc
        case "escape": self = .escape
        case "delete": self = .delete
        case "backspace": self = .delete
        case "forwardDelete": self = .forwardDelete
        case "help": self = .help
        case "audioVolumeUp": self = .volumeUp
        case "audioVolumeDown": self = .volumeDown
        case "audioVolumeMute": self = .mute
        default: return nil
        }
    }
}
