/// Elimina mensajes duplicados por id y aplica límites por sección.
class MessageDeduplicator {
  List<T> dedupeAndLimit<T>({
    required List<T> items,
    required String Function(T) idExtractor,
    required int limit,
    int Function(T, T)? priorityComparator,
  }) {
    final seen = <String>{};
    final unique = <T>[];

    for (final item in items) {
      final id = idExtractor(item);
      if (seen.contains(id)) continue;
      seen.add(id);
      unique.add(item);
    }

    if (priorityComparator != null) {
      unique.sort(priorityComparator);
    }

    if (unique.length <= limit) return unique;
    return unique.sublist(0, limit);
  }
}
