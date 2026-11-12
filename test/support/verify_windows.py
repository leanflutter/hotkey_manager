"""Run native compatibility tests on the Windows desktop; sends no input."""
import ctypes
import json
import os
from pathlib import Path
import shutil
import subprocess

package = Path(__file__).resolve().parents[2]
user32 = ctypes.WinDLL('user32', use_last_error=True)
user32.RegisterHotKey.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_uint, ctypes.c_uint]
user32.UnregisterHotKey.argtypes = [ctypes.c_void_p, ctypes.c_int]
results = {}
# These are the virtual keycodes emitted by the previous uni_platform bridge.
for name, code in {'Volume Up': 175, 'Volume Down': 174, 'Mute': 173,
                   'Media Play Pause': 179, 'Print Screen': 44, 'Pause': 19,
                   'Context Menu': 93, 'Browser Back': 166, 'Num Lock': 144,
                   'Numpad Equal': 146}.items():
    registered = bool(user32.RegisterHotKey(None, 0x7ffd, 0x0006, code))
    error = 0 if registered else ctypes.get_last_error()
    if registered:
        assert user32.UnregisterHotKey(None, 0x7ffd)
    results[name] = {'legacyVirtualKey': code, 'registered': registered, 'error': error}
folder = package / 'build/compatibility_audit'
folder.mkdir(parents=True, exist_ok=True)
(folder / 'windows_legacy_keys.json').write_text(json.dumps(results, indent=2))
print('AUDIT_WINDOWS_OS_KEYS ' + json.dumps(results), flush=True)
os.environ['CI'] = 'true'
os.environ['HOTKEY_MANAGER_NATIVE_TESTS'] = '1'
subprocess.run([shutil.which('flutter'), 'test', '--no-pub', '--reporter', 'expanded'],
               cwd=package, check=True)
