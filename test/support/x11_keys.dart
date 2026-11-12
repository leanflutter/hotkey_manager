import 'dart:ffi' as ffi;

/// Keymap queries only. Never sends X11 events or keyboard input.
bool x11HasKey(int keysym) {
  final library = ffi.DynamicLibrary.open('libX11.so.6');
  final open = library
      .lookupFunction<
        ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Char>),
        ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Char>)
      >('XOpenDisplay');
  final close = library
      .lookupFunction<
        ffi.Int32 Function(ffi.Pointer<ffi.Void>),
        int Function(ffi.Pointer<ffi.Void>)
      >('XCloseDisplay');
  final lookup = library
      .lookupFunction<
        ffi.Uint8 Function(ffi.Pointer<ffi.Void>, ffi.UintPtr),
        int Function(ffi.Pointer<ffi.Void>, int)
      >('XKeysymToKeycode');
  final display = open(ffi.nullptr);
  if (display == ffi.nullptr) return false;
  try {
    return lookup(display, keysym) != 0;
  } finally {
    close(display);
  }
}
