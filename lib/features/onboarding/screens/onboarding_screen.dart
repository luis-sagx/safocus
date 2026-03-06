import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/constants/app_constants.dart';
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
      icon: PhosphorIconsFill.prohibit,
      title: 'Bloqueo real de apps',
      body:
          'Para bloquear apps al alcanzar el límite, SaFocus necesita permiso de "Uso de apps" y "Superponer ventanas". Solo tardas 30 segundos en activarlos.',
      accent: AppColors.error,
    ),
  ];

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
                  Image.asset(
                    'lib/assets/logo.png',
                    height: 36,
                    fit: BoxFit.contain,
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
  const _Slide({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
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
