import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../../navigation/app_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = [
    _Slide(
      icon: PhosphorIconsFill.shieldCheck,
      title: 'Bloquea las distracciones',
      body:
          'Activa el escudo VPN y nunca más accederás a sitios que te alejan de tus metas. Silencio digital, atención plena.',
      accent: AppColors.primary,
    ),
    _Slide(
      icon: PhosphorIconsFill.clockCountdown,
      title: 'Controla el tiempo en apps',
      body:
          'Establece límites diarios en Instagram, TikTok y cualquier app que consuma tu tiempo. Recupera el control de tu jornada.',
      accent: AppColors.secondary,
    ),
    _Slide(
      icon: PhosphorIconsFill.lightning,
      title: 'Construye el hábito del enfoque',
      body:
          'Recordatorios motivacionales, racha de días y un puntaje de enfoque diario te mantienen en el camino correcto.',
      accent: AppColors.warning,
    ),
    _Slide(
      icon: PhosphorIconsFill.lock,
      title: 'Protégete con un PIN',
      body:
          'Configura un PIN de seguridad para proteger tus límites y ajustes. Solo acciones destructivas lo require. Es recomendado.',
      accent: AppColors.primary,
      isPinSlide: true,
    ),
    _Slide(
      icon: PhosphorIconsFill.prohibit,
      title: 'Bloqueo real de apps',
      body:
          'Para bloquear apps al alcanzar el límite, SaFocus necesita permiso de "Uso de apps" y "Superponer ventanas". Solo tardas 30 segundos en activarlos.',
      accent: AppColors.error,
    ),
  ];

  Future<void> _openPinSetup() async {
    if (!mounted) return;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const _PinSetupDialog(),
    );

    // If PIN was created, move to next slide
    if (result != null && mounted && _page == _slides.length - 2) {
      _next();
    }
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyOnboardingDone, true);
    if (mounted) context.go(AppRoutes.home);
  }

  Future<void> _openUsageSettings() async {
    try {
      await const MethodChannel(
        AppConstants.channelBlockControl,
      ).invokeMethod('openUsageSettings');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ve a Ajustes → Privacidad → Estadísticas de uso y activa SaFocus.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _openOverlaySettings() async {
    try {
      await const MethodChannel(
        AppConstants.channelBlockControl,
      ).invokeMethod('openOverlaySettings');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ve a Ajustes → Permisos especiales → Superponer ventanas y activa SaFocus.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Logo + skip row
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'lib/assets/logo.png',
                      height: 32,
                      fit: BoxFit.contain,
                    ),
                  ),
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Omitir',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _slides.length,
                itemBuilder: (_, i) => _SlidePage(slide: _slides[i]),
              ),
            ),

            // Dots + button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
              child: Column(
                children: [
                  // Indicator dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color:
                              active
                                  ? _slides[_page].accent
                                  : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
                  // PIN setup buttons (custom UI for PIN slide)
                  if (_slides[_page].isPinSlide) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _openPinSetup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _slides[_page].accent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Crear PIN',
                          style: AppTypography.labelLarge,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _next,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _slides[_page].accent),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Hacerlo después',
                          style: AppTypography.labelLarge.copyWith(
                            color: _slides[_page].accent,
                          ),
                        ),
                      ),
                    ),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _slides[_page].accent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _page == _slides.length - 1 ? 'Empezar' : 'Siguiente',
                          style: AppTypography.labelLarge,
                        ),
                      ),
                    ),
                  // On the last slide, show permission buttons.
                  if (_page == _slides.length - 1) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _openUsageSettings,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Activar: Estadísticas de uso',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _openOverlaySettings,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Activar: Superponer ventanas',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  final IconData icon;
  final String title;
  final String body;
  final Color accent;
  final bool isPinSlide;
  const _Slide({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
    this.isPinSlide = false,
  });
}

class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon circle
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: slide.accent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(slide.icon, size: 56, color: slide.accent),
          ),
          const SizedBox(height: 40),
          Text(
            slide.title,
            style: AppTypography.displayMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            slide.body,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PinSetupDialog extends StatefulWidget {
  const _PinSetupDialog();

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String _errorMsg = '';

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final p1 = _pinController.text.trim();
    final p2 = _confirmController.text.trim();

    if (p1.length < 4) {
      setState(() => _errorMsg = 'Mínimo 4 dígitos');
      return;
    }
    if (p1 != p2) {
      setState(() => _errorMsg = 'Los PINs no coinciden');
      return;
    }

    // Save PIN to AuthService
    try {
      await AuthService.instance.setPin(p1);
      if (mounted) {
        Navigator.pop(context, p1);
      }
    } catch (e) {
      setState(() => _errorMsg = 'Error al guardar el PIN');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      title: Row(
        children: [
          const Icon(
            PhosphorIconsRegular.lockKey,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Crear PIN', style: AppTypography.headlineSmall),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Nuevo PIN (4–6 dígitos)',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Confirmar PIN',
                counterText: '',
                errorText: _errorMsg.isNotEmpty ? _errorMsg : null,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
