import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safocus/core/icons/phosphor_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../../../navigation/app_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  final _controller = PageController();
  int _page = 0;
  int _scrollHoursPerDay = 3;
  String? _selectedIdentity;

  bool _usageGranted = false;
  bool _overlayGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from the system settings screen → re-check so the buttons
    // flip to "granted" immediately, without re-entering onboarding.
    if (state == AppLifecycleState.resumed) _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    try {
      const channel = MethodChannel(AppConstants.channelBlockControl);
      final usage =
          await channel.invokeMethod<bool>('hasUsagePermission') ?? false;
      final overlay =
          await channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
      if (mounted) {
        setState(() {
          _usageGranted = usage;
          _overlayGranted = overlay;
        });
      }
    } catch (_) {
      // Non-Android / channel unavailable — leave as not granted.
    }
  }

  List<_Slide> _slides(BuildContext context) {
    final strings = AppStrings.of(context);
    return [
      _Slide(
        icon: PhosphorIconsFill.clockCountdown,
        title: strings.onboardingSlide1Title,
        body: strings.onboardingSlide1Body,
        accent: AppColors.error,
        isScrollInputSlide: true,
      ),
      _Slide(
        icon: PhosphorIconsFill.lightning,
        title: strings.onboardingSlide2Title,
        body: strings.onboardingSlide2Body,
        accent: AppColors.warning,
        isIdentityChoiceSlide: true,
      ),
      _Slide(
        icon: PhosphorIconsFill.trophy,
        title: strings.onboardingSlide3Title,
        body: strings.onboardingSlide3Body,
        accent: AppColors.secondary,
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

    if (result != null && mounted && _page == slides.length - 2) {
      try {
        final container = ProviderScope.containerOf(context);
        await container
            .read(
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
    // Persist cost-mirror inputs so the web-block overlay can confront the user
    // with their own chosen identity and scroll cost.
    if (_selectedIdentity != null) {
      await prefs.setString(AppConstants.keyIdentity, _selectedIdentity!);
    }
    await prefs.setInt(
      AppConstants.keyScrollHoursPerDay,
      _scrollHoursPerDay,
    );
    // Mirror into the native prefs the BlockOverlayActivity reads.
    try {
      await const MethodChannel(
        AppConstants.channelBlockControl,
      ).invokeMethod('syncCostMirrorData', {
        'identity': _selectedIdentity,
        'scrollHours': _scrollHoursPerDay,
      });
    } catch (_) {
      // Non-Android / channel unavailable — overlay degrades gracefully.
    }
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
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final slides = _slides(context);
    return Scaffold(
      backgroundColor: context.colors.background,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
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
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: slides.length,
                itemBuilder: (_, i) => _SlidePage(
                  slide: slides[i],
                  scrollHours: _scrollHoursPerDay,
                  selectedIdentity: _selectedIdentity,
                  onScrollIncrement: () {
                    setState(() {
                      _scrollHoursPerDay = (_scrollHoursPerDay + 1).clamp(1, 8);
                    });
                  },
                  onScrollDecrement: () {
                    setState(() {
                      _scrollHoursPerDay = (_scrollHoursPerDay - 1).clamp(1, 8);
                    });
                  },
                  onIdentitySelect: (identity) {
                    setState(() => _selectedIdentity = identity);
                  },
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
              child: Column(
                children: [
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
                                  : context.colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
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
                          _page == slides.length - 1
                              ? strings.onboardingCta
                              : strings.next,
                          style: AppTypography.labelLarge,
                        ),
                      ),
                    ),
                  if (_page == slides.length - 1) ...[
                    const SizedBox(height: 12),
                    _PermissionButton(
                      label: strings.onboardingUsageStatsButton,
                      granted: _usageGranted,
                      onTap: _openUsageSettings,
                    ),
                    const SizedBox(height: 8),
                    _PermissionButton(
                      label: strings.onboardingOverlayButton,
                      granted: _overlayGranted,
                      onTap: _openOverlaySettings,
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
  final bool isScrollInputSlide;
  final bool isIdentityChoiceSlide;

  const _Slide({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
    this.isPinSlide = false,
    this.isScrollInputSlide = false,
    this.isIdentityChoiceSlide = false,
  });
}

class _SlidePage extends StatelessWidget {
  const _SlidePage({
    required this.slide,
    required this.scrollHours,
    required this.selectedIdentity,
    this.onScrollIncrement,
    this.onScrollDecrement,
    this.onIdentitySelect,
  });

  final _Slide slide;
  final int scrollHours;
  final String? selectedIdentity;
  final VoidCallback? onScrollIncrement;
  final VoidCallback? onScrollDecrement;
  final void Function(String)? onIdentitySelect;

  String _costMirrorBody(BuildContext context) {
    final strings = AppStrings.of(context);
    const weeksPerYear = 52;
    final hoursPerYear = scrollHours * 7 * weeksPerYear;
    final books = (hoursPerYear / 8).round();
    final episodes = (hoursPerYear / 0.75).round();
    final workouts = (hoursPerYear / 1.0).round();
    if (strings.isEnglish) {
      return "That's ${hoursPerYear}h/year scrolling → $books books / $episodes episodes / $workouts workouts";
    } else {
      return "Son ${hoursPerYear}h/año scrolleando → $books libros / $episodes episodios / $workouts entrenamientos";
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    final String bodyText = _resolveBody(context, strings);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
            bodyText,
            style: AppTypography.bodyLarge.copyWith(
              color: context.colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (slide.isScrollInputSlide) ...[
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(PhosphorIconsRegular.minus, color: slide.accent),
                  onPressed: onScrollDecrement,
                ),
                const SizedBox(width: 16),
                Text(
                  '$scrollHours',
                  style: AppTypography.displayLarge.copyWith(color: slide.accent),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(PhosphorIconsRegular.plus, color: slide.accent),
                  onPressed: onScrollIncrement,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              strings.isEnglish ? 'hours / day' : 'horas / día',
              style: AppTypography.bodyMedium,
            ),
          ],
          if (slide.isIdentityChoiceSlide) ...[
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _IdentityChip(
                  label: strings.isEnglish ? '📚 Study' : '📚 Estudiar',
                  selected: selectedIdentity == 'study',
                  accent: slide.accent,
                  onTap: () => onIdentitySelect?.call('study'),
                ),
                _IdentityChip(
                  label: '💪 Gym',
                  selected: selectedIdentity == 'gym',
                  accent: slide.accent,
                  onTap: () => onIdentitySelect?.call('gym'),
                ),
                _IdentityChip(
                  label: strings.isEnglish ? '🎨 Create' : '🎨 Crear',
                  selected: selectedIdentity == 'create',
                  accent: slide.accent,
                  onTap: () => onIdentitySelect?.call('create'),
                ),
                _IdentityChip(
                  label: strings.isEnglish ? '😴 Sleep well' : '😴 Dormir bien',
                  selected: selectedIdentity == 'sleep',
                  accent: slide.accent,
                  onTap: () => onIdentitySelect?.call('sleep'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _resolveBody(BuildContext context, AppStrings strings) {
    if (slide.icon == PhosphorIconsFill.trophy &&
        !slide.isScrollInputSlide &&
        !slide.isIdentityChoiceSlide &&
        !slide.isPinSlide) {
      return _costMirrorBody(context);
    }
    return slide.body;
  }
}

class _IdentityChip extends StatelessWidget {
  const _IdentityChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.15) : context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : context.colors.surfaceVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelLarge.copyWith(
            color: selected ? accent : context.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Onboarding permission action. Pending → primary outline that opens the
/// system settings screen. Granted → static green confirmation (no longer
/// tappable) so the wizard visibly guides the user from "activar" to "listo".
class _PermissionButton extends StatelessWidget {
  const _PermissionButton({
    required this.label,
    required this.granted,
    required this.onTap,
  });

  final String label;
  final bool granted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    if (granted) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.success),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              PhosphorIconsFill.checkCircle,
              color: AppColors.success,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '$label · ${strings.active}',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.success,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelLarge.copyWith(color: AppColors.primary),
        ),
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
      backgroundColor: context.colors.surface,
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
