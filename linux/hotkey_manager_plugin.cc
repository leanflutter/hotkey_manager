#include "include/hotkey_manager/hotkey_manager_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gdk/gdkkeysyms.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <X11/X.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <cstring>

#include <keybinder.h>

#include <algorithm>
#include <map>
#include <string>
#include <vector>

#define HOTKEY_MANAGER_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), hotkey_manager_plugin_get_type(), \
                              HotkeyManagerPlugin))

/* 
  Map of the Flutter key codes to GDK key codes.

  Reference: https://gitlab.gnome.org/GNOME/gtk/-/blob/863b399899e0a835cde7de111e20900a036738f4/gdk/gdkkeysyms.h
 */
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
    std::make_pair("enter", GDK_KEY_Return),
    std::make_pair("escape", GDK_KEY_Escape),
    std::make_pair("backspace", GDK_KEY_BackSpace),
    std::make_pair("tab", GDK_KEY_Tab),
    std::make_pair("space", GDK_KEY_space),
    std::make_pair("minus", GDK_KEY_minus),
    std::make_pair("equal", GDK_KEY_equal),
    std::make_pair("bracketLeft", GDK_KEY_bracketleft),
    std::make_pair("bracketRight", GDK_KEY_bracketright),
    std::make_pair("backslash", GDK_KEY_backslash),
    std::make_pair("semicolon", GDK_KEY_semicolon),
    std::make_pair("quote", GDK_KEY_quoteright),
    std::make_pair("backquote", GDK_KEY_quoteleft),
    std::make_pair("comma", GDK_KEY_comma),
    std::make_pair("period", GDK_KEY_period),
    std::make_pair("slash", GDK_KEY_slash),
    std::make_pair("capsLock", GDK_KEY_Caps_Lock),
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
    // std::make_pair("printScreen", 0),
    std::make_pair("scrollLock", GDK_KEY_Scroll_Lock),
    std::make_pair("pause", GDK_KEY_Pause),
    std::make_pair("insert", GDK_KEY_Insert),
    std::make_pair("home", GDK_KEY_Home),
    std::make_pair("pageUp", GDK_KEY_Page_Up),
    std::make_pair("delete", GDK_KEY_Delete),
    std::make_pair("end", GDK_KEY_End),
    std::make_pair("pageDown", GDK_KEY_Page_Down),
    std::make_pair("arrowRight", GDK_KEY_Right),
    std::make_pair("arrowLeft", GDK_KEY_Left),
    std::make_pair("arrowDown", GDK_KEY_Down),
    std::make_pair("arrowUp", GDK_KEY_Up),
    std::make_pair("numLock", GDK_KEY_Num_Lock),
    std::make_pair("numpadDivide", GDK_KEY_KP_Divide),
    std::make_pair("numpadMultiply", GDK_KEY_KP_Multiply),
    std::make_pair("numpadSubtract", GDK_KEY_KP_Subtract),
    std::make_pair("numpadAdd", GDK_KEY_KP_Add),
    std::make_pair("numpadEnter", GDK_KEY_KP_Enter),
    std::make_pair("numpad1", GDK_KEY_KP_1),
    std::make_pair("numpad2", GDK_KEY_KP_2),
    std::make_pair("numpad3", GDK_KEY_KP_3),
    std::make_pair("numpad4", GDK_KEY_KP_4),
    std::make_pair("numpad5", GDK_KEY_KP_5),
    std::make_pair("numpad6", GDK_KEY_KP_6),
    std::make_pair("numpad7", GDK_KEY_KP_7),
    std::make_pair("numpad8", GDK_KEY_KP_8),
    std::make_pair("numpad9", GDK_KEY_KP_9),
    std::make_pair("numpad0", GDK_KEY_KP_0),
    std::make_pair("numpadDecimal", GDK_KEY_KP_Decimal),
    // std::make_pair("intlBackslash", 0),
    std::make_pair("contextMenu", GDK_KEY_Menu),
    std::make_pair("power", GDK_KEY_PowerDown),
    std::make_pair("numpadEqual", GDK_KEY_KP_Equal),
    std::make_pair("f13", GDK_KEY_F13),
    std::make_pair("f14", GDK_KEY_F14),
    std::make_pair("f15", GDK_KEY_F15),
    std::make_pair("f16", GDK_KEY_F16),
    std::make_pair("f17", GDK_KEY_F17),
    std::make_pair("f18", GDK_KEY_F18),
    std::make_pair("f19", GDK_KEY_F19),
    std::make_pair("f20", GDK_KEY_F20),
    std::make_pair("f21", GDK_KEY_F21),
    std::make_pair("f22", GDK_KEY_F22),
    std::make_pair("f23", GDK_KEY_F23),
    std::make_pair("f24", GDK_KEY_F24),
    std::make_pair("open", GDK_KEY_Open),
    std::make_pair("help", GDK_KEY_Help),
    std::make_pair("select", GDK_KEY_Select),
    std::make_pair("again", GDK_KEY_Redo),
    std::make_pair("undo", GDK_KEY_Undo),
    std::make_pair("cut", GDK_KEY_Cut),
    std::make_pair("copy", GDK_KEY_Copy),
    std::make_pair("paste", GDK_KEY_Paste),
    std::make_pair("find", GDK_KEY_Find),
    std::make_pair("audioVolumeMute", GDK_KEY_AudioMute),
    std::make_pair("audioVolumeUp", GDK_KEY_AudioRaiseVolume),
    std::make_pair("audioVolumeDown", GDK_KEY_AudioLowerVolume),
    std::make_pair("numpadComma", GDK_KEY_KP_Separator),
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
    std::make_pair("abort", GDK_KEY_Cancel),
    // std::make_pair("props", 0),
    std::make_pair("numpadParenLeft", GDK_KEY_KP_Left),
    std::make_pair("numpadParenRight", GDK_KEY_KP_Right),
    std::make_pair("numpadBackspace", GDK_KEY_KP_Delete),
    // std::make_pair("numpadMemoryStore", 0),
    // std::make_pair("numpadMemoryRecall", 0),
    // std::make_pair("numpadMemoryClear", 0),
    // std::make_pair("numpadMemoryAdd", 0),
    // std::make_pair("numpadMemorySubtract", 0),
    // std::make_pair("numpadSignChange", 0),
    // std::make_pair("numpadClear", 0),
    // std::make_pair("numpadClearEntry", 0),
    std::make_pair("controlLeft", GDK_KEY_Control_L),
    std::make_pair("shiftLeft", GDK_KEY_Shift_L),
    std::make_pair("altLeft", GDK_KEY_Alt_L),
    std::make_pair("metaLeft", GDK_KEY_Super_L),
    std::make_pair("controlRight", GDK_KEY_Control_R),
    std::make_pair("shiftRight", GDK_KEY_Shift_R),
    std::make_pair("altRight", GDK_KEY_Alt_R),
    std::make_pair("metaRight", GDK_KEY_Super_R),
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
    std::make_pair("mediaPlay", GDK_KEY_AudioPlay),
    std::make_pair("mediaPause", GDK_KEY_AudioPause),
    std::make_pair("mediaRecord", GDK_KEY_AudioRecord),
    std::make_pair("mediaFastForward", GDK_KEY_AudioForward),
    std::make_pair("mediaRewind", GDK_KEY_AudioRewind),
    std::make_pair("mediaTrackNext", GDK_KEY_AudioNext),
    std::make_pair("mediaTrackPrevious", GDK_KEY_AudioPrev),
    std::make_pair("mediaStop", GDK_KEY_AudioStop),
    std::make_pair("eject", GDK_KEY_Eject),
    std::make_pair("mediaPlayPause", GDK_KEY_AudioPlay),
    // std::make_pair("speechInputToggle", 0),
    // std::make_pair("bassBoost", 0),
    // std::make_pair("mediaSelect", 0),
    // std::make_pair("launchWordProcessor", 0),
    // std::make_pair("launchSpreadsheet", 0),
    // std::make_pair("launchMail", 0),
    // std::make_pair("launchContacts", 0),
    // std::make_pair("launchCalendar", 0),
    // std::make_pair("launchApp2", 0),
    // std::make_pair("launchApp1", 0),
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
    // std::make_pair("print", 0),
    // std::make_pair("browserSearch", 0),
    // std::make_pair("browserHome", 0),
    // std::make_pair("browserBack", 0),
    // std::make_pair("browserForward", 0),
    // std::make_pair("browserStop", 0),
    // std::make_pair("browserRefresh", 0),
    // std::make_pair("browserFavorites", 0),
    // std::make_pair("zoomIn", 0),
    // std::make_pair("zoomOut", 0),
    // std::make_pair("zoomToggle", 0),
    std::make_pair("redo", GDK_KEY_Redo),
    // std::make_pair("mailReply", 0),
    // std::make_pair("mailForward", 0),
    // std::make_pair("mailSend", 0),
    // std::make_pair("keyboardLayoutSelect", 0),
    // std::make_pair("showAllWindows", 0),
    // std::make_pair("fn", 0),
    std::make_pair("shift", GDK_KEY_Shift_L),
    std::make_pair("meta", GDK_KEY_Super_L),
    std::make_pair("alt", GDK_KEY_Alt_L),
    std::make_pair("control", GDK_KEY_Control_L),
};

