import 'dart:ffi' as ffi;

final class CarbonHotKeyId extends ffi.Struct {
  @ffi.Uint32()
  external int signature;
  @ffi.Uint32()
  external int id;
}

/// Sends only process-local Carbon hotkey events; never generates keyboard input.
class CarbonHotKeys {
  final _carbon = ffi.DynamicLibrary.open(
    '/System/Library/Frameworks/Carbon.framework/Carbon',
  );
  final _libc = ffi.DynamicLibrary.process();
  late final _malloc = _libc
      .lookupFunction<
        ffi.Pointer<ffi.Void> Function(ffi.IntPtr),
        ffi.Pointer<ffi.Void> Function(int)
      >('malloc');
  late final _free = _libc
      .lookupFunction<
        ffi.Void Function(ffi.Pointer<ffi.Void>),
        void Function(ffi.Pointer<ffi.Void>)
      >('free');
  late final _target = _carbon
      .lookupFunction<
        ffi.Pointer<ffi.Void> Function(),
        ffi.Pointer<ffi.Void> Function()
      >('GetApplicationEventTarget');
  late final _create = _carbon
      .lookupFunction<
        ffi.Int32 Function(
          ffi.Pointer<ffi.Void>,
          ffi.Uint32,
          ffi.Uint32,
          ffi.Double,
          ffi.Uint32,
          ffi.Pointer<ffi.Pointer<ffi.Void>>,
        ),
        int Function(
          ffi.Pointer<ffi.Void>,
          int,
          int,
          double,
          int,
          ffi.Pointer<ffi.Pointer<ffi.Void>>,
        )
      >('CreateEvent');
  late final _parameter = _carbon
      .lookupFunction<
        ffi.Int32 Function(
          ffi.Pointer<ffi.Void>,
          ffi.Uint32,
          ffi.Uint32,
          ffi.Uint32,
          ffi.Pointer<ffi.Void>,
        ),
        int Function(
          ffi.Pointer<ffi.Void>,
          int,
          int,
          int,
          ffi.Pointer<ffi.Void>,
        )
      >('SetEventParameter');
  late final _send = _carbon
      .lookupFunction<
        ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Void>),
        int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Void>)
      >('SendEventToEventTarget');
  late final _release = _carbon
      .lookupFunction<
        ffi.Void Function(ffi.Pointer<ffi.Void>),
        void Function(ffi.Pointer<ffi.Void>)
      >('ReleaseEvent');
  late final _register = _carbon
      .lookupFunction<
        ffi.Int32 Function(
          ffi.Uint32,
          ffi.Uint32,
          CarbonHotKeyId,
          ffi.Pointer<ffi.Void>,
          ffi.Uint32,
          ffi.Pointer<ffi.Pointer<ffi.Void>>,
        ),
        int Function(
          int,
          int,
          CarbonHotKeyId,
          ffi.Pointer<ffi.Void>,
          int,
          ffi.Pointer<ffi.Pointer<ffi.Void>>,
        )
      >('RegisterEventHotKey');
  late final _unregister = _carbon
      .lookupFunction<
        ffi.Int32 Function(ffi.Pointer<ffi.Void>),
        int Function(ffi.Pointer<ffi.Void>)
      >('UnregisterEventHotKey');

  int send(int shortcutId, {required bool down}) {
    final event = _malloc(ffi.sizeOf<ffi.Pointer<ffi.Void>>())
        .cast<ffi.Pointer<ffi.Void>>();
    final identifier = _malloc(ffi.sizeOf<CarbonHotKeyId>())
        .cast<CarbonHotKeyId>();
    event.value = ffi.nullptr;
    try {
      var status = _create(ffi.nullptr, 0x6b657962, down ? 5 : 6, 0, 0, event);
      if (status != 0) return status;
      identifier.ref
        ..signature =
            0x6e746170 // nativeapi's 'ntap' ownership signature.
        ..id = shortcutId;
      status = _parameter(
        event.value,
        0x2d2d2d2d,
        0x686b6964,
        ffi.sizeOf<CarbonHotKeyId>(),
        identifier.cast(),
      );
      if (status != 0) return status;
      return _send(event.value, _target());
    } finally {
      if (event.value != ffi.nullptr) _release(event.value);
      _free(event.cast());
      _free(identifier.cast());
    }
  }

  /// Reserves and releases a legacy Carbon keycode directly, without activating it.
  int probeRegistration(int keycode) {
    final handle = _malloc(ffi.sizeOf<ffi.Pointer<ffi.Void>>())
        .cast<ffi.Pointer<ffi.Void>>();
    final identifier = _malloc(ffi.sizeOf<CarbonHotKeyId>())
        .cast<CarbonHotKeyId>();
    handle.value = ffi.nullptr;
    try {
      identifier.ref
        ..signature =
            0x686b6174 // Separate 'hkat' audit registration.
        ..id = keycode;
      final result = _register(
        keycode,
        0x1000 | 0x0200,
        identifier.ref,
        _target(),
        0,
        handle,
      ); // Control + Shift.
      if (result == 0) {
        final released = _unregister(handle.value);
        if (released != 0) {
          throw StateError('Carbon unregister failed: $released');
        }
      }
      return result;
    } finally {
      _free(handle.cast());
      _free(identifier.cast());
    }
  }
}
