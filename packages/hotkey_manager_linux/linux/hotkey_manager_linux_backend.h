#ifndef FLUTTER_PLUGIN_HOTKEY_MANAGER_LINUX_BACKEND_H_
#define FLUTTER_PLUGIN_HOTKEY_MANAGER_LINUX_BACKEND_H_

#include <flutter_linux/flutter_linux.h>
#include <glib.h>

#include <string>
#include <vector>

struct HotkeyDefinition {
  std::string identifier;
  guint key_code;
  std::vector<std::string> modifiers;
};

class HotkeyManagerLinuxBackend {
 public:
  virtual ~HotkeyManagerLinuxBackend() = default;

  virtual FlMethodResponse* Register(FlValue* args) = 0;
  virtual FlMethodResponse* Unregister(FlValue* args) = 0;
  virtual FlMethodResponse* UnregisterAll() = 0;
};

bool ParseHotkeyDefinition(FlValue* args,
                           HotkeyDefinition* hotkey,
                           std::string* error_message);
FlMethodResponse* SuccessResponse();
FlMethodResponse* ErrorResponse(const char* code, const std::string& message);
void SendHotkeyEvent(FlEventChannel* event_channel,
                     const char* type,
                     const std::string& identifier);

#endif  // FLUTTER_PLUGIN_HOTKEY_MANAGER_LINUX_BACKEND_H_
