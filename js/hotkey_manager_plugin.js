const knownVirtualKeyCodes = {
  keyA: 0x41,
  keyB: 0x42,
  keyC: 0x43,
  keyD: 0x44,
  keyE: 0x45,
  keyF: 0x46,
  keyG: 0x47,
  keyH: 0x48,
  keyI: 0x49,
  keyJ: 0x4a,
  keyK: 0x4b,
  keyL: 0x4c,
  keyM: 0x4d,
  keyN: 0x4e,
  keyO: 0x4f,
  keyP: 0x50,
  keyQ: 0x51,
  keyR: 0x52,
  keyS: 0x53,
  keyT: 0x54,
  keyU: 0x55,
  keyV: 0x56,
  keyW: 0x57,
  keyX: 0x58,
  keyY: 0x59,
  keyZ: 0x5a,
};

var _window = window.parent;
var _document = window.parent.document;

var _hotkeyMap = {};

function _hotkeyManagerPluginInit() {
  var handleKeyDownOrUp = function (eventType, event) {
    var hotKey = Object.values(_hotkeyMap).find(function (value) {
      if (event.which != knownVirtualKeyCodes[value.keyCode]) {
        return false;
      }
      return !(value.modifiers || [])
        .map(function (e) {
          if (e == "shift") {
            return event.shiftKey;
          } else if (e == "control") {
            return event.ctrlKey;
          } else if (e == "alt") {
            return event.altKey;
          } else if (e == "meta") {
            return event.metaKey;
          }
        })
        .includes(false);
    });
    if (hotKey != null) {
      _document
        .getElementsByTagName("iframe")[0]
        .contentWindow.postMessage({ eventType, hotKey }, "*");
    } else {
      console.log(event);
    }
  };

  _document.onkeydown = (e) => handleKeyDownOrUp("onKeyDown", e);
  _document.onkeyup = (e) => handleKeyDownOrUp("onKeyUp", e);
}

function _hotkeyManagerPluginUninit() {
  _document.onkeyup = null;
  _document.onkeydown = null;
}

function hotkeyManagerPluginRegister(hotkey) {
  _hotkeyMap[hotkey.identifier] = hotkey;
  console.log(_hotkeyMap);
  console.log(hotkey);
  _hotkeyManagerPluginInit();
}

function hotkeyManagerPluginUnregister(hotkey) {
  _hotkeyMap[hotkey.identifier] = null;
  delete _hotkeyMap[hotkey.identifier];
  console.log(_hotkeyMap);
  if (Object.values(_hotkeyMap).length == 0) {
    _hotkeyManagerPluginUninit();
  }
}
