> **hotkey_manager 从 0.3.0 起基于 [nativeapi](https://pub.dev/packages/nativeapi) 构建**，
> 通过 Dart FFI 使用共享的 [libnativeapi C++ 核心](https://github.com/libnativeapi/nativeapi-core)。
> 从 0.2.x 升级？原有 HotKey API 保持兼容，环境要求和平台差异见 [nativeapi 迁移](#nativeapi-迁移)。

# hotkey_manager

[![pub version][pub-image]][pub-url] [![][discord-image]][discord-url] ![][visits-count-image] 

[pub-image]: https://img.shields.io/pub/v/hotkey_manager.svg
[pub-url]: https://pub.dev/packages/hotkey_manager

[discord-image]: https://img.shields.io/discord/884679008049037342.svg
[discord-url]: https://discord.gg/zPa6EZ2jqb

[visits-count-image]: https://img.shields.io/badge/dynamic/json?label=Visits%20Count&query=value&url=https://api.countapi.xyz/hit/leanflutter.hotkey_manager/visits

这个插件支持 Flutter 桌面应用的系统和应用内快捷键，以及 Android 应用的应用内硬件键盘快捷键。

---

[English](./README.md) | 简体中文

---

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [hotkey_manager](#hotkey_manager)
  - [平台支持](#平台支持)
  - [快速开始](#快速开始)
    - [安装](#安装)
      - [Linux requirements](#linux-requirements)
    - [用法](#用法)
  - [谁在用使用它？](#谁在用使用它)
  - [API](#api)
    - [HotKeyManager](#hotkeymanager)
  - [相关链接](#相关链接)
  - [许可证](#许可证)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## nativeapi 迁移

系统快捷键通过 Dart FFI 使用 nativeapi C++ 核心，不再依赖各平台原生插件。
需要 Dart 3.13+、Flutter 3.47+ 和 **nativeapi/cnativeapi 0.5.6+**。
两个依赖均已发布到 pub.dev，无需本地依赖覆盖。

`package:hotkey_manager/native.dart` 单独导出 `ShortcutManager`、`ShortcutOptions`
和快捷键事件，避免与 Flutter 的同名类型冲突。推荐使用
`registerWithOptions` 注册、`addListener` 接收事件，回调会异步送达 Dart isolate。
注销时先调用 `unregisterWithId(shortcut.id)`，再调用 `shortcut.dispose()`；仅释放句柄
不会注销原生快捷键。完整示例见 [英文文档](README.md#native-api) 和 example 应用。

旧 `HotKeyManager`、`HotKey`、录制/展示组件及全局快捷键组件仍可从原入口导入，
也可使用 `package:hotkey_manager/legacy.dart`，历史 JSON 格式继续兼容。
普通应用内快捷键由 Flutter 处理，macOS 媒体键通过 nativeapi 处理，均支持按下和抬起事件。
系统快捷键的抬起事件支持 macOS，以及发送释放通知的 Wayland Portal 提供方；
Windows 和 X11 仅支持按下事件。macOS 系统媒体键需要操作系统授权。
Android 仅支持应用内硬件键盘快捷键，系统级注册会明确返回错误。
Fn 系统修饰键支持 macOS；CapsLock 支持 macOS 和 X11。Windows 保持旧版忽略
Fn/CapsLock 的行为，Linux 忽略 Fn。旧平台键码继续覆盖媒体键、国际键和小键盘键；
Windows 系统快捷键保留原生长按连发策略。无法映射的键位会抛出 `PlatformException`。
Linux 支持 X11（含 XWayland），也支持通过 GlobalShortcuts Portal 注册原生 Wayland 快捷键。
Wayland 请使用 `await hotKeyManager.register(...)` 等待桌面结果，最终组合键由桌面决定；注销、组件销毁和热重启清理
会取消尚未完成的请求。

原 `HotKeyManagerPlatform` 和 `MethodChannelHotKeyManager` 接口及平台替换能力继续保留，
默认实现使用 nativeapi。`registeredHotKeyList` 保持实时列表；
同一 identifier 重复注册时，未重传的回调继续保留；不同 identifier 注册相同组合键会共享原生注册，
并分别收到事件。`hotKeyManager.unregisterAll()` 只清理本包快捷键（含热重启遗留），
不会影响直接通过 `ShortcutManager` 注册的快捷键。

## 平台支持

| Linux | macOS | Windows | Android |
| :---: | :---: | :-----: | :-----: |
| ✔️ | ✔️ | ✔️ | 仅应用内 |

## 快速开始

### 安装

在 `pubspec.yaml` 中添加已发布的依赖：

```yaml
dependencies:
  hotkey_manager: ^0.3.0
```

#### Linux requirements

原生 Wayland 需要运行中的桌面会话和支持 `org.freedesktop.portal.GlobalShortcuts`
的提供方；仅安装通用 Portal 软件包不够。非沙箱应用还需安装与 GTK 应用 ID 同名的
`.desktop` 文件。桌面不支持、权限拒绝或应用身份无效时会返回 `PlatformException`。

```bash
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev libx11-dev libxi-dev
```

### 用法

```dart
import 'package:hotkey_manager/hotkey_manager.dart';

void main() async {
  // 必须加上这一行。
  WidgetsFlutterBinding.ensureInitialized();
  // 清理热重启后遗留的原生注册。
  await hotKeyManager.unregisterAll();

  runApp(MyApp());
}
```

注册/卸载一个系统/应用范围的热键。

```dart
// ⌥ + Q
HotKey _hotKey = HotKey(
  key: PhysicalKeyboardKey.keyQ,
  modifiers: [HotKeyModifier.alt],
  // 设置热键范围（默认为 HotKeyScope.system）
  scope: HotKeyScope.inapp, // 设置为应用范围的热键。
);
await hotKeyManager.register(
  _hotKey,
  keyDownHandler: (hotKey) {
    print('onKeyDown+${hotKey.toJson()}');
  },
  // 系统抬起事件支持 macOS 和提供释放通知的 Wayland Portal；应用内快捷键支持抬起事件。
  keyUpHandler: (hotKey){
    print('onKeyUp+${hotKey.toJson()}');
  } ,
);

await hotKeyManager.unregister(_hotKey);

await hotKeyManager.unregisterAll();
```

使用 `HotKeyRecorder` 小部件帮助您录制一个热键。

```dart
HotKeyRecorder(
  onHotKeyRecorded: (hotKey) {
    _hotKey = hotKey;
    setState(() {});
  },
),
```

> 请看这个插件的示例应用，以了解完整的例子。

## 谁在用使用它？

- [Airclap](https://airclap.app/) - 任何文件，任意设备，随意发送。简单好用的跨平台高速文件传输APP。
- [AuthPass](https://authpass.app/) - 基于Flutter的密码管理器，适用于所有平台。兼容Keepass 2.x（kdbx 3.x）。
- [Biyi (比译)](https://biyidev.com/) - 一个便捷的翻译和词典应用程序。

## API

### HotKeyManager

| Method        | Description                       | Linux | macOS | Windows |
| ------------- | --------------------------------- | ----- | ----- | ------- |
| register      | 注册一个系统/应用范围的热键。     | ✔️     | ✔️     | ✔️       |
| unregister    | 取消注册一个系统/应用范围的热键。 | ✔️     | ✔️     | ✔️       |
| unregisterAll | 取消注册全部系统/应用范围的热键。 | ✔️     | ✔️     | ✔️       |

## 相关链接

- [nativeapi](https://github.com/libnativeapi/nativeapi)
- [nativeapi C++ core](https://github.com/libnativeapi/nativeapi-core)

## 许可证

[MIT](./LICENSE)
