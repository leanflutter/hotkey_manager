#include "hotkey_manager_portal_backend.h"

#include <gdk/gdkkeysyms.h>
#include <gtk/gtk.h>

#include <algorithm>
#include <cctype>
#include <sstream>
#include <string>
#include <vector>

namespace {

constexpr char kPortalBusName[] = "org.freedesktop.portal.Desktop";
constexpr char kPortalObjectPath[] = "/org/freedesktop/portal/desktop";
constexpr char kGlobalShortcutsInterface[] =
    "org.freedesktop.portal.GlobalShortcuts";
constexpr char kHostRegistryInterface[] = "org.freedesktop.host.portal.Registry";
constexpr char kRequestInterface[] = "org.freedesktop.portal.Request";
constexpr char kSessionInterface[] = "org.freedesktop.portal.Session";
constexpr guint kRebindDelayMs = 100;

struct RequestContext {
  HotkeyManagerPortalBackend* backend;
  guint generation;
  guint subscription_id;
  PortalRequestKind kind;
};

gboolean RebindTimeoutCallback(gpointer user_data) {
  return static_cast<HotkeyManagerPortalBackend*>(user_data)->RebindNow();
}

void RequestResponseCallback(GDBusConnection* connection,
                             const gchar* sender_name,
                             const gchar* object_path,
                             const gchar* interface_name,
                             const gchar* signal_name,
                             GVariant* parameters,
                             gpointer user_data) {
  guint32 response = 0;
  GVariant* results = nullptr;
  g_variant_get(parameters, "(u@a{sv})", &response, &results);

  RequestContext* context = static_cast<RequestContext*>(user_data);
  switch (context->kind) {
    case PortalRequestKind::create_session:
      context->backend->HandleCreateSessionResponse(response, results,
                                                    context->generation);
      break;
    case PortalRequestKind::list_shortcuts:
      context->backend->HandleListShortcutsResponse(response, results,
                                                    context->generation);
      break;
    case PortalRequestKind::bind_shortcuts:
      context->backend->HandleBindShortcutsResponse(response,
                                                    context->generation);
      break;
  }

  context->backend->RemoveRequestSubscription(context->subscription_id);
  g_dbus_connection_signal_unsubscribe(connection, context->subscription_id);
  g_variant_unref(results);
}

void ShortcutSignalCallback(GDBusConnection* connection,
                            const gchar* sender_name,
                            const gchar* object_path,
                            const gchar* interface_name,
                            const gchar* signal_name,
                            GVariant* parameters,
                            gpointer user_data) {
  static_cast<HotkeyManagerPortalBackend*>(user_data)->HandleShortcutSignal(
      signal_name, parameters);
}

std::string NextToken(const char* prefix) {
  g_autofree gchar* uuid = g_uuid_string_random();
  std::string token = std::string(prefix) + "_";
  for (const gchar* character = uuid; *character != '\0'; character++) {
    token.push_back(g_ascii_isalnum(*character) ? *character : '_');
  }
  return token;
}

void SubscribeRequestResponse(GDBusConnection* connection,
                              const std::string& request_handle,
                              HotkeyManagerPortalBackend* backend,
                              guint generation,
                              PortalRequestKind kind) {
  RequestContext* context =
      new RequestContext{backend, generation, 0, kind};
  context->subscription_id = g_dbus_connection_signal_subscribe(
      connection, kPortalBusName, kRequestInterface, "Response",
      request_handle.c_str(), nullptr, G_DBUS_SIGNAL_FLAGS_NONE,
      RequestResponseCallback, context,
      [](gpointer data) { delete static_cast<RequestContext*>(data); });

  if (context->subscription_id == 0) {
    delete context;
    g_warning("Failed to subscribe to portal request response.");
    return;
  }

  backend->AddRequestSubscription(context->subscription_id);
}

bool AddModifierToTrigger(const std::string& modifier,
                          std::vector<std::string>* trigger_parts) {
  if (modifier == "control") {
    trigger_parts->push_back("CTRL");
  } else if (modifier == "alt") {
    trigger_parts->push_back("ALT");
  } else if (modifier == "shift") {
    trigger_parts->push_back("SHIFT");
  } else if (modifier == "meta") {
    trigger_parts->push_back("LOGO");
  } else if (modifier == "capsLock" || modifier == "fn") {
    g_warning("The Wayland GlobalShortcuts portal does not support the %s "
              "modifier.",
              modifier.c_str());
    return false;
  }

  return true;
}

std::string NormalizeKeyName(const gchar* key_name) {
  if (key_name == nullptr) {
    return "";
  }

  std::string normalized = key_name;
  if (normalized.size() == 1) {
    normalized[0] = static_cast<char>(
        std::tolower(static_cast<unsigned char>(normalized[0])));
  }
  return normalized;
}

std::string JoinTriggerParts(const std::vector<std::string>& trigger_parts) {
  std::stringstream trigger;
  for (size_t i = 0; i < trigger_parts.size(); i++) {
    if (i > 0) {
      trigger << "+";
    }
    trigger << trigger_parts[i];
  }
  return trigger.str();
}

}  // namespace

