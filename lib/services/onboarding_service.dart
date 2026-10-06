import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_log.dart';

/// Recuerda si el usuario ya vio (u omitió) el tutorial de bienvenida, para
/// mostrarlo solo en la primera apertura de la app. Sigue el patrón
/// Singleton + SharedPreferences del resto de servicios.
class OnboardingService {
  static const String _completedKey = 'onboarding_completed';

  static final OnboardingService _instance = OnboardingService._internal();
  factory OnboardingService() => _instance;
  OnboardingService._internal();

  bool _completed = false;

  bool get shouldShow => !_completed;

  /// Debe llamarse una vez antes de `runApp`, igual que
  /// `RegionService().load()` en `main.dart`.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _completed = prefs.getBool(_completedKey) ?? false;
    } catch (e) {
      AppLog.error('Error cargando OnboardingService', e);
      _completed = false;
    }
  }

  Future<void> markCompleted() async {
    _completed = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_completedKey, true);
    } catch (e) {
      AppLog.error('Error guardando OnboardingService', e);
    }
  }
}