HotkeyManagerPlugin* plugin_instance;
std::map<std::string, std::string> hotkey_id_map;

struct _HotkeyManagerPlugin {
  GObject parent_instance;
  FlPluginRegistrar* registrar;
  FlMethodChannel* channel;
};

// Gets the window being controlled.
GtkWindow* get_window(HotkeyManagerPlugin* self) {
  FlView* view = fl_plugin_registrar_get_view(self->registrar);
  if (view == nullptr)
    return nullptr;

  return GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

G_DEFINE_TYPE(HotkeyManagerPlugin, hotkey_manager_plugin, g_object_get_type())

void handle_key_down(const char* keystring, void* user_data) {
  const char* identifier;

  std::string val = keystring;
  auto result = std::find_if(hotkey_id_map.begin(), hotkey_id_map.end(),
                             [val](const auto& e) { return e.second == val; });

  if (result != hotkey_id_map.end())
    identifier = result->first.c_str();

  g_autoptr(FlValue) result_data = fl_value_new_map();
  fl_value_set_string_take(result_data, "identifier",
                           fl_value_new_string(identifier));
  fl_method_channel_invoke_method(plugin_instance->channel, "onKeyDown",
                                  result_data, nullptr, nullptr, nullptr);
}

guint get_keyval(const char* key_code) {
  return known_virtual_key_codes[key_code];
}

guint get_mods(const std::vector<std::string>& modifiers) {
  guint mods = 0;
  for (int i = 0; i < modifiers.size(); i++) {
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

static FlMethodResponse* hkm_register(HotkeyManagerPlugin* self,
                                      FlValue* args) {
  FlValue* modifiers_value = fl_value_lookup_string(args, "modifiers");

  const char* identifier =
      fl_value_get_string(fl_value_lookup_string(args, "identifier"));
  const char* key_code =
      fl_value_get_string(fl_value_lookup_string(args, "keyCode"));
  std::vector<std::string> modifiers;
  for (gint i = 0; i < fl_value_get_length(modifiers_value); i++) {
    std::string keyModifier =
        fl_value_get_string(fl_value_get_list_value(modifiers_value, i));
    modifiers.push_back(keyModifier);
  }

  const char* keystring = gtk_accelerator_name(
      get_keyval(key_code), (GdkModifierType)get_mods(modifiers));

  hotkey_id_map.insert(
      std::pair<std::string, std::string>(identifier, keystring));

  keybinder_init();
  keybinder_bind(keystring, handle_key_down, NULL);

  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(true)));
}

static FlMethodResponse* hkm_unregister(HotkeyManagerPlugin* self,
                                        FlValue* args) {
  const char* identifier =
      fl_value_get_string(fl_value_lookup_string(args, "identifier"));
  const char* keystring;

  std::string val = identifier;
  auto result = std::find_if(hotkey_id_map.begin(), hotkey_id_map.end(),
                             [val](const auto& e) { return e.first == val; });

  if (result != hotkey_id_map.end())
    keystring = result->second.c_str();

  keybinder_unbind(keystring, handle_key_down);
  hotkey_id_map.erase(identifier);

  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(true)));
}