HotkeyManagerPortalBackend::HotkeyManagerPortalBackend(
    FlEventChannel* event_channel)
    : event_channel_(event_channel),
      connection_(nullptr),
      portal_(nullptr),
      activated_subscription_id_(0),
      deactivated_subscription_id_(0),
      rebind_source_id_(0),
      generation_(0) {}

HotkeyManagerPortalBackend::~HotkeyManagerPortalBackend() {
  if (rebind_source_id_ != 0) {
    g_source_remove(rebind_source_id_);
    rebind_source_id_ = 0;
  }
  UnsubscribeRequestSignals();
  UnsubscribeShortcutSignals();
  CloseSession();
  g_clear_object(&portal_);
  g_clear_object(&connection_);
}

FlMethodResponse* HotkeyManagerPortalBackend::Register(FlValue* args) {
  HotkeyDefinition hotkey;
  std::string error_message;
  if (!ParseHotkeyDefinition(args, &hotkey, &error_message)) {
    return ErrorResponse("bad-arguments", error_message);
  }
  if (!EnsurePortal(&error_message)) {
    return ErrorResponse("portal-unavailable", error_message);
  }

  hotkeys_[hotkey.identifier] = {hotkey.key_code, hotkey.modifiers};
  ScheduleRebind();
  return SuccessResponse();
}

FlMethodResponse* HotkeyManagerPortalBackend::Unregister(FlValue* args) {
  FlValue* identifier_value = fl_value_lookup_string(args, "identifier");
  if (identifier_value == nullptr ||
      fl_value_get_type(identifier_value) != FL_VALUE_TYPE_STRING) {
    return ErrorResponse("bad-arguments", "Expected a string identifier.");
  }

  hotkeys_.erase(fl_value_get_string(identifier_value));
  ScheduleRebind();
  return SuccessResponse();
}

FlMethodResponse* HotkeyManagerPortalBackend::UnregisterAll() {
  hotkeys_.clear();
  ScheduleRebind();
  return SuccessResponse();
}

gboolean HotkeyManagerPortalBackend::RebindNow() {
  rebind_source_id_ = 0;
  generation_++;
  CloseSession();

  if (hotkeys_.empty()) {
    return G_SOURCE_REMOVE;
  }

  std::string error_message;
  if (!EnsurePortal(&error_message)) {
    g_warning("Unable to use GlobalShortcuts portal: %s",
              error_message.c_str());
    return G_SOURCE_REMOVE;
  }

  CreateSession(generation_);
  return G_SOURCE_REMOVE;
}

void HotkeyManagerPortalBackend::HandleCreateSessionResponse(guint32 response,
                                                             GVariant* results,
                                                             guint generation) {
  if (generation != generation_) {
    return;
  }
  if (response != 0) {
    g_warning("GlobalShortcuts CreateSession failed with response %u.",
              response);
    return;
  }

  GVariant* session_handle_value =
      g_variant_lookup_value(results, "session_handle", nullptr);
  if (session_handle_value == nullptr) {
    g_warning("GlobalShortcuts CreateSession response did not include a "
              "session handle.");
    return;
  }

  session_handle_ = g_variant_get_string(session_handle_value, nullptr);
  g_variant_unref(session_handle_value);

  SubscribeShortcutSignals();
  ListShortcuts(generation);
}

void HotkeyManagerPortalBackend::HandleListShortcutsResponse(
    guint32 response,
    GVariant* results,
    guint generation) {
  if (generation != generation_) {
    return;
  }
  if (response != 0) {
    g_warning("GlobalShortcuts ListShortcuts failed with response %u.",
              response);
    BindShortcuts(generation);
    return;
  }

  std::vector<std::string> registered_shortcut_ids;
  GVariant* shortcuts =
      g_variant_lookup_value(results, "shortcuts",
                             G_VARIANT_TYPE("a(sa{sv})"));
  if (shortcuts != nullptr) {
    GVariantIter iterator;
    const gchar* shortcut_id = nullptr;
    GVariant* properties = nullptr;
    g_variant_iter_init(&iterator, shortcuts);
    while (g_variant_iter_next(&iterator, "(&s@a{sv})", &shortcut_id,
                               &properties)) {
      registered_shortcut_ids.emplace_back(shortcut_id);
      g_variant_unref(properties);
    }
    g_variant_unref(shortcuts);
  }

  if (HasMissingShortcuts(hotkeys_, registered_shortcut_ids)) {
    BindShortcuts(generation);
  }
}

