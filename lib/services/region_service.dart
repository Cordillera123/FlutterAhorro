import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/region.dart';
import '../utils/app_log.dart';

/// Región/moneda activa de la app. Sigue el patrón Singleton +
/// ChangeNotifier del resto de servicios, persistido en SharedPreferences.
///
/// Por defecto es [Region.ecuador], el mercado al que está dirigida la app,
/// pero queda como una preferencia editable en Configuración — no como un
/// valor fijo en el código.
class RegionService extends ChangeNotifier {
  static const String _regionKey = 'region_selected';

  static final RegionService _instance = RegionService._internal();
  factory RegionService() => _instance;
  RegionService._internal();

  Region _current = Region.ecuador;

  Region get current => _current;

  /// Debe llamarse una vez antes de `runApp`, igual que con
  /// `AccountService().loadAccounts()` en `main.dart`.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_regionKey);
      if (saved != null) {
        _current = Region.values.firstWhere(
          (r) => r.name == saved,
          orElse: () => Region.ecuador,
        );
      }
    } catch (e) {
      AppLog.error('Error cargando RegionService', e);
      _current = Region.ecuador;
    }
  }

  Future<void> setRegion(Region region) async {
    if (region == _current) return;
    _current = region;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_regionKey, region.name);
    } catch (e) {
      AppLog.error('Error guardando RegionService', e);
    }
  }
}
