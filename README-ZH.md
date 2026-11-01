> **🚀 快速发布您的应用**: 试试 [Fastforge](https://fastforge.dev) - 构建、打包和分发您的 Flutter 应用最简单的方式。

# hotkey_manager

[![pub version][pub-image]][pub-url] [![][discord-image]][discord-url] ![][visits-count-image] 

[pub-image]: https://img.shields.io/pub/v/hotkey_manager.svg
[pub-url]: https://pub.dev/packages/hotkey_manager

[discord-image]: https://img.shields.io/discord/884679008049037342.svg
[discord-url]: https://discord.gg/zPa6EZ2jqb

[visits-count-image]: https://img.shields.io/badge/dynamic/json?label=Visits%20Count&query=value&url=https://api.countapi.xyz/hit/leanflutter.hotkey_manager/visits

这个插件允许 Flutter 桌面应用定义系统/应用范围内的热键（即快捷键）。

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
需要 Dart 3.13+、Flutter 3.47+ 和 **nativeapi/cnativeapi 0.5.4+** 的原生键码支持。
该依赖版本发布前，需要通过本地覆盖指向匹配的 nativeapi 工作区源码。

`package:hotkey_manager/native.dart` 单独导出 `ShortcutManager`、`ShortcutOptions`
和快捷键事件，避免与 Flutter 的同名类型冲突。推荐使用
`registerWithOptions` 注册、`addListener` 接收事件，回调会异步送达 Dart isolate。
注销时先调用 `unregisterWithId(shortcut.id)`，再调用 `shortcut.dispose()`；仅释放句柄
不会注销原生快捷键。完整示例见 [英文文档](README.md#native-api) 和 example 应用。

旧 `HotKeyManager`、`HotKey`、录制/展示组件及全局快捷键组件仍可从原入口导入，
也可使用 `package:hotkey_manager/legacy.dart`，历史 JSON 格式继续兼容。
应用内快捷键仍由 Flutter 处理，各平台都支持按下和抬起事件。
系统快捷键的抬起事件仅支持 macOS；Windows、Linux 仅支持按下事件。
Fn 系统修饰键支持 macOS；CapsLock 支持 macOS 和 Linux。Windows 保持旧版忽略
Fn/CapsLock 的行为，Linux 忽略 Fn。旧平台键码继续覆盖媒体键、国际键和小键盘键；
Windows 系统快捷键保留原生长按连发策略。无法映射的键位会抛出 `PlatformException`。
Linux 系统快捷键需要 X11（含 XWayland），暂不支持原生 Wayland。

原 `HotKeyManagerPlatform` 和 `MethodChannelHotKeyManager` 接口及平台替换能力继续保留，
默认实现使用 nativeapi。`registeredHotKeyList` 保持实时列表；
同一 identifier 重复注册时，未重传的回调继续保留；不同 identifier 注册相同组合键会共享原生注册，
并分别收到事件。`hotKeyManager.unregisterAll()` 只清理本包快捷键（含热重启遗留），
不会影响直接通过 `ShortcutManager` 注册的快捷键。

## 平台支持

| Linux | macOS | Windows |
| :---: | :---: | :-----: |
|   ✔️   |   ✔️   |    ✔️    |

## 快速开始

### 安装

使用以下 Git 依赖体验本文描述的 nativeapi 迁移：

```yaml
dependencies:
  hotkey_manager:
    git:
      path: packages/hotkey_manager
      url: https://github.com/leanflutter/hotkey_manager.git
      ref: main
```

#### Linux requirements

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
  // 系统快捷键的抬起事件仅限 macOS，应用内快捷键各平台都支持。
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