void HotkeyManagerPortalBackend::HandleBindShortcutsResponse(guint32 response,
                                                             guint generation) {
  if (generation != generation_) {
    return;
  }
  if (response != 0) {
    g_warning("GlobalShortcuts BindShortcuts failed with response %u.",
              response);
  }
}

void HotkeyManagerPortalBackend::HandleShortcutSignal(
    const gchar* signal_name,
    GVariant* parameters) {
  const gchar* session_handle = nullptr;
  const gchar* shortcut_id = nullptr;
  guint64 timestamp = 0;
  GVariant* options = nullptr;
  g_variant_get(parameters, "(&o&st@a{sv})", &session_handle, &shortcut_id,
                &timestamp, &options);

  bool matches_session = session_handle_ == session_handle;
  bool is_registered =
      shortcut_id != nullptr && hotkeys_.find(shortcut_id) != hotkeys_.end();
  if (matches_session && is_registered) {
    if (g_strcmp0(signal_name, "Activated") == 0) {
      SendHotkeyEvent(event_channel_, "onKeyDown", shortcut_id);
    } else if (g_strcmp0(signal_name, "Deactivated") == 0) {
      SendHotkeyEvent(event_channel_, "onKeyUp", shortcut_id);
    }
  }

  g_variant_unref(options);
}

void HotkeyManagerPortalBackend::AddRequestSubscription(guint subscription_id) {
  request_subscription_ids_.push_back(subscription_id);
}

void HotkeyManagerPortalBackend::RemoveRequestSubscription(
    guint subscription_id) {
  request_subscription_ids_.erase(
      std::remove(request_subscription_ids_.begin(),
                  request_subscription_ids_.end(), subscription_id),
      request_subscription_ids_.end());
}

bool HotkeyManagerPortalBackend::EnsurePortal(std::string* error_message) {
  if (portal_ != nullptr && connection_ != nullptr) {
    return true;
  }

  g_autoptr(GError) error = nullptr;
  g_autofree gchar* bus_address =
      g_dbus_address_get_for_bus_sync(G_BUS_TYPE_SESSION, nullptr, &error);
  if (bus_address == nullptr) {
    *error_message =
        error != nullptr ? error->message : "No session bus address.";
    return false;
  }

  connection_ = g_dbus_connection_new_for_address_sync(
      bus_address,
      static_cast<GDBusConnectionFlags>(
          G_DBUS_CONNECTION_FLAGS_AUTHENTICATION_CLIENT |
          G_DBUS_CONNECTION_FLAGS_MESSAGE_BUS_CONNECTION),
      nullptr, nullptr, &error);
  if (connection_ == nullptr) {
    *error_message = error != nullptr ? error->message : "No session bus.";
    return false;
  }
  if (!RegisterHostApplication(error_message)) {
    g_clear_object(&connection_);
    return false;
  }

  portal_ = g_dbus_proxy_new_sync(
      connection_, G_DBUS_PROXY_FLAGS_NONE, nullptr, kPortalBusName,
      kPortalObjectPath, kGlobalShortcutsInterface, nullptr, &error);
  if (portal_ == nullptr) {
    *error_message =
        error != nullptr ? error->message : "GlobalShortcuts portal missing.";
    g_clear_object(&connection_);
    return false;
  }

  g_autofree gchar* owner = g_dbus_proxy_get_name_owner(portal_);
  if (owner == nullptr) {
    *error_message = "GlobalShortcuts portal is not running.";
    g_clear_object(&portal_);
    g_clear_object(&connection_);
    return false;
  }

  g_autoptr(GVariant) version =
      g_dbus_proxy_get_cached_property(portal_, "version");
  if (version == nullptr) {
    g_warning("GlobalShortcuts portal did not expose a cached version "
              "property.");
  }

  return true;
}

