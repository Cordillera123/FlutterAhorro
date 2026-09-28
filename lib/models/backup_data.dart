/// Modelo del "sobre" de copia de seguridad.
///
/// Contiene metadata (versión de formato, fecha, versión de la app) más
/// los datos crudos de cada servicio, ya serializados con sus propios
/// `toJson()` — este modelo no conoce la forma interna de cada entidad,
/// solo transporta las listas.
class BackupData {
  /// Versión del formato del backup (independiente de la versión de la app).
  /// Incrementar solo cuando cambie la estructura del sobre o se necesite
  /// una migración entre versiones de backup.
  static const int currentFormatVersion = 1;

  final int formatVersion;
  final DateTime exportedAt;
  final String appVersion;

  final List<Map<String, dynamic>> accounts;
  final String activeAccountId;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> budgets;
  final List<Map<String, dynamic>> financialGoals;
  final List<Map<String, dynamic>> goalContributions;
  final List<Map<String, dynamic>> customCategories;
  final List<Map<String, dynamic>> recurringExpenses;

  BackupData({
    required this.formatVersion,
    required this.exportedAt,
    required this.appVersion,
    required this.accounts,
    required this.activeAccountId,
    required this.transactions,
    required this.budgets,
    required this.financialGoals,
    required this.goalContributions,
    required this.customCategories,
    required this.recurringExpenses,
  });

  Map<String, dynamic> toJson() {
    return {
      'formatVersion': formatVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'appVersion': appVersion,
      'data': {
        'accounts': accounts,
        'activeAccountId': activeAccountId,
        'transactions': transactions,
        'budgets': budgets,
        'financialGoals': financialGoals,
        'goalContributions': goalContributions,
        'customCategories': customCategories,
        'recurringExpenses': recurringExpenses,
      },
    };
  }

  /// Parsea y valida la ESTRUCTURA del sobre (no valida aún cada entidad
  /// individual — eso lo hace BackupService al intentar reconstruir los
  /// modelos). Lanza [FormatException] con mensaje claro si algo no calza.
  factory BackupData.fromJson(Map<String, dynamic> json) {
    final formatVersion = json['formatVersion'];
    if (formatVersion is! int) {
      throw const FormatException(
        'El archivo no tiene un formato de copia de seguridad válido.',
      );
    }
    if (formatVersion > currentFormatVersion) {
      throw FormatException(
        'Esta copia de seguridad fue creada con una versión más nueva de '
        'la app (formato $formatVersion). Actualiza la app para poder '
        'restaurarla.',
      );
    }

    final exportedAtRaw = json['exportedAt'];
    final data = json['data'];
    if (exportedAtRaw is! String || data is! Map) {
      throw const FormatException(
        'El archivo no tiene un formato de copia de seguridad válido.',
      );
    }

    DateTime exportedAt;
    try {
      exportedAt = DateTime.parse(exportedAtRaw);
    } catch (_) {
      throw const FormatException(
        'El archivo no tiene un formato de copia de seguridad válido.',
      );
    }

    final dataMap = Map<String, dynamic>.from(data);

    return BackupData(
      formatVersion: formatVersion,
      exportedAt: exportedAt,
      appVersion: json['appVersion'] as String? ?? 'desconocida',
      accounts: _asMapList(dataMap['accounts']),
      activeAccountId: dataMap['activeAccountId'] as String? ?? '',
      transactions: _asMapList(dataMap['transactions']),
      budgets: _asMapList(dataMap['budgets']),
      financialGoals: _asMapList(dataMap['financialGoals']),
      goalContributions: _asMapList(dataMap['goalContributions']),
      customCategories: _asMapList(dataMap['customCategories']),
      recurringExpenses: _asMapList(dataMap['recurringExpenses']),
    );
  }

  static List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) {
      throw const FormatException(
        'El archivo no tiene un formato de copia de seguridad válido.',
      );
    }
    return value.map((item) {
      if (item is! Map) {
        throw const FormatException(
          'El archivo no tiene un formato de copia de seguridad válido.',
        );
      }
      return Map<String, dynamic>.from(item);
    }).toList();
  }
}
