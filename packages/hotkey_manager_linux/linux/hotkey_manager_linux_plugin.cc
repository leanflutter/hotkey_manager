#include "include/hotkey_manager_linux/hotkey_manager_linux_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>

#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "hotkey_manager_keybinder_backend.h"
#include "hotkey_manager_linux_backend.h"
#include "hotkey_manager_linux_plugin_private.h"
#include "hotkey_manager_portal_backend.h"

#define HOTKEY_MANAGER_LINUX_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), hotkey_manager_linux_plugin_get_type(), \
                              HotkeyManagerLinuxPlugin))

struct _HotkeyManagerLinuxPlugin {
  GObject parent_instance;
  FlEventChannel* event_channel;
  HotkeyManagerLinuxBackend* backend;
};

G_DEFINE_TYPE(HotkeyManagerLinuxPlugin,
              hotkey_manager_linux_plugin,
              g_object_get_type())

// Called when a method call is received from Flutter.
static void hotkey_manager_linux_plugin_handle_method_call(
    HotkeyManagerLinuxPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "register") == 0) {
    response = self->backend->Register(args);
  } else if (strcmp(method, "unregister") == 0) {
    response = self->backend->Unregister(args);
  } else if (strcmp(method, "unregisterAll") == 0) {
    response = self->backend->UnregisterAll();
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

FlMethodResponse* get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar* version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static void hotkey_manager_linux_plugin_dispose(GObject* object) {
  HotkeyManagerLinuxPlugin* self = HOTKEY_MANAGER_LINUX_PLUGIN(object);
  delete self->backend;
  self->backend = nullptr;
  g_clear_object(&self->event_channel);
  G_OBJECT_CLASS(hotkey_manager_linux_plugin_parent_class)->dispose(object);
}

static void hotkey_manager_linux_plugin_class_init(
    HotkeyManagerLinuxPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = hotkey_manager_linux_plugin_dispose;
}

static void hotkey_manager_linux_plugin_init(HotkeyManagerLinuxPlugin* self) {}

static bool is_x11_display() {
#ifdef GDK_WINDOWING_X11
  GdkDisplay* display = gdk_display_get_default();
  return display != nullptr && GDK_IS_X11_DISPLAY(display);
#else
  return false;
#endif
}

static HotkeyManagerLinuxBackend* create_backend(FlEventChannel* event_channel) {
  if (is_x11_display()) {
    return new HotkeyManagerKeybinderBackend(event_channel);
  }
  return new HotkeyManagerPortalBackend(event_channel);
}

static void method_call_cb(FlMethodChannel* channel,
                           FlMethodCall* method_call,
                           gpointer user_data) {
  HotkeyManagerLinuxPlugin* plugin = HOTKEY_MANAGER_LINUX_PLUGIN(user_data);
  hotkey_manager_linux_plugin_handle_method_call(plugin, method_call);
}

void hotkey_manager_linux_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  HotkeyManagerLinuxPlugin* plugin = HOTKEY_MANAGER_LINUX_PLUGIN(
      g_object_new(hotkey_manager_linux_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      "dev.leanflutter.plugins/hotkey_manager", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  g_autoptr(FlStandardMethodCodec) event_codec = fl_standard_method_codec_new();
  plugin->event_channel =
      fl_event_channel_new(fl_plugin_registrar_get_messenger(registrar),
                           "dev.leanflutter.plugins/hotkey_manager_event",
                           FL_METHOD_CODEC(event_codec));
  plugin->backend = create_backend(plugin->event_channel);

  g_object_unref(plugin);
}
