#include "hotkey_manager_linux_backend.h"

bool ParseHotkeyDefinition(FlValue* args,
                           HotkeyDefinition* hotkey,
                           std::string* error_message) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    *error_message = "Expected hotkey arguments.";
    return false;
  }

  FlValue* identifier_value = fl_value_lookup_string(args, "identifier");
  FlValue* key_code_value = fl_value_lookup_string(args, "keyCode");
  FlValue* modifiers_value = fl_value_lookup_string(args, "modifiers");

  if (identifier_value == nullptr ||
      fl_value_get_type(identifier_value) != FL_VALUE_TYPE_STRING) {
    *error_message = "Expected a string identifier.";
    return false;
  }
  if (key_code_value == nullptr ||
      fl_value_get_type(key_code_value) != FL_VALUE_TYPE_INT) {
    *error_message = "Expected an integer keyCode.";
    return false;
  }
  if (modifiers_value == nullptr ||
      fl_value_get_type(modifiers_value) != FL_VALUE_TYPE_LIST) {
    *error_message = "Expected a modifiers list.";
    return false;
  }

  hotkey->identifier = fl_value_get_string(identifier_value);
  hotkey->key_code = static_cast<guint>(fl_value_get_int(key_code_value));
  hotkey->modifiers.clear();

  for (gint i = 0; i < fl_value_get_length(modifiers_value); i++) {
    FlValue* modifier_value = fl_value_get_list_value(modifiers_value, i);
    if (modifier_value == nullptr ||
        fl_value_get_type(modifier_value) != FL_VALUE_TYPE_STRING) {
      *error_message = "Expected string modifiers.";
      return false;
    }
    hotkey->modifiers.push_back(fl_value_get_string(modifier_value));
  }

  return true;
}

FlMethodResponse* SuccessResponse() {
  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(true)));
}

FlMethodResponse* ErrorResponse(const char* code, const std::string& message) {
  return FL_METHOD_RESPONSE(
      fl_method_error_response_new(code, message.c_str(), nullptr));
}

void SendHotkeyEvent(FlEventChannel* event_channel,
                     const char* type,
                     const std::string& identifier) {
  if (event_channel == nullptr || identifier.empty()) {
    return;
  }

  FlValue* event_data = fl_value_new_map();
  fl_value_set_string_take(event_data, "identifier",
                           fl_value_new_string(identifier.c_str()));

  g_autoptr(FlValue) event = fl_value_new_map();
  fl_value_set_string_take(event, "type", fl_value_new_string(type));
  fl_value_set_string_take(event, "data", event_data);

  fl_event_channel_send(event_channel, event, nullptr, nullptr);
}
