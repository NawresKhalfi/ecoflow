/// Catégories de notifications activables (US-009).
enum NotificationCategory { collectionStatus, points, marketplace }

class NotificationPreferences {
  const NotificationPreferences(this.enabled);

  /// Tout est activé par défaut.
  static const defaults = NotificationPreferences({
    NotificationCategory.collectionStatus: true,
    NotificationCategory.points: true,
    NotificationCategory.marketplace: true,
  });

  final Map<NotificationCategory, bool> enabled;

  bool isEnabled(NotificationCategory c) => enabled[c] ?? true;

  NotificationPreferences toggle(NotificationCategory c, bool value) =>
      NotificationPreferences({...enabled, c: value});

  Map<String, bool> toMap() => {
        for (final c in NotificationCategory.values) c.name: isEnabled(c),
      };

  static NotificationPreferences fromMap(Map<String, dynamic>? m) {
    if (m == null) return defaults;
    return NotificationPreferences({
      for (final c in NotificationCategory.values) c: m[c.name] as bool? ?? true,
    });
  }
}
