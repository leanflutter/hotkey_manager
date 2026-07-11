#include "hotkey_manager_keybinder_backend.h"

#include <gdk/gdkkeysyms.h>
#include <gtk/gtk.h>
#include <keybinder.h>

#include <algorithm>
#include <string>
#include <vector>

namespace {

HotkeyManagerKeybinderBackend* keybinder_backend_instance = nullptr;

void HandleKeyDownCallback(const char* keystring, void* user_data) {
  if (keybinder_backend_instance != nullptr) {
    keybinder_backend_instance->HandleKeyDown(keystring);
  }
}

guint GetMods(const std::vector<std::string>& modifiers) {
  guint mods = 0;
  for (const std::string& modifier : modifiers) {
    guint mod = 0;
    if (modifier == "alt")
      mod = GDK_MOD1_MASK;
    else if (modifier == "capsLock")
      mod = GDK_LOCK_MASK;
    else if (modifier == "control")
      mod = GDK_CONTROL_MASK;
    else if (modifier == "meta")
      mod = GDK_META_MASK;
    else if (modifier == "shift")
      mod = GDK_SHIFT_MASK;
    mods = mods | mod;
  }
  return mods;
}

}  // namespace

HotkeyManagerKeybinderBackend::HotkeyManagerKeybinderBackend(
    FlEventChannel* event_channel)
    : event_channel_(event_channel) {
  keybinder_backend_instance = this;
  keybinder_init();
}

HotkeyManagerKeybinderBackend::~HotkeyManagerKeybinderBackend() {
  UnbindAll();
  if (keybinder_backend_instance == this) {
    keybinder_backend_instance = nullptr;
  }
}

FlMethodResponse* HotkeyManagerKeybinderBackend::Register(FlValue* args) {
  HotkeyDefinition hotkey;
  std::string error_message;
  if (!ParseHotkeyDefinition(args, &hotkey, &error_message)) {
    return ErrorResponse("bad-arguments", error_message);
  }

  g_autofree gchar* keystring = gtk_accelerator_name(
      hotkey.key_code, static_cast<GdkModifierType>(GetMods(hotkey.modifiers)));
  if (keystring == nullptr || keystring[0] == '\0') {
    return ErrorResponse("invalid-hotkey", "Unable to create GTK accelerator.");
  }

  auto existing = hotkey_id_map_.find(hotkey.identifier);
  if (existing != hotkey_id_map_.end()) {
    keybinder_unbind(existing->second.c_str(), HandleKeyDownCallback);
    hotkey_id_map_.erase(existing);
  }

  if (!keybinder_bind(keystring, HandleKeyDownCallback, nullptr)) {
    return ErrorResponse("register-failed", "Unable to bind global hotkey.");
  }

  hotkey_id_map_.insert({hotkey.identifier, keystring});
  return SuccessResponse();
}

FlMethodResponse* HotkeyManagerKeybinderBackend::Unregister(FlValue* args) {
  FlValue* identifier_value = fl_value_lookup_string(args, "identifier");
  if (identifier_value == nullptr ||
      fl_value_get_type(identifier_value) != FL_VALUE_TYPE_STRING) {
    return ErrorResponse("bad-arguments", "Expected a string identifier.");
  }

  std::string identifier = fl_value_get_string(identifier_value);
  auto existing = hotkey_id_map_.find(identifier);
  if (existing != hotkey_id_map_.end()) {
    keybinder_unbind(existing->second.c_str(), HandleKeyDownCallback);
    hotkey_id_map_.erase(existing);
  }

  return SuccessResponse();
}

FlMethodResponse* HotkeyManagerKeybinderBackend::UnregisterAll() {
  UnbindAll();
  return SuccessResponse();
}

void HotkeyManagerKeybinderBackend::HandleKeyDown(const char* keystring) {
  if (keystring == nullptr) {
    return;
  }

  std::string accelerator = keystring;
  auto result = std::find_if(
      hotkey_id_map_.begin(), hotkey_id_map_.end(),
      [accelerator](const auto& hotkey) { return hotkey.second == accelerator; });

  if (result == hotkey_id_map_.end()) {
    return;
  }

  SendHotkeyEvent(event_channel_, "onKeyDown", result->first);
}

void HotkeyManagerKeybinderBackend::UnbindAll() {
  for (const auto& hotkey : hotkey_id_map_) {
    keybinder_unbind(hotkey.second.c_str(), HandleKeyDownCallback);
  }
  hotkey_id_map_.clear();
}
