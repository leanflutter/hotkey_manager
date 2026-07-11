#include <flutter_linux/flutter_linux.h>
#include <gmock/gmock.h>
#include <gtest/gtest.h>

#include <map>
#include <string>
#include <vector>

#include "include/hotkey_manager_linux/hotkey_manager_linux_plugin.h"
#include "hotkey_manager_linux_plugin_private.h"
#include "hotkey_manager_portal_backend.h"

// This demonstrates a simple unit test of the C portion of this plugin's
// implementation.
//
// Once you have built the plugin's example app, you can run these tests
// from the command line. For instance, for a plugin called my_plugin
// built for x64 debug, run:
// $ build/linux/x64/debug/plugins/my_plugin/my_plugin_test

namespace hotkey_manager_linux {
namespace test {

TEST(HotkeyManagerLinuxPlugin, GetPlatformVersion) {
  g_autoptr(FlMethodResponse) response = get_platform_version();
  ASSERT_NE(response, nullptr);
  ASSERT_TRUE(FL_IS_METHOD_SUCCESS_RESPONSE(response));
  FlValue* result = fl_method_success_response_get_result(
      FL_METHOD_SUCCESS_RESPONSE(response));
  ASSERT_EQ(fl_value_get_type(result), FL_VALUE_TYPE_STRING);
  // The full string varies, so just validate that it has the right format.
  EXPECT_THAT(fl_value_get_string(result), testing::StartsWith("Linux "));
}

TEST(HotkeyManagerPortalBackend, FindsMissingShortcut) {
  const std::map<std::string, PortalHotkey> desired_hotkeys = {
      {"open-window", {0, {}}},
      {"toggle-mute", {0, {}}},
  };

  EXPECT_TRUE(HasMissingShortcuts(desired_hotkeys, {"open-window"}));
}

TEST(HotkeyManagerPortalBackend, ReusesPreviouslyRegisteredShortcuts) {
  const std::map<std::string, PortalHotkey> desired_hotkeys = {
      {"open-window", {0, {}}},
      {"toggle-mute", {0, {}}},
  };

  EXPECT_FALSE(HasMissingShortcuts(
      desired_hotkeys, {"toggle-mute", "unused-action", "open-window"}));
}

}  // namespace test
}  // namespace hotkey_manager_linux
