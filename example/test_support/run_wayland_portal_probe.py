"""No-input Hyprland end-to-end test of the real release Flutter application."""
import json
import os
from pathlib import Path
import re
import selectors
import subprocess
import time

example = Path(__file__).resolve().parents[1]
executable = example / "build/linux/x64/release/bundle/hotkey_manager_example"
manifest = (example / "linux/CMakeLists.txt").read_text()
application_id = re.search(r'set\(APPLICATION_ID\s+"([A-Za-z0-9_.-]+)"\)', manifest)[1]
env = dict(os.environ, GDK_BACKEND="wayland", DISPLAY="")
session = subprocess.check_output(["systemctl", "--user", "show-environment"], text=True)
for line in session.splitlines():
    name, _, value = line.partition("=")
    if name in ("HYPRLAND_INSTANCE_SIGNATURE", "WAYLAND_DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "XDG_RUNTIME_DIR"):
        env[name] = value
assert env.get("WAYLAND_DISPLAY") and env.get("HYPRLAND_INSTANCE_SIGNATURE")
entry = Path(env.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / f"applications/{application_id}.desktop"
entry.parent.mkdir(parents=True, exist_ok=True)
created = False
if not entry.exists():
    with entry.open("x") as stream:
        stream.write(f'[Desktop Entry]\nType=Application\nName=Hotkey verification\nExec="{executable}"\nNoDisplay=true\n')
    created = True
child = None
selector = selectors.DefaultSelector()
try:
    child = subprocess.Popen([str(executable)], cwd=example, env=env, stdout=subprocess.PIPE, text=True)
    selector.register(child.stdout, selectors.EVENT_READ)
    deadline = time.monotonic() + 45
    action = None
    rounds = 0
    passed = False
    while time.monotonic() < deadline:
        for source, _ in selector.select(timeout=0.1):
            line = source.fileobj.readline()
            if not line:
                selector.unregister(source.fileobj)
                continue
            print(line, end="", flush=True)
            if line.startswith("WAYLAND_PORTAL_READY "):
                metadata = json.loads(line.removeprefix("WAYLAND_PORTAL_READY "))
                rounds += 1
                assert metadata["round"] == rounds
                assert "F19" in metadata["description"] and "Unknown" not in metadata["description"]
                key = metadata["registrationKey"]
                assert re.fullmatch(r"hotkey_manager:[A-Za-z0-9+]+", key), key
                action = f"{application_id}:{key}"
                actions = subprocess.check_output(["hyprctl", "globalshortcuts"], env=env, text=True, timeout=3)
                assert action in actions, actions
                # Target this action through the compositor protocol. No key
                # is delivered to the currently focused application.
                result = subprocess.check_output(["hyprctl", "dispatch", f"hl.dsp.global({json.dumps(action)})"], env=env, text=True, timeout=3)
                print("COMPOSITOR_DISPATCH " + result.strip(), flush=True)
            elif line.startswith("WAYLAND_PORTAL_RESULT "):
                result = json.loads(line.removeprefix("WAYLAND_PORTAL_RESULT "))
                assert result["passed"] and result["releaseMode"]
                assert result["realCompositorActivation"] and not result["osKeyboardInputGenerated"]
                passed = True
        if child.poll() is not None and not selector.get_map():
            break
    assert child.wait(timeout=1) == 0 and passed and rounds == 2
    actions = subprocess.check_output(["hyprctl", "globalshortcuts"], env=env, text=True, timeout=3)
    assert action is not None
    # Hyprland Portal 1.4.1 retains its advertised catalog after closing a
    # session. Validate SDK cleanup plus fresh registration/activation in both
    # rounds instead of interpreting that catalog as a live client session.
    print("PROVIDER_CATALOG_RETAINED " + str(action in actions), flush=True)
finally:
    selector.close()
    if child is not None:
        if child.poll() is None:
            child.kill()
        child.wait()
    if created:
        entry.unlink()
