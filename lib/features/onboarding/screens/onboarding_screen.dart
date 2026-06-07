import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../../../navigation/app_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  List<_Slide> _slides(BuildContext context) {
    final strings = AppStrings.of(context);
    return [
      _Slide(
        icon: PhosphorIconsFill.shieldCheck,
        title: strings.onboardingSlide1Title,
        body: strings.onboardingSlide1Body,
        accent: AppColors.primary,
      ),
      _Slide(
        icon: PhosphorIconsFill.clockCountdown,
        title: strings.onboardingSlide2Title,
        body: strings.onboardingSlide2Body,
        accent: AppColors.secondary,
      ),
      _Slide(
        icon: PhosphorIconsFill.lightning,
        title: strings.onboardingSlide3Title,
        body: strings.onboardingSlide3Body,
        accent: AppColors.warning,
      ),
      _Slide(
        icon: PhosphorIconsFill.lock,
        title: strings.onboardingSlide4Title,
        body: strings.onboardingSlide4Body,
        accent: AppColors.primary,
        isPinSlide: true,
      ),
      _Slide(
        icon: PhosphorIconsFill.prohibit,
        title: strings.onboardingSlide5Title,
        body: strings.onboardingSlide5Body,
        accent: AppColors.error,
      ),
    ];
  }

  Future<void> _openPinSetup() async {
    if (!mounted) return;
    final slides = _slides(context);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const _PinSetupDialog(),
    );

    // If PIN was created, move to next slide
    if (result != null && mounted && _page == slides.length - 2) {
      // Ensure SettingsProvider reflects the new PIN state so the toggle
      // in SettingsScreen appears enabled immediately.
      try {
        final container = ProviderScope.containerOf(context);
        // Call togglePin to persist and update provider state. If PIN was
        // already saved by AuthService, this is idempotent.
        await container
            .read(
              // ignore: invalid_use_of_visible_for_testing_member
              // Using the notifier provider directly to update settings state.
              // This keeps the SettingsState in sync with LocalStorage.
              // The settings provider path is resolved at compile time.
              // We import the provider to access it.
              // NOTE: We import flutter_riverpod above to access ProviderScope.
              // Using a dynamic read to avoid circular imports in some setups.
              settingsProvider.notifier,
            )
            .togglePin(true, pin: result);
      } catch (_) {
        // ignore errors; fallback is that LocalStorage already has the flag
      }
      _next();
    }
  }

  void _next() {
    final slides = _slides(context);
    if (_page < slides.length - 1) {
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
        final strings = AppStrings.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.onboardingUsagePermissionFallback),
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
        final strings = AppStrings.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.onboardingOverlayPermissionFallback),
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
    final strings = AppStrings.of(context);
    final slides = _slides(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
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
                      strings.onboardingSkip,
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
                itemCount: slides.length,
                itemBuilder: (_, i) => _SlidePage(slide: slides[i]),
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
                    children: List.generate(slides.length, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color:
                              active
                                  ? slides[_page].accent
                                  : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
                  // PIN setup buttons (custom UI for PIN slide)
                  if (slides[_page].isPinSlide) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _openPinSetup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: slides[_page].accent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          strings.onboardingCreatePin,
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
                          side: BorderSide(color: slides[_page].accent),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          strings.onboardingPinLater,
                          style: AppTypography.labelLarge.copyWith(
                            color: slides[_page].accent,
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
                          backgroundColor: slides[_page].accent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _page == slides.length - 1 ? strings.start : strings.next,
                          style: AppTypography.labelLarge,
                        ),
                      ),
                    ),
                  // On the last slide, show permission buttons.
                  if (_page == slides.length - 1) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _openUsageSettings,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.secondary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          strings.onboardingUsageStatsButton,
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.secondary,
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
                          side: const BorderSide(color: AppColors.secondary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          strings.onboardingOverlayButton,
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.secondary,
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
      setState(() => _errorMsg = AppStrings.of(context).minimum4Digits);
      return;
    }
    if (p1 != p2) {
      setState(() => _errorMsg = AppStrings.of(context).pinsDoNotMatch);
      return;
    }

    // Save PIN to AuthService
    try {
      await AuthService.instance.setPin(p1);
      if (mounted) {
        Navigator.pop(context, p1);
      }
    } catch (e) {
      setState(() => _errorMsg = AppStrings.of(context).pinSaveError);
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
            child: Text(AppStrings.of(context).onboardingCreatePin, style: AppTypography.headlineSmall),
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
              decoration: InputDecoration(
                hintText: AppStrings.of(context).newPinHint,
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
                hintText: AppStrings.of(context).confirmPin,
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
          child: Text(AppStrings.of(context).cancel),
        ),
        ElevatedButton(onPressed: _submit, child: Text(AppStrings.of(context).save)),
      ],
    );
  }
}
