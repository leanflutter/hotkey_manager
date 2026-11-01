"""Own one test chord in a separate process; never generates input."""
import ctypes
import json
import sys

user32 = ctypes.WinDLL('user32', use_last_error=True)
user32.RegisterHotKey.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_uint, ctypes.c_uint]
user32.UnregisterHotKey.argtypes = [ctypes.c_void_p, ctypes.c_int]
registered = bool(user32.RegisterHotKey(None, 0x7ff9, 0x0007, 0x82))  # Ctrl+Alt+Shift+F19
print(json.dumps({'registered': registered, 'error': ctypes.get_last_error() if not registered else 0}), flush=True)
if not registered:
    sys.exit(1)
try:
    sys.stdin.readline()
finally:
    if not user32.UnregisterHotKey(None, 0x7ff9):
        sys.exit(2)
