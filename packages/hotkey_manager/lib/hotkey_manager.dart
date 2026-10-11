library;

export 'package:nativeapi/nativeapi.dart'
    show
        ListenerId,
        Shortcut,
        ShortcutActivatedEvent,
        ShortcutEvent,
        ShortcutId,
        ShortcutManager,
        ShortcutOptions,
        ShortcutRegisteredEvent,
        ShortcutRegistrationFailedEvent,
        ShortcutReleasedEvent,
        ShortcutScope,
        ShortcutUnregisteredEvent;

// Existing imports keep the HotKey model, manager and Flutter widgets working.
export 'legacy.dart';
