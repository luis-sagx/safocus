import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../../../data/local/local_storage.dart';
import '../../../core/constants/app_constants.dart';

/// Centralised authentication service: PIN (SHA-256 hashed) + biometric.
class AuthService {
  static final AuthService _instance = AuthService._();
  static AuthService get instance => _instance;

  AuthService._();

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _localAuth = LocalAuthentication();

  // ── Keys in secure storage ───────────────────────────────────────────
  static const _keyPinHash = 'safocus_pin_hash';
  static const _keyPinSalt = 'safocus_pin_salt';
  static const _keyPinLength = 'safocus_pin_length';

  // ── Lockout ──────────────────────────────────────────────────────────
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  static const int maxAttempts = 3;
  static const Duration lockoutDuration = Duration(minutes: 1);

  // ══════════════════════════════════════════════════════════════════════
  //  PIN MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════

  /// Hash a PIN with a salt using SHA-256.
  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  /// Generate a simple salt from current time.
  String _generateSalt() {
    final bytes = utf8.encode(DateTime.now().toIso8601String());
    return sha256.convert(bytes).toString().substring(0, 16);
  }

  /// Save a new PIN (hashed + salted).
  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await _secureStorage.write(key: _keyPinHash, value: hash);
    await _secureStorage.write(key: _keyPinSalt, value: salt);
    await _secureStorage.write(key: _keyPinLength, value: '${pin.length}');
    await LocalStorage.instance.setBool(AppConstants.keyPinEnabled, true);
    _failedAttempts = 0;
    _lockoutUntil = null;
  }

  /// Returns the length of the stored PIN (4, 5, or 6). Defaults to 4.
  Future<int> getPinLength() async {
    final v = await _secureStorage.read(key: _keyPinLength);
    return int.tryParse(v ?? '') ?? 4;
  }

  /// Verify a PIN against the stored hash.
  Future<bool> verifyPin(String pin) async {
    // Check lockout
    if (isLockedOut) return false;

    final storedHash = await _secureStorage.read(key: _keyPinHash);
    final storedSalt = await _secureStorage.read(key: _keyPinSalt);
    if (storedHash == null || storedSalt == null) return false;

    final inputHash = _hashPin(pin, storedSalt);
    if (inputHash == storedHash) {
      _failedAttempts = 0;
      _lockoutUntil = null;
      return true;
    }

    _failedAttempts++;
    if (_failedAttempts >= maxAttempts) {
      _lockoutUntil = DateTime.now().add(lockoutDuration);
    }
    return false;
  }

  /// Remove PIN.
  Future<void> removePin() async {
    await _secureStorage.delete(key: _keyPinHash);
    await _secureStorage.delete(key: _keyPinSalt);
    await _secureStorage.delete(key: _keyPinLength);
    await LocalStorage.instance.setBool(AppConstants.keyPinEnabled, false);
    _failedAttempts = 0;
    _lockoutUntil = null;
  }

  /// Whether a PIN is currently set.
  Future<bool> get hasPinSet async {
    final hash = await _secureStorage.read(key: _keyPinHash);
    return hash != null && hash.isNotEmpty;
  }

  /// Whether user is currently locked out.
  bool get isLockedOut {
    if (_lockoutUntil == null) return false;
    if (DateTime.now().isAfter(_lockoutUntil!)) {
      _lockoutUntil = null;
      _failedAttempts = 0;
      return false;
    }
    return true;
  }

  /// Remaining lockout duration.
  Duration get remainingLockout {
    if (_lockoutUntil == null) return Duration.zero;
    final remaining = _lockoutUntil!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  int get failedAttempts => _failedAttempts;

  // ══════════════════════════════════════════════════════════════════════
  //  BIOMETRIC AUTH
  // ══════════════════════════════════════════════════════════════════════

  /// Check if biometric auth is available on device.
  Future<bool> get isBiometricAvailable async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Get available biometric types.
  Future<List<BiometricType>> get availableBiometrics async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Authenticate with biometrics.
  Future<bool> authenticateWithBiometrics({
    String reason = 'Autenticación requerida para continuar',
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  COMBINED AUTH
  // ══════════════════════════════════════════════════════════════════════

  /// Whether auth is required (PIN or biometric enabled).
  bool get isAuthEnabled {
    final pinEnabled = LocalStorage.instance.getBool(
      AppConstants.keyPinEnabled,
    );
    final bioEnabled = LocalStorage.instance.getBool(
      AppConstants.keyBiometricEnabled,
    );
    return pinEnabled || bioEnabled;
  }

  /// Whether PIN is enabled.
  bool get isPinEnabled =>
      LocalStorage.instance.getBool(AppConstants.keyPinEnabled);

  /// Whether biometric is enabled.
  bool get isBiometricEnabled =>
      LocalStorage.instance.getBool(AppConstants.keyBiometricEnabled);

  /// Enable biometric auth.
  Future<void> enableBiometric() async {
    await LocalStorage.instance.setBool(AppConstants.keyBiometricEnabled, true);
  }

  /// Disable biometric auth.
  Future<void> disableBiometric() async {
    await LocalStorage.instance.setBool(
      AppConstants.keyBiometricEnabled,
      false,
    );
  }
}
