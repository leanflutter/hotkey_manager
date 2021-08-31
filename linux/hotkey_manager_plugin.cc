#include "include/hotkey_manager/hotkey_manager_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <gdk/gdkkeysyms.h>
#include <sys/utsname.h>

#include <cstring>
#include <X11/X.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>

#include <keybinder.h>

#include <map>
#include <vector>
#include <algorithm>
#include <string>

#define HOTKEY_MANAGER_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), hotkey_manager_plugin_get_type(), \
                              HotkeyManagerPlugin))

std::map<std::string, uint> known_virtual_key_codes = {
    std::make_pair("keyA", GDK_KEY_a),
    std::make_pair("keyB", GDK_KEY_b),
    std::make_pair("keyC", GDK_KEY_c),
    std::make_pair("keyD", GDK_KEY_d),
    std::make_pair("keyE", GDK_KEY_e),
    std::make_pair("keyF", GDK_KEY_f),
    std::make_pair("keyG", GDK_KEY_g),
    std::make_pair("keyH", GDK_KEY_h),
    std::make_pair("keyI", GDK_KEY_i),
    std::make_pair("keyJ", GDK_KEY_j),
    std::make_pair("keyK", GDK_KEY_k),
    std::make_pair("keyL", GDK_KEY_l),
    std::make_pair("keyM", GDK_KEY_m),
    std::make_pair("keyN", GDK_KEY_n),
    std::make_pair("keyO", GDK_KEY_o),
    std::make_pair("keyP", GDK_KEY_p),
    std::make_pair("keyQ", GDK_KEY_q),
    std::make_pair("keyR", GDK_KEY_r),
    std::make_pair("keyS", GDK_KEY_s),
    std::make_pair("keyT", GDK_KEY_t),
    std::make_pair("keyU", GDK_KEY_u),
    std::make_pair("keyV", GDK_KEY_v),
    std::make_pair("keyW", GDK_KEY_w),
    std::make_pair("keyX", GDK_KEY_x),
    std::make_pair("keyY", GDK_KEY_y),
    std::make_pair("keyZ", GDK_KEY_z),
    std::make_pair("digit1", GDK_KEY_1),
    std::make_pair("digit2", GDK_KEY_2),
    std::make_pair("digit3", GDK_KEY_3),
    std::make_pair("digit4", GDK_KEY_4),
    std::make_pair("digit5", GDK_KEY_5),
    std::make_pair("digit6", GDK_KEY_6),
    std::make_pair("digit7", GDK_KEY_7),
    std::make_pair("digit8", GDK_KEY_8),
    std::make_pair("digit9", GDK_KEY_9),
    std::make_pair("digit0", GDK_KEY_0),
    // std::make_pair("enter", VK_RETURN),
    // std::make_pair("escape", VK_SPACE),
    // std::make_pair("backspace", VK_BACK),
    // std::make_pair("tab", VK_TAB),
    // std::make_pair("space", VK_SPACE),
    // std::make_pair("minus", VK_OEM_MINUS),
    // std::make_pair("equal", 0),
    // std::make_pair("bracketLeft", 0),
    // std::make_pair("bracketRight", 0),
    // std::make_pair("backslash", 0),
    // std::make_pair("semicolon", 0),
    // std::make_pair("quote", 0),
    // std::make_pair("backquote", 0),
    // std::make_pair("comma", 0),
    // std::make_pair("period", 0),
    // std::make_pair("slash", 0),
    // std::make_pair("capsLock", VK_CAPITAL),
    std::make_pair("f1", GDK_KEY_F1),
    std::make_pair("f2", GDK_KEY_F2),
    std::make_pair("f3", GDK_KEY_F3),
    std::make_pair("f4", GDK_KEY_F4),
    std::make_pair("f5", GDK_KEY_F5),
    std::make_pair("f6", GDK_KEY_F6),
    std::make_pair("f7", GDK_KEY_F7),
    std::make_pair("f8", GDK_KEY_F8),
    std::make_pair("f9", GDK_KEY_F9),
    std::make_pair("f10", GDK_KEY_F10),
    std::make_pair("f11", GDK_KEY_F11),
    std::make_pair("f12", GDK_KEY_F12),
    // std::make_pair("printScreen", VK_SNAPSHOT),
    // std::make_pair("scrollLock", VK_SCROLL),
    // std::make_pair("pause", VK_PAUSE),
    // std::make_pair("insert", VK_INSERT),
    // std::make_pair("home", VK_HOME),
    // std::make_pair("pageUp", VK_PRIOR),
    // std::make_pair("delete", VK_DELETE),
    // std::make_pair("end", VK_END),
    // std::make_pair("pageDown", VK_NEXT),
    // std::make_pair("arrowRight", VK_RIGHT),
    // std::make_pair("arrowLeft", VK_LEFT),
    // std::make_pair("arrowDown", VK_DOWN),
    // std::make_pair("arrowUp", VK_UP),
    // std::make_pair("numLock", VK_NUMLOCK),
    // std::make_pair("numpadDivide", VK_DIVIDE),
    // std::make_pair("numpadMultiply", VK_MULTIPLY),
    // std::make_pair("numpadSubtract", VK_SUBTRACT),
    // std::make_pair("numpadAdd", VK_ADD),
    // std::make_pair("numpadEnter", 0),
    // std::make_pair("numpad1", VK_NUMPAD1),
    // std::make_pair("numpad2", VK_NUMPAD2),
    // std::make_pair("numpad3", VK_NUMPAD3),
    // std::make_pair("numpad4", VK_NUMPAD4),
    // std::make_pair("numpad5", VK_NUMPAD5),
    // std::make_pair("numpad6", VK_NUMPAD6),
    // std::make_pair("numpad7", VK_NUMPAD7),
    // std::make_pair("numpad8", VK_NUMPAD8),
    // std::make_pair("numpad9", VK_NUMPAD9),
    // std::make_pair("numpad0", VK_NUMPAD0),
    // std::make_pair("numpadDecimal", VK_DECIMAL),
    // std::make_pair("intlBackslash", 0),
    // std::make_pair("contextMenu", 0),
    // std::make_pair("power", 0),
    // std::make_pair("numpadEqual", 0),
    // std::make_pair("f13", VK_F13),
    // std::make_pair("f14", VK_F14),
    // std::make_pair("f15", VK_F15),
    // std::make_pair("f16", VK_F16),
    // std::make_pair("f17", VK_F17),
    // std::make_pair("f18", VK_F18),
    // std::make_pair("f19", VK_F19),
    // std::make_pair("f20", VK_F20),
    // std::make_pair("f21", VK_F21),
    // std::make_pair("f22", VK_F22),
    // std::make_pair("f23", VK_F23),
    // std::make_pair("f24", VK_F24),
    // std::make_pair("open", 0),
    // std::make_pair("help", VK_HELP),
    // std::make_pair("select", VK_SELECT),
    // std::make_pair("again", 0),
    // std::make_pair("undo", 0),
    // std::make_pair("cut", 0),
    // std::make_pair("copy", 0),
    // std::make_pair("paste", 0),
    // std::make_pair("find", 0),
    // std::make_pair("audioVolumeMute", VK_VOLUME_MUTE),
    // std::make_pair("audioVolumeUp", VK_VOLUME_UP),
    // std::make_pair("audioVolumeDown", VK_VOLUME_DOWN),
    // std::make_pair("numpadComma", 0),
    // std::make_pair("intlRo", 0),
    // std::make_pair("kanaMode", 0),
    // std::make_pair("intlYen", 0),
    // std::make_pair("convert", 0),
    // std::make_pair("nonConvert", 0),
    // std::make_pair("lang1", 0),
    // std::make_pair("lang2", 0),
    // std::make_pair("lang3", 0),
    // std::make_pair("lang4", 0),
    // std::make_pair("lang5", 0),
    // std::make_pair("abort", 0),
    // std::make_pair("props", 0),
    // std::make_pair("numpadParenLeft", 0),
    // std::make_pair("numpadParenRight", 0),
    // std::make_pair("numpadBackspace", 0),
    // std::make_pair("numpadMemoryStore", 0),
    // std::make_pair("numpadMemoryRecall", 0),
    // std::make_pair("numpadMemoryClear", 0),
    // std::make_pair("numpadMemoryAdd", 0),
    // std::make_pair("numpadMemorySubtract", 0),
    // std::make_pair("numpadSignChange", 0),
    // std::make_pair("numpadClear", 0),
    // std::make_pair("numpadClearEntry", 0),
    // std::make_pair("controlLeft", VK_LCONTROL),
    // std::make_pair("shiftLeft", VK_LSHIFT),
    // std::make_pair("altLeft", 0),
    // std::make_pair("metaLeft", VK_LWIN),
    // std::make_pair("controlRight", VK_RCONTROL),
    // std::make_pair("shiftRight", VK_RSHIFT),
    // std::make_pair("altRight", 0),
    // std::make_pair("metaRight", VK_RWIN),
    // std::make_pair("info", 0),
    // std::make_pair("closedCaptionToggle", 0),
    // std::make_pair("brightnessUp", 0),
    // std::make_pair("brightnessDown", 0),
    // std::make_pair("brightnessToggle", 0),
    // std::make_pair("brightnessMinimum", 0),
    // std::make_pair("brightnessMaximum", 0),
    // std::make_pair("brightnessAuto", 0),
    // std::make_pair("kbdIllumUp", 0),
    // std::make_pair("kbdIllumDown", 0),
    // std::make_pair("mediaLast", 0),
    // std::make_pair("launchPhone", 0),
    // std::make_pair("programGuide", 0),
    // std::make_pair("exit", 0),
    // std::make_pair("channelUp", 0),
    // std::make_pair("channelDown", 0),
    // std::make_pair("mediaPlay", VK_MEDIA_PLAY_PAUSE),
    // std::make_pair("mediaPause", VK_MEDIA_PLAY_PAUSE),
    // std::make_pair("mediaRecord", 0),
    // std::make_pair("mediaFastForward", 0),
    // std::make_pair("mediaRewind", 0),
    // std::make_pair("mediaTrackNext", VK_MEDIA_NEXT_TRACK),
    // std::make_pair("mediaTrackPrevious", VK_MEDIA_PREV_TRACK),
    // std::make_pair("mediaStop", VK_MEDIA_STOP),
    // std::make_pair("eject", 0),
    // std::make_pair("mediaPlayPause", 0),
    // std::make_pair("speechInputToggle", 0),
    // std::make_pair("bassBoost", 0),
    // std::make_pair("mediaSelect", VK_LAUNCH_MEDIA_SELECT),
    // std::make_pair("launchWordProcessor", 0),
    // std::make_pair("launchSpreadsheet", 0),
    // std::make_pair("launchMail", VK_LAUNCH_MAIL),
    // std::make_pair("launchContacts", 0),
    // std::make_pair("launchCalendar", 0),
    // std::make_pair("launchApp2", VK_LAUNCH_APP2),
    // std::make_pair("launchApp1", VK_LAUNCH_APP1),
    // std::make_pair("launchInternetBrowser", 0),
    // std::make_pair("logOff", 0),
    // std::make_pair("lockScreen", 0),
    // std::make_pair("launchControlPanel", 0),
    // std::make_pair("selectTask", 0),
    // std::make_pair("launchDocuments", 0),
    // std::make_pair("spellCheck", 0),
    // std::make_pair("launchKeyboardLayout", 0),
    // std::make_pair("launchScreenSaver", 0),
    // std::make_pair("launchAssistant", 0),
    // std::make_pair("launchAudioBrowser", 0),
    // std::make_pair("newKey", 0),
    // std::make_pair("close", 0),
    // std::make_pair("save", 0),
    // std::make_pair("print", VK_PRINT),
    // std::make_pair("browserSearch", VK_BROWSER_SEARCH),
    // std::make_pair("browserHome", VK_BROWSER_HOME),
    // std::make_pair("browserBack", VK_BROWSER_BACK),
    // std::make_pair("browserForward", VK_BROWSER_FORWARD),
    // std::make_pair("browserStop", VK_BROWSER_STOP),
    // std::make_pair("browserRefresh", VK_BROWSER_REFRESH),
    // std::make_pair("browserFavorites", VK_BROWSER_FAVORITES),
    // std::make_pair("zoomIn", 0),
    // std::make_pair("zoomOut", 0),
    // std::make_pair("zoomToggle", 0),
    // std::make_pair("redo", 0),
    // std::make_pair("mailReply", 0),
    // std::make_pair("mailForward", 0),
    // std::make_pair("mailSend", 0),
    // std::make_pair("keyboardLayoutSelect", 0),
    // std::make_pair("showAllWindows", 0),
    // std::make_pair("fn", 0),
    // std::make_pair("shift", VK_SHIFT),
    // std::make_pair("meta", VK_LWIN),
    // std::make_pair("alt", VK_MENU),
    // std::make_pair("control", VK_CONTROL),
};

