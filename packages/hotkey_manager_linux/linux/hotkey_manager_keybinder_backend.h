#ifndef FLUTTER_PLUGIN_HOTKEY_MANAGER_KEYBINDER_BACKEND_H_
#define FLUTTER_PLUGIN_HOTKEY_MANAGER_KEYBINDER_BACKEND_H_

#include <flutter_linux/flutter_linux.h>

#include <map>
#include <string>

#include "hotkey_manager_linux_backend.h"

class HotkeyManagerKeybinderBackend : public HotkeyManagerLinuxBackend {
 public:
  explicit HotkeyManagerKeybinderBackend(FlEventChannel* event_channel);
  ~HotkeyManagerKeybinderBackend() override;

  FlMethodResponse* Register(FlValue* args) override;
  FlMethodResponse* Unregister(FlValue* args) override;
  FlMethodResponse* UnregisterAll() override;
  void HandleKeyDown(const char* keystring);

 private:
  void UnbindAll();

  FlEventChannel* event_channel_;
  std::map<std::string, std::string> hotkey_id_map_;
};

#endif  // FLUTTER_PLUGIN_HOTKEY_MANAGER_KEYBINDER_BACKEND_H_
