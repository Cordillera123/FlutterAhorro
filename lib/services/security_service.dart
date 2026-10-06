import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../utils/app_info.dart';
import '../utils/app_log.dart';

/// Servicio de seguridad de la app: bloqueo con PIN, biometría y la
/// preferencia de ocultar saldos.
///
/// El PIN nunca se guarda en texto plano: se almacena su hash SHA-256
/// (con una sal aleatoria por instalación) en almacenamiento cifrado del
/// sistema operativo (Keystore en Android, Keychain en iOS), a través de
/// [FlutterSecureStorage] — no en SharedPreferences.
///
/// Sigue el patrón Singleton + ChangeNotifier del resto de servicios.
class SecurityService extends ChangeNotifier {
  static const String _kLockEnabledKey = 'security_lock_enabled';
  static const String _kPinHashKey = 'security_pin_hash';
  static const String _kPinSaltKey = 'security_pin_salt';
  static const String _kBiometricEnabledKey = 'security_biometric_enabled';
  static const String _kHideBalancesKey = 'security_hide_balances';

  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _initialized = false;
  bool _lockEnabled = false;
  bool _biometricEnabled = false;
  bool _hideBalances = false;
  bool _hasPin = false;

  bool get isLockEnabled => _lockEnabled;
  bool get isBiometricEnabled => _biometricEnabled;
  bool get hideBalances => _hideBalances;
  bool get hasPin => _hasPin;

  /// Debe llamarse una vez antes de `runApp`, igual que se hace con
  /// `AccountService().loadAccounts()` en `main.dart`.
  Future<void> init() async {
    if (_initialized) return;
    try {
      final lockEnabled = await _storage.read(key: _kLockEnabledKey);
      final biometricEnabled = await _storage.read(key: _kBiometricEnabledKey);
      final hideBalances = await _storage.read(key: _kHideBalancesKey);
      final pinHash = await _storage.read(key: _kPinHashKey);

      _lockEnabled = lockEnabled == 'true';
      _biometricEnabled = biometricEnabled == 'true';
      _hideBalances = hideBalances == 'true';
      _hasPin = pinHash != null && pinHash.isNotEmpty;
    } catch (e) {
      AppLog.error('Error inicializando SecurityService', e);
      _lockEnabled = false;
      _biometricEnabled = false;
      _hideBalances = false;
      _hasPin = false;
    } finally {
      _initialized = true;
    }
  }

  // ─── PIN ────────────────────────────────────────────────────────────────

  /// Crea o reemplaza el PIN y activa el bloqueo.
  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);

    await _storage.write(key: _kPinSaltKey, value: salt);
    await _storage.write(key: _kPinHashKey, value: hash);
    await _storage.write(key: _kLockEnabledKey, value: 'true');

    _hasPin = true;
    _lockEnabled = true;
    notifyListeners();
  }

  /// Verifica el PIN ingresado contra el hash guardado.
  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _kPinSaltKey);
    final storedHash = await _storage.read(key: _kPinHashKey);
    if (salt == null || storedHash == null) return false;
    return _hashPin(pin, salt) == storedHash;
  }

  /// Desactiva el bloqueo por completo (PIN + biometría) y borra el PIN
  /// guardado. Los datos financieros de la app NO se ven afectados — esto
  /// solo quita la puerta de acceso a la UI, para permitir recuperarse de
  /// un PIN olvidado sin perder información.
  Future<void> disableLock() async {
    await _storage.delete(key: _kPinHashKey);
    await _storage.delete(key: _kPinSaltKey);
    await _storage.write(key: _kLockEnabledKey, value: 'false');
    await _storage.write(key: _kBiometricEnabledKey, value: 'false');

    _hasPin = false;
    _lockEnabled = false;
    _biometricEnabled = false;
    notifyListeners();
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  // ─── Biometría ──────────────────────────────────────────────────────────

  /// `true` si el dispositivo soporta biometría (o bloqueo de dispositivo)
  /// y tiene algo enrolado. En plataformas sin soporte (web) devuelve
  /// `false` en vez de lanzar una excepción.
  Future<bool> isBiometricAvailable() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return false;
      final available = await _localAuth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (e) {
      AppLog.error('Biometría no disponible', e);
      return false;
    }
  }

  /// Activa/desactiva el uso de biometría como atajo para desbloquear.
  /// Requiere que ya haya un PIN configurado (la biometría nunca sustituye
  /// por completo al PIN, que sigue siendo el respaldo).
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: _kBiometricEnabledKey,
      value: enabled ? 'true' : 'false',
    );
    _biometricEnabled = enabled;
    notifyListeners();
  }

  /// Muestra el prompt nativo de biometría. Devuelve `false` (sin lanzar)
  /// si el usuario cancela, falla la verificación, o la plataforma no
  /// soporta biometría.
  Future<bool> authenticateWithBiometrics({
    String reason = 'Confirma tu identidad para acceder a ${AppInfo.name}',
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } catch (e) {
      AppLog.error('Autenticación biométrica no completada', e);
      return false;
    }
  }

  // ─── Ocultar saldos ─────────────────────────────────────────────────────

  Future<void> setHideBalances(bool hide) async {
    await _storage.write(
      key: _kHideBalancesKey,
      value: hide ? 'true' : 'false',
    );
    _hideBalances = hide;
    notifyListeners();
  }
}