HotkeyManagerPlugin *plugin_instance;
std::map<std::string, std::string> hotkey_map;

struct _HotkeyManagerPlugin
{
  GObject parent_instance;
  FlPluginRegistrar *registrar;
  FlMethodChannel *channel;
};

// Gets the window being controlled.
GtkWindow *get_window(HotkeyManagerPlugin *self)
{
  FlView *view = fl_plugin_registrar_get_view(self->registrar);
  if (view == nullptr)
    return nullptr;

  return GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

G_DEFINE_TYPE(HotkeyManagerPlugin, hotkey_manager_plugin, g_object_get_type())

void handle_key_down(const char *keystring, void *user_data)
{
  const char *identifier;

  std::string val = keystring;
  auto result = std::find_if(
      hotkey_map.begin(),
      hotkey_map.end(),
      [val](const auto &e)
      { return e.second == val; });

  if (result != hotkey_map.end())
    identifier = result->first.c_str();

  g_autoptr(FlValue) result_data = fl_value_new_map();
  fl_value_set_string_take(result_data, "identifier", fl_value_new_string(identifier));
  fl_method_channel_invoke_method(plugin_instance->channel,
                                  "onKeyDown", result_data,
                                  nullptr, nullptr, nullptr);
}

guint get_keyval(const char *key_code)
{
  return known_virtual_key_codes[key_code];
}

guint get_mods(const std::vector<std::string> &modifiers)
{
  guint mods = 0;
  for (int i = 0; i < modifiers.size(); i++)
  {
    guint mod = 0;
    if (modifiers[i] == "shift")
      mod = GDK_SHIFT_MASK;
    else if (modifiers[i] == "control")
      mod = GDK_CONTROL_MASK;
    else if (modifiers[i] == "alt")
      mod = GDK_MOD1_MASK;
    else if (modifiers[i] == "meta")
      mod = GDK_META_MASK;
    mods = mods | mod;
  }
  return mods;
}

static FlMethodResponse *hkm_register(HotkeyManagerPlugin *self,
                                      FlValue *args)
{
  FlValue *modifiers_value = fl_value_lookup_string(args, "modifiers");

  const char *identifier = fl_value_get_string(fl_value_lookup_string(args, "identifier"));
  const char *key_code = fl_value_get_string(fl_value_lookup_string(args, "keyCode"));
  std::vector<std::string> modifiers;
  for (gint i = 0; i < fl_value_get_length(modifiers_value); i++)
  {
    std::string keyModifier = fl_value_get_string(fl_value_get_list_value(modifiers_value, i));
    modifiers.push_back(keyModifier);
  }

  const char *keystring = gtk_accelerator_name(
      get_keyval(key_code),
      (GdkModifierType)get_mods(modifiers));

  hotkey_map.insert(std::pair<std::string, std::string>(identifier, keystring));

  keybinder_init();
  keybinder_bind(keystring, handle_key_down, NULL);

  return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(true)));
}