bool HotkeyManagerPortalBackend::RegisterHostApplication(
    std::string* error_message) {
  GApplication* application = g_application_get_default();
  const gchar* application_id =
      application != nullptr ? g_application_get_application_id(application)
                             : nullptr;
  if (application_id == nullptr || application_id[0] == '\0') {
    *error_message =
        "The GlobalShortcuts portal requires a GApplication application-id.";
    return false;
  }

  GVariantBuilder options;
  g_variant_builder_init(&options, G_VARIANT_TYPE_VARDICT);

  g_autoptr(GError) error = nullptr;
  g_dbus_connection_call_sync(
      connection_, kPortalBusName, kPortalObjectPath, kHostRegistryInterface,
      "Register", g_variant_new("(sa{sv})", application_id, &options), nullptr,
      G_DBUS_CALL_FLAGS_NONE, -1, nullptr, &error);
  if (error != nullptr) {
    if (g_strrstr(error->message, "already associated") != nullptr) {
      return true;
    }
    if (g_strrstr(error->message, "App info not found") != nullptr) {
      std::stringstream message;
      message << "The GlobalShortcuts portal requires an installed .desktop "
                 "file whose basename matches the application id '"
              << application_id << "'. " << error->message;
      *error_message = message.str();
      return false;
    }
    *error_message = error->message;
    return false;
  }

  return true;
}

void HotkeyManagerPortalBackend::ScheduleRebind() {
  if (rebind_source_id_ != 0) {
    g_source_remove(rebind_source_id_);
  }
  rebind_source_id_ = g_timeout_add(kRebindDelayMs, RebindTimeoutCallback, this);
}

void HotkeyManagerPortalBackend::CreateSession(guint generation) {
  GVariantBuilder options;
  g_variant_builder_init(&options, G_VARIANT_TYPE_VARDICT);
  std::string handle_token = NextToken("hkm_create");
  std::string session_token = NextToken("hkm_session");
  g_variant_builder_add(&options, "{sv}", "handle_token",
                        g_variant_new_string(handle_token.c_str()));
  g_variant_builder_add(&options, "{sv}", "session_handle_token",
                        g_variant_new_string(session_token.c_str()));

  g_autoptr(GError) error = nullptr;
  g_autoptr(GVariant) result = g_dbus_proxy_call_sync(
      portal_, "CreateSession", g_variant_new("(a{sv})", &options),
      G_DBUS_CALL_FLAGS_NONE, -1, nullptr, &error);
  if (result == nullptr) {
    g_warning("GlobalShortcuts CreateSession call failed: %s",
              error != nullptr ? error->message : "unknown error");
    return;
  }

  const gchar* request_handle = nullptr;
  g_variant_get(result, "(&o)", &request_handle);
  SubscribeRequestResponse(connection_, request_handle, this, generation,
                           PortalRequestKind::create_session);
}

void HotkeyManagerPortalBackend::ListShortcuts(guint generation) {
  if (session_handle_.empty()) {
    return;
  }

  GVariantBuilder options;
  g_variant_builder_init(&options, G_VARIANT_TYPE_VARDICT);
  std::string handle_token = NextToken("hkm_list");
  g_variant_builder_add(&options, "{sv}", "handle_token",
                        g_variant_new_string(handle_token.c_str()));

  g_autoptr(GError) error = nullptr;
  g_autoptr(GVariant) result = g_dbus_proxy_call_sync(
      portal_, "ListShortcuts",
      g_variant_new("(oa{sv})", session_handle_.c_str(), &options),
      G_DBUS_CALL_FLAGS_NONE, -1, nullptr, &error);
  if (result == nullptr) {
    g_warning("GlobalShortcuts ListShortcuts call failed: %s",
              error != nullptr ? error->message : "unknown error");
    BindShortcuts(generation);
    return;
  }

  const gchar* request_handle = nullptr;
  g_variant_get(result, "(&o)", &request_handle);
  SubscribeRequestResponse(connection_, request_handle, this, generation,
                           PortalRequestKind::list_shortcuts);
}

