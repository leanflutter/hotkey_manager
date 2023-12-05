import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const Map<KeyCode, LogicalKeyboardKey> _knownLogicalKeys =
    <KeyCode, LogicalKeyboardKey>{
  // KeyCode.none: LogicalKeyboardKey.none,
  KeyCode.hyper: LogicalKeyboardKey.hyper,
  KeyCode.superKey: LogicalKeyboardKey.superKey,
  KeyCode.fnLock: LogicalKeyboardKey.fnLock,
  KeyCode.suspend: LogicalKeyboardKey.suspend,
  KeyCode.resume: LogicalKeyboardKey.resume,
  // KeyCode.turbo: LogicalKeyboardKey.turbo,
  // KeyCode.privacyScreenToggle: LogicalKeyboardKey.privacyScreenToggle,
  KeyCode.sleep: LogicalKeyboardKey.sleep,
  KeyCode.wakeUp: LogicalKeyboardKey.wakeUp,
  // KeyCode.displayToggleIntExt: LogicalKeyboardKey.displayToggleIntExt,
  // KeyCode.usbReserved: LogicalKeyboardKey.usbReserved,
  // KeyCode.usbErrorRollOver: LogicalKeyboardKey.usbErrorRollOver,
  // KeyCode.usbPostFail: LogicalKeyboardKey.usbPostFail,
  // KeyCode.usbErrorUndefined: LogicalKeyboardKey.usbErrorUndefined,
  KeyCode.keyA: LogicalKeyboardKey.keyA,
  KeyCode.keyB: LogicalKeyboardKey.keyB,
  KeyCode.keyC: LogicalKeyboardKey.keyC,
  KeyCode.keyD: LogicalKeyboardKey.keyD,
  KeyCode.keyE: LogicalKeyboardKey.keyE,
  KeyCode.keyF: LogicalKeyboardKey.keyF,
  KeyCode.keyG: LogicalKeyboardKey.keyG,
  KeyCode.keyH: LogicalKeyboardKey.keyH,
  KeyCode.keyI: LogicalKeyboardKey.keyI,
  KeyCode.keyJ: LogicalKeyboardKey.keyJ,
  KeyCode.keyK: LogicalKeyboardKey.keyK,
  KeyCode.keyL: LogicalKeyboardKey.keyL,
  KeyCode.keyM: LogicalKeyboardKey.keyM,
  KeyCode.keyN: LogicalKeyboardKey.keyN,
  KeyCode.keyO: LogicalKeyboardKey.keyO,
  KeyCode.keyP: LogicalKeyboardKey.keyP,
  KeyCode.keyQ: LogicalKeyboardKey.keyQ,
  KeyCode.keyR: LogicalKeyboardKey.keyR,
  KeyCode.keyS: LogicalKeyboardKey.keyS,
  KeyCode.keyT: LogicalKeyboardKey.keyT,
  KeyCode.keyU: LogicalKeyboardKey.keyU,
  KeyCode.keyV: LogicalKeyboardKey.keyV,
  KeyCode.keyW: LogicalKeyboardKey.keyW,
  KeyCode.keyX: LogicalKeyboardKey.keyX,
  KeyCode.keyY: LogicalKeyboardKey.keyY,
  KeyCode.keyZ: LogicalKeyboardKey.keyZ,
  KeyCode.digit1: LogicalKeyboardKey.digit1,
  KeyCode.digit2: LogicalKeyboardKey.digit2,
  KeyCode.digit3: LogicalKeyboardKey.digit3,
  KeyCode.digit4: LogicalKeyboardKey.digit4,
  KeyCode.digit5: LogicalKeyboardKey.digit5,
  KeyCode.digit6: LogicalKeyboardKey.digit6,
  KeyCode.digit7: LogicalKeyboardKey.digit7,
  KeyCode.digit8: LogicalKeyboardKey.digit8,
  KeyCode.digit9: LogicalKeyboardKey.digit9,
  KeyCode.digit0: LogicalKeyboardKey.digit0,
  KeyCode.enter: LogicalKeyboardKey.enter,
  KeyCode.escape: LogicalKeyboardKey.escape,
  KeyCode.backspace: LogicalKeyboardKey.backspace,
  KeyCode.tab: LogicalKeyboardKey.tab,
  KeyCode.space: LogicalKeyboardKey.space,
  KeyCode.minus: LogicalKeyboardKey.minus,
  KeyCode.numberSign: LogicalKeyboardKey.numberSign,
  KeyCode.multiply: LogicalKeyboardKey.asterisk,
  KeyCode.add: LogicalKeyboardKey.add,
  KeyCode.equal: LogicalKeyboardKey.equal,
  KeyCode.bracketLeft: LogicalKeyboardKey.bracketLeft,
  KeyCode.bracketRight: LogicalKeyboardKey.bracketRight,
  KeyCode.backslash: LogicalKeyboardKey.backslash,
  KeyCode.semicolon: LogicalKeyboardKey.semicolon,
  KeyCode.quote: LogicalKeyboardKey.quote,
  KeyCode.backquote: LogicalKeyboardKey.backquote,
  KeyCode.comma: LogicalKeyboardKey.comma,
  KeyCode.period: LogicalKeyboardKey.period,
  KeyCode.slash: LogicalKeyboardKey.slash,
  KeyCode.capsLock: LogicalKeyboardKey.capsLock,
  KeyCode.f1: LogicalKeyboardKey.f1,
  KeyCode.f2: LogicalKeyboardKey.f2,
  KeyCode.f3: LogicalKeyboardKey.f3,
  KeyCode.f4: LogicalKeyboardKey.f4,
  KeyCode.f5: LogicalKeyboardKey.f5,
  KeyCode.f6: LogicalKeyboardKey.f6,
  KeyCode.f7: LogicalKeyboardKey.f7,
  KeyCode.f8: LogicalKeyboardKey.f8,
  KeyCode.f9: LogicalKeyboardKey.f9,
  KeyCode.f10: LogicalKeyboardKey.f10,
  KeyCode.f11: LogicalKeyboardKey.f11,
  KeyCode.f12: LogicalKeyboardKey.f12,
  KeyCode.printScreen: LogicalKeyboardKey.printScreen,
  KeyCode.scrollLock: LogicalKeyboardKey.scrollLock,
  KeyCode.pause: LogicalKeyboardKey.pause,
  KeyCode.insert: LogicalKeyboardKey.insert,
  KeyCode.home: LogicalKeyboardKey.home,
  KeyCode.pageUp: LogicalKeyboardKey.pageUp,
  KeyCode.delete: LogicalKeyboardKey.delete,
  KeyCode.end: LogicalKeyboardKey.end,
  KeyCode.pageDown: LogicalKeyboardKey.pageDown,
  KeyCode.arrowRight: LogicalKeyboardKey.arrowRight,
  KeyCode.arrowLeft: LogicalKeyboardKey.arrowLeft,
  KeyCode.arrowDown: LogicalKeyboardKey.arrowDown,
  KeyCode.arrowUp: LogicalKeyboardKey.arrowUp,
  KeyCode.numLock: LogicalKeyboardKey.numLock,
  KeyCode.numpadDivide: LogicalKeyboardKey.numpadDivide,
  KeyCode.numpadMultiply: LogicalKeyboardKey.numpadMultiply,
  KeyCode.numpadSubtract: LogicalKeyboardKey.numpadSubtract,
  KeyCode.numpadAdd: LogicalKeyboardKey.numpadAdd,
  KeyCode.numpadEnter: LogicalKeyboardKey.numpadEnter,
  KeyCode.numpad1: LogicalKeyboardKey.numpad1,
  KeyCode.numpad2: LogicalKeyboardKey.numpad2,
  KeyCode.numpad3: LogicalKeyboardKey.numpad3,
  KeyCode.numpad4: LogicalKeyboardKey.numpad4,
  KeyCode.numpad5: LogicalKeyboardKey.numpad5,
  KeyCode.numpad6: LogicalKeyboardKey.numpad6,
  KeyCode.numpad7: LogicalKeyboardKey.numpad7,
  KeyCode.numpad8: LogicalKeyboardKey.numpad8,
  KeyCode.numpad9: LogicalKeyboardKey.numpad9,
  KeyCode.numpad0: LogicalKeyboardKey.numpad0,
  KeyCode.numpadDecimal: LogicalKeyboardKey.numpadDecimal,
  KeyCode.intlBackslash: LogicalKeyboardKey.intlBackslash,
  KeyCode.contextMenu: LogicalKeyboardKey.contextMenu,
  KeyCode.power: LogicalKeyboardKey.power,
  KeyCode.numpadEqual: LogicalKeyboardKey.numpadEqual,
  KeyCode.f13: LogicalKeyboardKey.f13,
  KeyCode.f14: LogicalKeyboardKey.f14,
  KeyCode.f15: LogicalKeyboardKey.f15,
  KeyCode.f16: LogicalKeyboardKey.f16,
  KeyCode.f17: LogicalKeyboardKey.f17,
  KeyCode.f18: LogicalKeyboardKey.f18,
  KeyCode.f19: LogicalKeyboardKey.f19,
  KeyCode.f20: LogicalKeyboardKey.f20,
  KeyCode.f21: LogicalKeyboardKey.f21,
  KeyCode.f22: LogicalKeyboardKey.f22,
  KeyCode.f23: LogicalKeyboardKey.f23,
  KeyCode.f24: LogicalKeyboardKey.f24,
  KeyCode.open: LogicalKeyboardKey.open,
  KeyCode.help: LogicalKeyboardKey.help,
  KeyCode.select: LogicalKeyboardKey.select,
  KeyCode.again: LogicalKeyboardKey.again,
  KeyCode.undo: LogicalKeyboardKey.undo,
  KeyCode.cut: LogicalKeyboardKey.cut,
  KeyCode.copy: LogicalKeyboardKey.copy,
  KeyCode.paste: LogicalKeyboardKey.paste,
  KeyCode.find: LogicalKeyboardKey.find,
  KeyCode.audioVolumeMute: LogicalKeyboardKey.audioVolumeMute,
  KeyCode.audioVolumeUp: LogicalKeyboardKey.audioVolumeUp,
  KeyCode.audioVolumeDown: LogicalKeyboardKey.audioVolumeDown,
  KeyCode.numpadComma: LogicalKeyboardKey.numpadComma,
  KeyCode.intlRo: LogicalKeyboardKey.intlRo,
  KeyCode.kanaMode: LogicalKeyboardKey.kanaMode,
  KeyCode.intlYen: LogicalKeyboardKey.intlYen,
  KeyCode.convert: LogicalKeyboardKey.convert,
  KeyCode.nonConvert: LogicalKeyboardKey.nonConvert,
  KeyCode.lang1: LogicalKeyboardKey.lang1,
  KeyCode.lang2: LogicalKeyboardKey.lang2,
  KeyCode.lang3: LogicalKeyboardKey.lang3,
  KeyCode.lang4: LogicalKeyboardKey.lang4,
  KeyCode.lang5: LogicalKeyboardKey.lang5,
  KeyCode.abort: LogicalKeyboardKey.abort,
  KeyCode.props: LogicalKeyboardKey.props,
  KeyCode.numpadParenLeft: LogicalKeyboardKey.numpadParenLeft,
  KeyCode.numpadParenRight: LogicalKeyboardKey.numpadParenRight,
  // KeyCode.numpadBackspace: LogicalKeyboardKey.numpadBackspace,
  // KeyCode.numpadMemoryStore: LogicalKeyboardKey.numpadMemoryStore,
  // KeyCode.numpadMemoryRecall: LogicalKeyboardKey.numpadMemoryRecall,
  // KeyCode.numpadMemoryClear: LogicalKeyboardKey.numpadMemoryClear,
  // KeyCode.numpadMemoryAdd: LogicalKeyboardKey.numpadMemoryAdd,
  // KeyCode.numpadMemorySubtract: LogicalKeyboardKey.numpadMemorySubtract,
  // KeyCode.numpadSignChange: LogicalKeyboardKey.numpadSignChange,
  // KeyCode.numpadClear: LogicalKeyboardKey.numpadClear,
  // KeyCode.numpadClearEntry: LogicalKeyboardKey.numpadClearEntry,
  KeyCode.controlLeft: LogicalKeyboardKey.controlLeft,
  KeyCode.shiftLeft: LogicalKeyboardKey.shiftLeft,
  KeyCode.altLeft: LogicalKeyboardKey.altLeft,
  KeyCode.metaLeft: LogicalKeyboardKey.metaLeft,
  KeyCode.controlRight: LogicalKeyboardKey.controlRight,
  KeyCode.shiftRight: LogicalKeyboardKey.shiftRight,
  KeyCode.altRight: LogicalKeyboardKey.altRight,
  KeyCode.metaRight: LogicalKeyboardKey.metaRight,
  KeyCode.info: LogicalKeyboardKey.info,
  KeyCode.closedCaptionToggle: LogicalKeyboardKey.closedCaptionToggle,
  KeyCode.brightnessUp: LogicalKeyboardKey.brightnessUp,
  KeyCode.brightnessDown: LogicalKeyboardKey.brightnessDown,
  // KeyCode.brightnessToggle: LogicalKeyboardKey.brightnessToggle,
  // KeyCode.brightnessMinimum: LogicalKeyboardKey.brightnessMinimum,
  // KeyCode.brightnessMaximum: LogicalKeyboardKey.brightnessMaximum,
  // KeyCode.brightnessAuto: LogicalKeyboardKey.brightnessAuto,
  // KeyCode.kbdIllumUp: LogicalKeyboardKey.kbdIllumUp,
  // KeyCode.kbdIllumDown: LogicalKeyboardKey.kbdIllumDown,
  KeyCode.mediaLast: LogicalKeyboardKey.mediaLast,
  KeyCode.launchPhone: LogicalKeyboardKey.launchPhone,
  // KeyCode.programGuide: LogicalKeyboardKey.programGuide,
  KeyCode.exit: LogicalKeyboardKey.exit,
  KeyCode.channelUp: LogicalKeyboardKey.channelUp,
  KeyCode.channelDown: LogicalKeyboardKey.channelDown,
  KeyCode.mediaPlay: LogicalKeyboardKey.mediaPlay,
  KeyCode.mediaPause: LogicalKeyboardKey.mediaPause,
  KeyCode.mediaRecord: LogicalKeyboardKey.mediaRecord,
  KeyCode.mediaFastForward: LogicalKeyboardKey.mediaFastForward,
  KeyCode.mediaRewind: LogicalKeyboardKey.mediaRewind,
  KeyCode.mediaTrackNext: LogicalKeyboardKey.mediaTrackNext,
  KeyCode.mediaTrackPrevious: LogicalKeyboardKey.mediaTrackPrevious,
  KeyCode.mediaStop: LogicalKeyboardKey.mediaStop,
  KeyCode.eject: LogicalKeyboardKey.eject,
  KeyCode.mediaPlayPause: LogicalKeyboardKey.mediaPlayPause,
  KeyCode.speechInputToggle: LogicalKeyboardKey.speechInputToggle,
  // KeyCode.bassBoost: LogicalKeyboardKey.bassBoost,
  // KeyCode.mediaSelect: LogicalKeyboardKey.mediaSelect,
  KeyCode.launchWordProcessor: LogicalKeyboardKey.launchWordProcessor,
  KeyCode.launchSpreadsheet: LogicalKeyboardKey.launchSpreadsheet,
  KeyCode.launchMail: LogicalKeyboardKey.launchMail,
  KeyCode.launchContacts: LogicalKeyboardKey.launchContacts,
  KeyCode.launchCalendar: LogicalKeyboardKey.launchCalendar,
  // KeyCode.launchApp2: LogicalKeyboardKey.launchApp2,
  // KeyCode.launchApp1: LogicalKeyboardKey.launchApp1,
  // KeyCode.launchInternetBrowser: LogicalKeyboardKey.launchInternetBrowser,
  KeyCode.logOff: LogicalKeyboardKey.logOff,
  // KeyCode.lockScreen: LogicalKeyboardKey.lockScreen,
  KeyCode.launchControlPanel: LogicalKeyboardKey.launchControlPanel,
  // KeyCode.selectTask: LogicalKeyboardKey.selectTask,
  // KeyCode.launchDocuments: LogicalKeyboardKey.launchDocuments,
  KeyCode.spellCheck: LogicalKeyboardKey.spellCheck,
  // KeyCode.launchKeyboardLayout: LogicalKeyboardKey.launchKeyboardLayout,
  KeyCode.launchScreenSaver: LogicalKeyboardKey.launchScreenSaver,
  KeyCode.launchAssistant: LogicalKeyboardKey.launchAssistant,
  // KeyCode.launchAudioBrowser: LogicalKeyboardKey.launchAudioBrowser,
  KeyCode.newKey: LogicalKeyboardKey.newKey,
  KeyCode.close: LogicalKeyboardKey.close,
  KeyCode.save: LogicalKeyboardKey.save,
  KeyCode.print: LogicalKeyboardKey.print,
  KeyCode.browserSearch: LogicalKeyboardKey.browserSearch,
  KeyCode.browserHome: LogicalKeyboardKey.browserHome,
  KeyCode.browserBack: LogicalKeyboardKey.browserBack,
  KeyCode.browserForward: LogicalKeyboardKey.browserForward,
  KeyCode.browserStop: LogicalKeyboardKey.browserStop,
  KeyCode.browserRefresh: LogicalKeyboardKey.browserRefresh,
  KeyCode.browserFavorites: LogicalKeyboardKey.browserFavorites,
  KeyCode.zoomIn: LogicalKeyboardKey.zoomIn,
  KeyCode.zoomOut: LogicalKeyboardKey.zoomOut,
  KeyCode.zoomToggle: LogicalKeyboardKey.zoomToggle,
  KeyCode.redo: LogicalKeyboardKey.redo,
  KeyCode.mailReply: LogicalKeyboardKey.mailReply,
  KeyCode.mailForward: LogicalKeyboardKey.mailForward,
  KeyCode.mailSend: LogicalKeyboardKey.mailSend,
  // KeyCode.keyboardLayoutSelect: LogicalKeyboardKey.keyboardLayoutSelect,
  // KeyCode.showAllWindows: LogicalKeyboardKey.showAllWindows,
  KeyCode.gameButton1: LogicalKeyboardKey.gameButton1,
  KeyCode.gameButton2: LogicalKeyboardKey.gameButton2,
  KeyCode.gameButton3: LogicalKeyboardKey.gameButton3,
  KeyCode.gameButton4: LogicalKeyboardKey.gameButton4,
  KeyCode.gameButton5: LogicalKeyboardKey.gameButton5,
  KeyCode.gameButton6: LogicalKeyboardKey.gameButton6,
  KeyCode.gameButton7: LogicalKeyboardKey.gameButton7,
  KeyCode.gameButton8: LogicalKeyboardKey.gameButton8,
  KeyCode.gameButton9: LogicalKeyboardKey.gameButton9,
  KeyCode.gameButton10: LogicalKeyboardKey.gameButton10,
  KeyCode.gameButton11: LogicalKeyboardKey.gameButton11,
  KeyCode.gameButton12: LogicalKeyboardKey.gameButton12,
  KeyCode.gameButton13: LogicalKeyboardKey.gameButton13,
  KeyCode.gameButton14: LogicalKeyboardKey.gameButton14,
  KeyCode.gameButton15: LogicalKeyboardKey.gameButton15,
  KeyCode.gameButton16: LogicalKeyboardKey.gameButton16,
  KeyCode.gameButtonA: LogicalKeyboardKey.gameButtonA,
  KeyCode.gameButtonB: LogicalKeyboardKey.gameButtonB,
  KeyCode.gameButtonC: LogicalKeyboardKey.gameButtonC,
  KeyCode.gameButtonLeft1: LogicalKeyboardKey.gameButtonLeft1,
  KeyCode.gameButtonLeft2: LogicalKeyboardKey.gameButtonLeft2,
  KeyCode.gameButtonMode: LogicalKeyboardKey.gameButtonMode,
  KeyCode.gameButtonRight1: LogicalKeyboardKey.gameButtonRight1,
  KeyCode.gameButtonRight2: LogicalKeyboardKey.gameButtonRight2,
  KeyCode.gameButtonSelect: LogicalKeyboardKey.gameButtonSelect,
  KeyCode.gameButtonStart: LogicalKeyboardKey.gameButtonStart,
  KeyCode.gameButtonThumbLeft: LogicalKeyboardKey.gameButtonThumbLeft,
  KeyCode.gameButtonThumbRight: LogicalKeyboardKey.gameButtonThumbRight,
  KeyCode.gameButtonX: LogicalKeyboardKey.gameButtonX,
  KeyCode.gameButtonY: LogicalKeyboardKey.gameButtonY,
  KeyCode.gameButtonZ: LogicalKeyboardKey.gameButtonZ,
  KeyCode.fn: LogicalKeyboardKey.fn,
  KeyCode.shift: LogicalKeyboardKey.shift,
  KeyCode.meta: LogicalKeyboardKey.meta,
  KeyCode.alt: LogicalKeyboardKey.alt,
  KeyCode.control: LogicalKeyboardKey.control,
};

