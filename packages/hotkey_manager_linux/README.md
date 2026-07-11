# hotkey_manager_linux

[![pub version][pub-image]][pub-url]

[pub-image]: https://img.shields.io/pub/v/hotkey_manager_linux.svg
[pub-url]: https://pub.dev/packages/hotkey_manager_linux

The Linux implementation of [hotkey_manager](https://pub.dev/packages/hotkey_manager).

## Backends

On X11, global shortcuts are registered with
[`keybinder-3.0`](https://github.com/kupferlauncher/keybinder).

On Wayland, global shortcuts are registered with the
[`org.freedesktop.portal.GlobalShortcuts`](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.GlobalShortcuts.html)
desktop portal. The compositor may show a permission dialog the first time
shortcuts are bound. The portal backend emits both `onKeyDown` and `onKeyUp`
events when the compositor sends activation and deactivation signals.

Applications should reuse a stable, semantic `HotKey.identifier` for each
system shortcut across launches. The backend queries `ListShortcuts` and reuses
portal-owned bindings when all requested identifiers already exist; it calls
`BindShortcuts` only when an identifier is missing. Adding a shortcut can
therefore show the portal dialog again. A requested key combination is only a
preference for a new binding; change an existing binding through the desktop's
shortcut configuration UI. The portal has no portable API for removing one
persisted shortcut, so unregistering only stops handling that shortcut in the
current application session.

Recent versions of `xdg-desktop-portal` require host applications to have an
installed `.desktop` file whose basename matches the Linux `application-id`
(for example, `com.example.MyApp.desktop` for `com.example.MyApp`). Wayland
compositors without a GlobalShortcuts portal backend, such as some Niri/wlroots
setups, will still reject global shortcut registration.

The Wayland portal does not have portable equivalents for the `capsLock` and
`fn` modifiers, so those modifiers may be ignored by the compositor.

## License

[MIT](./LICENSE)