static FlMethodResponse *hkm_unregister(HotkeyManagerPlugin *self,
                                        FlValue *args)
{
  const char *identifier = fl_value_get_string(fl_value_lookup_string(args, "identifier"));
  const char *keystring;

  std::string val = identifier;
  auto result = std::find_if(
      hotkey_map.begin(),
      hotkey_map.end(),
      [val](const auto &e)
      { return e.first == val; });

  if (result != hotkey_map.end())
    keystring = result->second.c_str();

  keybinder_unbind(keystring, handle_key_down);

  return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(true)));
}

// Called when a method call is received from Flutter.
static void hotkey_manager_plugin_handle_method_call(
    HotkeyManagerPlugin *self,
    FlMethodCall *method_call)
{
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar *method = fl_method_call_get_name(method_call);
  FlValue *args = fl_method_call_get_args(method_call);

  if (strcmp(method, "register") == 0)
  {
    response = hkm_register(self, args);
  }
  else if (strcmp(method, "unregister") == 0)
  {
    response = hkm_unregister(self, args);
  }
  else
  {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void hotkey_manager_plugin_dispose(GObject *object)
{
  G_OBJECT_CLASS(hotkey_manager_plugin_parent_class)->dispose(object);
}

static void hotkey_manager_plugin_class_init(HotkeyManagerPluginClass *klass)
{
  G_OBJECT_CLASS(klass)->dispose = hotkey_manager_plugin_dispose;
}

static void hotkey_manager_plugin_init(HotkeyManagerPlugin *self) {}

static void method_call_cb(FlMethodChannel *channel, FlMethodCall *method_call,
                           gpointer user_data)
{
  HotkeyManagerPlugin *plugin = HOTKEY_MANAGER_PLUGIN(user_data);
  hotkey_manager_plugin_handle_method_call(plugin, method_call);
}

void hotkey_manager_plugin_register_with_registrar(FlPluginRegistrar *registrar)
{
  HotkeyManagerPlugin *plugin = HOTKEY_MANAGER_PLUGIN(
      g_object_new(hotkey_manager_plugin_get_type(), nullptr));

  plugin->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "hotkey_manager",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(plugin->channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  plugin_instance = plugin;
  g_object_unref(plugin);
}