enum KeyCode {
  empty,
  // none,
  hyper,
  superKey,
  fnLock,
  suspend,
  resume,
  // turbo,
  // privacyScreenToggle,
  sleep,
  wakeUp,
  // displayToggleIntExt,
  // usbReserved,
  // usbErrorRollOver,
  // usbPostFail,
  // usbErrorUndefined,
  keyA,
  keyB,
  keyC,
  keyD,
  keyE,
  keyF,
  keyG,
  keyH,
  keyI,
  keyJ,
  keyK,
  keyL,
  keyM,
  keyN,
  keyO,
  keyP,
  keyQ,
  keyR,
  keyS,
  keyT,
  keyU,
  keyV,
  keyW,
  keyX,
  keyY,
  keyZ,
  digit1,
  digit2,
  digit3,
  digit4,
  digit5,
  digit6,
  digit7,
  digit8,
  digit9,
  digit0,
  enter,
  escape,
  backspace,
  tab,
  space,
  add,
  minus,
  numberSign,
  multiply,
  equal,
  bracketLeft,
  bracketRight,
  backslash,
  semicolon,
  quote,
  backquote,
  comma,
  period,
  slash,
  capsLock,
  f1,
  f2,
  f3,
  f4,
  f5,
  f6,
  f7,
  f8,
  f9,
  f10,
  f11,
  f12,
  printScreen,
  scrollLock,
  pause,
  insert,
  home,
  pageUp,
  delete,
  end,
  pageDown,
  arrowRight,
  arrowLeft,
  arrowDown,
  arrowUp,
  numLock,
  numpadDivide,
  numpadMultiply,
  numpadSubtract,
  numpadAdd,
  numpadEnter,
  numpad1,
  numpad2,
  numpad3,
  numpad4,
  numpad5,
  numpad6,
  numpad7,
  numpad8,
  numpad9,
  numpad0,
  numpadDecimal,
  intlBackslash,
  contextMenu,
  power,
  numpadEqual,
  f13,
  f14,
  f15,
  f16,
  f17,
  f18,
  f19,
  f20,
  f21,
  f22,
  f23,
  f24,
  open,
  help,
  select,
  again,
  undo,
  cut,
  copy,
  paste,
  find,
  audioVolumeMute,
  audioVolumeUp,
  audioVolumeDown,
  numpadComma,
  intlRo,
  kanaMode,
  intlYen,
  convert,
  nonConvert,
  lang1,
  lang2,
  lang3,
  lang4,
  lang5,
  abort,
  props,
  numpadParenLeft,
  numpadParenRight,
  // numpadBackspace,
  // numpadMemoryStore,
  // numpadMemoryRecall,
  // numpadMemoryClear,
  // numpadMemoryAdd,
  // numpadMemorySubtract,
  // numpadSignChange,
  // numpadClear,
  // numpadClearEntry,
  controlLeft,
  shiftLeft,
  altLeft,
  metaLeft,
  controlRight,
  shiftRight,
  altRight,
  metaRight,
  info,
  closedCaptionToggle,
  brightnessUp,
  brightnessDown,
  // brightnessToggle,
  // brightnessMinimum,
  // brightnessMaximum,
  // brightnessAuto,
  // kbdIllumUp,
  // kbdIllumDown,
  mediaLast,
  launchPhone,
  // programGuide,
  exit,
  channelUp,
  channelDown,
  mediaPlay,
  mediaPause,
  mediaRecord,
  mediaFastForward,
  mediaRewind,
  mediaTrackNext,
  mediaTrackPrevious,
  mediaStop,
  eject,
  mediaPlayPause,
  speechInputToggle,
  // bassBoost,
  // mediaSelect,
  launchWordProcessor,
  launchSpreadsheet,
  launchMail,
  launchContacts,
  launchCalendar,
  // launchApp2,
  // launchApp1,
  // launchInternetBrowser,
  logOff,
  // lockScreen,
  launchControlPanel,
  // selectTask,
  // launchDocuments,
  spellCheck,
  // launchKeyboardLayout,
  launchScreenSaver,
  launchAssistant,
  // launchAudioBrowser,
  newKey,
  close,
  save,
  print,
  browserSearch,
  browserHome,
  browserBack,
  browserForward,
  browserStop,
  browserRefresh,
  browserFavorites,
  zoomIn,
  zoomOut,
  zoomToggle,
  redo,
  mailReply,
  mailForward,
  mailSend,
  // keyboardLayoutSelect,
  // showAllWindows,
  gameButton1,
  gameButton2,
  gameButton3,
  gameButton4,
  gameButton5,
  gameButton6,
  gameButton7,
  gameButton8,
  gameButton9,
  gameButton10,
  gameButton11,
  gameButton12,
  gameButton13,
  gameButton14,
  gameButton15,
  gameButton16,
  gameButtonA,
  gameButtonB,
  gameButtonC,
  gameButtonLeft1,
  gameButtonLeft2,
  gameButtonMode,
  gameButtonRight1,
  gameButtonRight2,
  gameButtonSelect,
  gameButtonStart,
  gameButtonThumbLeft,
  gameButtonThumbRight,
  gameButtonX,
  gameButtonY,
  gameButtonZ,
  fn,
  shift,
  meta,
  alt,
  control,
}