static FlMethodResponse* hkm_unregister_all(HotkeyManagerPlugin* self,
                                            FlValue* args) {
  for (std::map<std::string, std::string>::iterator it = hotkey_id_map.begin();
       it != hotkey_id_map.end(); ++it) {
    std::string identifier = it->first;
    const char* keystring = it->second.c_str();
    keybinder_unbind(keystring, handle_key_down);
  }

  hotkey_id_map.clear();

  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(true)));
}

// Called when a method call is received from Flutter.
static void hotkey_manager_plugin_handle_method_call(
    HotkeyManagerPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "register") == 0) {
    response = hkm_register(self, args);
  } else if (strcmp(method, "unregister") == 0) {
    response = hkm_unregister(self, args);
  } else if (strcmp(method, "unregisterAll") == 0) {
    response = hkm_unregister_all(self, args);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void hotkey_manager_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(hotkey_manager_plugin_parent_class)->dispose(object);
}

static void hotkey_manager_plugin_class_init(HotkeyManagerPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = hotkey_manager_plugin_dispose;
}

static void hotkey_manager_plugin_init(HotkeyManagerPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel,
                           FlMethodCall* method_call,
                           gpointer user_data) {
  HotkeyManagerPlugin* plugin = HOTKEY_MANAGER_PLUGIN(user_data);
  hotkey_manager_plugin_handle_method_call(plugin, method_call);
}

void hotkey_manager_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  HotkeyManagerPlugin* plugin = HOTKEY_MANAGER_PLUGIN(
      g_object_new(hotkey_manager_plugin_get_type(), nullptr));

  plugin->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "hotkey_manager", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      plugin->channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  plugin_instance = plugin;
  g_object_unref(plugin);
}
