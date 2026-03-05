import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../services/auth_service.dart';

/// Full-screen PIN entry / lock screen.
/// Shows biometric option if enabled.
/// Locks out after 3 failed attempts for 1 minute.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthenticated});

  final VoidCallback onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = AuthService.instance;
  String _pin = '';
  String _error = '';
  bool _loading = false;
  bool _biometricAvailable = false;
  Timer? _lockoutTimer;
  int _expectedLength = 4; // loaded from secure storage on init

  @override
  void initState() {
    super.initState();
    _loadExpectedLength();
    _checkBiometric();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadExpectedLength() async {
    final len = await _auth.getPinLength();
    if (mounted) setState(() => _expectedLength = len);
  }

  Future<void> _checkBiometric() async {
    if (_auth.isBiometricEnabled) {
      final available = await _auth.isBiometricAvailable;
      if (mounted) {
        setState(() => _biometricAvailable = available);
        if (available) _tryBiometric();
      }
    }
  }

  Future<void> _tryBiometric() async {
    final ok = await _auth.authenticateWithBiometrics();
    if (ok && mounted) widget.onAuthenticated();
  }

  void _onDigit(int digit) {
    if (_auth.isLockedOut) {
      _startLockoutTimer();
      return;
    }
    if (_pin.length >= _expectedLength) return;
    setState(() {
      _pin += digit.toString();
      _error = '';
    });
    // No auto-verify: user must press Confirm when ready
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = '';
    });
  }

  Future<void> _tryVerify() async {
    if (_loading) return;
    setState(() => _loading = true);

    final ok = await _auth.verifyPin(_pin);
    if (!mounted) return;

    if (ok) {
      widget.onAuthenticated();
    } else {
      setState(() {
        _pin = '';
        _loading = false;
        if (_auth.isLockedOut) {
          _error = 'Demasiados intentos. Espera 1 minuto.';
          _startLockoutTimer();
        } else {
          final remaining = AuthService.maxAttempts - _auth.failedAttempts;
          _error =
              'PIN incorrecto. $remaining intento${remaining == 1 ? '' : 's'} restante${remaining == 1 ? '' : 's'}.';
        }
      });
    }
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_auth.isLockedOut) {
        _lockoutTimer?.cancel();
        if (mounted) setState(() => _error = '');
      } else {
        if (mounted) {
          final secs = _auth.remainingLockout.inSeconds;
          setState(() {
            _error = 'Bloqueado. Intenta de nuevo en ${secs}s.';
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            // Lock icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                PhosphorIconsFill.lock,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text('Ingresa tu PIN', style: AppTypography.headlineLarge),
            const SizedBox(height: 8),
            Text(
              'Protege tus configuraciones',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // PIN dots (count = expected length)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_expectedLength, (i) {
                final filled = i < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color:
                          filled ? AppColors.primary : AppColors.textSecondary,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),

            // Error message
            const SizedBox(height: 16),
            SizedBox(
              height: 20,
              child:
                  _error.isNotEmpty
                      ? Text(
                        _error,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      )
                      : null,
            ),

            const Spacer(flex: 1),

            // Numpad
            _buildNumpad(),

            const SizedBox(height: 20),

            // Confirm button — enabled only when PIN is complete
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      (_pin.length == _expectedLength && !_loading)
                          ? _tryVerify
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _loading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text(
                            'Confirmar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Biometric button
            if (_biometricAvailable)
              TextButton.icon(
                onPressed: _tryBiometric,
                icon: const Icon(
                  PhosphorIconsRegular.fingerprint,
                  color: AppColors.primary,
                ),
                label: Text(
                  'Usar biometría',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),

            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          _numRow([1, 2, 3]),
          const SizedBox(height: 12),
          _numRow([4, 5, 6]),
          const SizedBox(height: 12),
          _numRow([7, 8, 9]),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 72, height: 72),
              _numButton(0),
              _backspaceButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numRow(List<int> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _numButton(d)).toList(),
    );
  }

  Widget _numButton(int digit) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(36),
        child: InkWell(
          borderRadius: BorderRadius.circular(36),
          onTap: () => _onDigit(digit),
          child: Center(
            child: Text(
              '$digit',
              style: AppTypography.displayMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _backspaceButton() {
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(36),
        child: InkWell(
          borderRadius: BorderRadius.circular(36),
          onTap: _onBackspace,
          child: const Center(
            child: Icon(
              PhosphorIconsRegular.backspace,
              color: AppColors.textSecondary,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  REUSABLE AUTH GATE — wraps a critical action with auth
// ══════════════════════════════════════════════════════════════════════════

/// Shows the auth screen (PIN or biometric) before executing [onAuthed].
/// If auth is not enabled, executes immediately.
Future<bool> requireAuth(
  BuildContext context, {
  required Future<void> Function() onAuthed,
}) async {
  final auth = AuthService.instance;
  if (!auth.isAuthEnabled) {
    await onAuthed();
    return true;
  }

  // Try biometric first
  if (auth.isBiometricEnabled) {
    final bioAvailable = await auth.isBiometricAvailable;
    if (bioAvailable) {
      final ok = await auth.authenticateWithBiometrics();
      if (ok) {
        await onAuthed();
        return true;
      }
    }
  }

  // Fall back to PIN dialog
  if (!auth.isPinEnabled) {
    // Only biometric was enabled but failed
    return false;
  }

  if (!context.mounted) return false;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PinDialog(onAuthed: onAuthed),
  );
  return result ?? false;
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.onAuthed});
  final Future<void> Function() onAuthed;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _auth = AuthService.instance;
  final _controller = TextEditingController();
  String _error = '';
  bool _loading = false;
  int _expectedLength = 4;

  @override
  void initState() {
    super.initState();
    _loadExpectedLength();
  }

  Future<void> _loadExpectedLength() async {
    final len = await _auth.getPinLength();
    if (mounted) setState(() => _expectedLength = len);
  }

  Future<void> _verify() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = '';
    });

    final pin = _controller.text;
    if (pin.length != _expectedLength) {
      setState(() {
        _error = 'El PIN debe tener exactamente $_expectedLength dígitos';
        _loading = false;
      });
      return;
    }

    final ok = await _auth.verifyPin(pin);
    if (!mounted) return;

    if (ok) {
      await widget.onAuthed();
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() {
        _controller.clear();
        _loading = false;
        if (_auth.isLockedOut) {
          _error = 'Demasiados intentos. Espera 1 minuto.';
        } else {
          final remaining = AuthService.maxAttempts - _auth.failedAttempts;
          _error =
              'PIN incorrecto. $remaining intento${remaining == 1 ? '' : 's'}.';
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Row(
        children: [
          const Icon(
            PhosphorIconsRegular.lock,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text('Verificar PIN', style: AppTypography.headlineSmall),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Ingresa tu PIN',
              counterText: '',
              errorText: _error.isNotEmpty ? _error : null,
            ),
            onSubmitted: (_) => _verify(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _verify,
          child:
              _loading
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Verificar'),
        ),
      ],
    );
  }
}