final Map<KeyCode, String> _knownKeyLabels = <KeyCode, String>{
  KeyCode.keyA: 'A',
  KeyCode.keyB: 'B',
  KeyCode.keyC: 'C',
  KeyCode.keyD: 'D',
  KeyCode.keyE: 'E',
  KeyCode.keyF: 'F',
  KeyCode.keyG: 'G',
  KeyCode.keyH: 'H',
  KeyCode.keyI: 'I',
  KeyCode.keyJ: 'J',
  KeyCode.keyK: 'K',
  KeyCode.keyL: 'L',
  KeyCode.keyM: 'M',
  KeyCode.keyN: 'N',
  KeyCode.keyO: 'O',
  KeyCode.keyP: 'P',
  KeyCode.keyQ: 'Q',
  KeyCode.keyR: 'R',
  KeyCode.keyS: 'S',
  KeyCode.keyT: 'T',
  KeyCode.keyU: 'U',
  KeyCode.keyV: 'V',
  KeyCode.keyW: 'W',
  KeyCode.keyX: 'X',
  KeyCode.keyY: 'Y',
  KeyCode.keyZ: 'Z',
  KeyCode.digit1: '1',
  KeyCode.digit2: '2',
  KeyCode.digit3: '3',
  KeyCode.digit4: '4',
  KeyCode.digit5: '5',
  KeyCode.digit6: '6',
  KeyCode.digit7: '7',
  KeyCode.digit8: '8',
  KeyCode.digit9: '9',
  KeyCode.digit0: '0',
  KeyCode.enter: '↩︎',
  KeyCode.escape: '⎋',
  KeyCode.backspace: '←',
  KeyCode.tab: '⇥',
  KeyCode.space: '␣',
  KeyCode.numberSign: '#',
  KeyCode.minus: '-',
  KeyCode.multiply: '*',
  KeyCode.add: '+',
  KeyCode.equal: '=',
  KeyCode.bracketLeft: '[',
  KeyCode.bracketRight: ']',
  KeyCode.backslash: '\\',
  KeyCode.semicolon: ';',
  KeyCode.quote: '"',
  KeyCode.backquote: '`',
  KeyCode.comma: ',',
  KeyCode.period: '.',
  KeyCode.slash: '/',
  KeyCode.capsLock: '⇪',
  KeyCode.f1: 'F1',
  KeyCode.f2: 'F2',
  KeyCode.f3: 'F3',
  KeyCode.f4: 'F4',
  KeyCode.f5: 'F5',
  KeyCode.f6: 'F6',
  KeyCode.f7: 'F7',
  KeyCode.f8: 'F8',
  KeyCode.f9: 'F9',
  KeyCode.f10: 'F10',
  KeyCode.f11: 'F11',
  KeyCode.f12: 'F12',
  KeyCode.home: '↖',
  KeyCode.pageUp: '⇞',
  KeyCode.delete: '⌫',
  KeyCode.end: '↘',
  KeyCode.pageDown: '⇟',
  KeyCode.arrowRight: '→',
  KeyCode.arrowLeft: '←',
  KeyCode.arrowDown: '↓',
  KeyCode.arrowUp: '↑',
  KeyCode.controlLeft: '⌃',
  KeyCode.shiftLeft: '⇧',
  KeyCode.altLeft: '⌥',
  KeyCode.metaLeft: (!kIsWeb && Platform.isMacOS) ? '⌘' : '⊞',
  KeyCode.controlRight: '⌃',
  KeyCode.shiftRight: '⇧',
  KeyCode.altRight: '⌥',
  KeyCode.metaRight: (!kIsWeb && Platform.isMacOS) ? '⌘' : '⊞',
  KeyCode.fn: 'fn',
  KeyCode.shift: '⇧',
  KeyCode.meta: (!kIsWeb && Platform.isMacOS) ? '⌘' : '⊞',
  KeyCode.alt: '⌥',
  KeyCode.control: '⌃',
  KeyCode.empty: ' ',
};

extension KeyCodeParser on KeyCode {
  static KeyCode? fromLogicalKey(LogicalKeyboardKey logicalKey) {
    List<int> logicalKeyIdList =
        _knownLogicalKeys.values.map((e) => e.keyId).toList();
    if (!logicalKeyIdList.contains(logicalKey.keyId)) return null;

    return _knownLogicalKeys.entries
        .firstWhere((entry) => entry.value.keyId == logicalKey.keyId)
        .key;
  }

  LogicalKeyboardKey get logicalKey {
    return _knownLogicalKeys[this]!;
  }

  static KeyCode parse(String string) {
    return KeyCode.values.firstWhere((e) => describeEnum(e) == string);
  }

  String get stringValue {
    return describeEnum(this);
  }

  int get keyId {
    return logicalKey.keyId;
  }

  String get keyLabel {
    return _knownKeyLabels[this] ?? logicalKey.keyLabel;
  }
}