void HotkeyManagerPortalBackend::BindShortcuts(guint generation) {
  if (session_handle_.empty()) {
    return;
  }

  GVariantBuilder shortcuts;
  g_variant_builder_init(&shortcuts, G_VARIANT_TYPE("a(sa{sv})"));
  for (const auto& item : hotkeys_) {
    GVariantBuilder properties;
    g_variant_builder_init(&properties, G_VARIANT_TYPE_VARDICT);

    std::string description = "Global shortcut";
    g_variant_builder_add(&properties, "{sv}", "description",
                          g_variant_new_string(description.c_str()));

    std::string preferred_trigger = TriggerForHotkey(item.second);
    if (!preferred_trigger.empty()) {
      g_variant_builder_add(&properties, "{sv}", "preferred_trigger",
                            g_variant_new_string(preferred_trigger.c_str()));
    }

    g_variant_builder_add(&shortcuts, "(s@a{sv})", item.first.c_str(),
                          g_variant_builder_end(&properties));
  }

  GVariantBuilder options;
  g_variant_builder_init(&options, G_VARIANT_TYPE_VARDICT);
  std::string handle_token = NextToken("hkm_bind");
  g_variant_builder_add(&options, "{sv}", "handle_token",
                        g_variant_new_string(handle_token.c_str()));

  g_autoptr(GError) error = nullptr;
  g_autoptr(GVariant) result = g_dbus_proxy_call_sync(
      portal_, "BindShortcuts",
      g_variant_new("(oa(sa{sv})sa{sv})", session_handle_.c_str(), &shortcuts,
                    "", &options),
      G_DBUS_CALL_FLAGS_NONE, -1, nullptr, &error);
  if (result == nullptr) {
    g_warning("GlobalShortcuts BindShortcuts call failed: %s",
              error != nullptr ? error->message : "unknown error");
    return;
  }

  const gchar* request_handle = nullptr;
  g_variant_get(result, "(&o)", &request_handle);
  SubscribeRequestResponse(connection_, request_handle, this, generation,
                           PortalRequestKind::bind_shortcuts);
}

void HotkeyManagerPortalBackend::CloseSession() {
  UnsubscribeShortcutSignals();

  if (connection_ != nullptr && !session_handle_.empty()) {
    g_autoptr(GError) error = nullptr;
    g_dbus_connection_call_sync(
        connection_, kPortalBusName, session_handle_.c_str(), kSessionInterface,
        "Close", g_variant_new("()"), nullptr, G_DBUS_CALL_FLAGS_NONE, -1,
        nullptr, &error);
    if (error != nullptr) {
      g_warning("GlobalShortcuts session close failed: %s", error->message);
    }
  }

  session_handle_.clear();
}

void HotkeyManagerPortalBackend::UnsubscribeRequestSignals() {
  if (connection_ == nullptr) {
    request_subscription_ids_.clear();
    return;
  }

  for (guint subscription_id : request_subscription_ids_) {
    g_dbus_connection_signal_unsubscribe(connection_, subscription_id);
  }
  request_subscription_ids_.clear();
}

void HotkeyManagerPortalBackend::SubscribeShortcutSignals() {
  if (connection_ == nullptr || session_handle_.empty()) {
    return;
  }

  UnsubscribeShortcutSignals();
  activated_subscription_id_ = g_dbus_connection_signal_subscribe(
      connection_, kPortalBusName, kGlobalShortcutsInterface, "Activated",
      kPortalObjectPath, nullptr, G_DBUS_SIGNAL_FLAGS_NONE,
      ShortcutSignalCallback, this, nullptr);
  deactivated_subscription_id_ = g_dbus_connection_signal_subscribe(
      connection_, kPortalBusName, kGlobalShortcutsInterface, "Deactivated",
      kPortalObjectPath, nullptr, G_DBUS_SIGNAL_FLAGS_NONE,
      ShortcutSignalCallback, this, nullptr);
}

void HotkeyManagerPortalBackend::UnsubscribeShortcutSignals() {
  if (connection_ == nullptr) {
    return;
  }
  if (activated_subscription_id_ != 0) {
    g_dbus_connection_signal_unsubscribe(connection_,
                                         activated_subscription_id_);
    activated_subscription_id_ = 0;
  }
  if (deactivated_subscription_id_ != 0) {
    g_dbus_connection_signal_unsubscribe(connection_,
                                         deactivated_subscription_id_);
    deactivated_subscription_id_ = 0;
  }
}

std::string HotkeyManagerPortalBackend::TriggerForHotkey(
    const PortalHotkey& hotkey) const {
  std::vector<std::string> trigger_parts;
  for (const std::string& modifier : hotkey.modifiers) {
    AddModifierToTrigger(modifier, &trigger_parts);
  }

  std::string key_name = NormalizeKeyName(gdk_keyval_name(hotkey.key_code));
  if (key_name.empty()) {
    g_warning("Unable to resolve key name for key code %u.", hotkey.key_code);
    return "";
  }
  trigger_parts.push_back(key_name);

  return JoinTriggerParts(trigger_parts);
}

bool HasMissingShortcuts(
    const std::map<std::string, PortalHotkey>& desired_hotkeys,
    const std::vector<std::string>& registered_shortcut_ids) {
  return std::any_of(
      desired_hotkeys.begin(), desired_hotkeys.end(),
      [&registered_shortcut_ids](const auto& desired_hotkey) {
        return std::find(registered_shortcut_ids.begin(),
                         registered_shortcut_ids.end(),
                         desired_hotkey.first) ==
               registered_shortcut_ids.end();
      });
}
