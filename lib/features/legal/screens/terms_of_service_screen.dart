import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../widgets/legal_section.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final isEn = strings.isEnglish;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        elevation: 0,
        foregroundColor: context.colors.textPrimary,
        title: Text(
          strings.termsOfService,
          style: AppTypography.headlineMedium,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LegalSection(
              title: isEn ? 'Acceptance' : 'Aceptación',
              body:
                  isEn
                      ? 'By using Safocus, you agree to these Terms. If you do not agree, do not use the app.'
                      : 'Al usar Safocus, aceptás estos Términos. Si no estás de acuerdo, no uses la app.',
            ),
            LegalSection(
              title:
                  isEn ? 'Description of Service' : 'Descripción del servicio',
              body:
                  isEn
                      ? 'Safocus is a productivity app that helps you manage screen time by blocking distracting websites and apps. '
                          'All blocking features operate locally on your device.'
                      : 'Safocus es una app de productividad que te ayuda a gestionar el tiempo de pantalla bloqueando sitios web y apps distractoras. '
                          'Todas las funciones de bloqueo operan localmente en tu dispositivo.',
            ),
            LegalSection(
              title:
                  isEn
                      ? 'User Responsibilities'
                      : 'Responsabilidades del usuario',
              body:
                  isEn
                      ? '• You are responsible for the limits and blocks you configure.\n'
                          '• Do not use Safocus to block emergency services or critical apps.\n'
                          '• The PIN protection is your responsibility — we cannot recover a lost PIN.\n'
                          '• Focus Duo features are for personal accountability only.'
                      : '• Sos responsable de los límites y bloqueos que configurás.\n'
                          '• No uses Safocus para bloquear servicios de emergencia o apps críticas.\n'
                          '• La protección con PIN es tu responsabilidad — no podemos recuperar un PIN perdido.\n'
                          '• Las funciones de Focus Duo son solo para responsabilidad personal.',
            ),
            LegalSection(
              title:
                  isEn ? 'Disclaimer of Warranties' : 'Exención de garantías',
              body:
                  isEn
                      ? 'Safocus is provided \'as is\' without warranty of any kind. '
                          'We do not guarantee that the app will block all content or that it cannot be bypassed. '
                          'The effectiveness of blocking depends on your device settings and Android version.'
                      : 'Safocus se proporciona "tal cual" sin garantía de ningún tipo. '
                          'No garantizamos que la app bloqueará todo el contenido ni que no puede ser eludida. '
                          'La efectividad del bloqueo depende de la configuración de tu dispositivo y la versión de Android.',
            ),
            LegalSection(
              title:
                  isEn
                      ? 'Limitation of Liability'
                      : 'Limitación de responsabilidad',
              body:
                  isEn
                      ? 'To the maximum extent permitted by law, the developer is not liable for any indirect, '
                          'incidental, or consequential damages arising from your use of Safocus.'
                      : 'En la máxima medida permitida por la ley, el desarrollador no es responsable de ningún daño indirecto, '
                          'incidental o consecuente derivado del uso de Safocus.',
            ),
            LegalSection(
              title: isEn ? 'Changes to Terms' : 'Cambios en los términos',
              body:
                  isEn
                      ? 'We may update these Terms occasionally. '
                          'Continued use of the app after changes constitutes acceptance of the new Terms.'
                      : 'Podemos actualizar estos Términos ocasionalmente. '
                          'El uso continuado de la app después de los cambios constituye la aceptación de los nuevos Términos.',
            ),
            LegalSection(
              title: isEn ? 'Contact' : 'Contacto',
              body:
                  isEn
                      ? 'For questions about these Terms, contact: sagxluis@gmail.com'
                      : 'Para preguntas sobre estos Términos, contactanos en: sagxluis@gmail.com',
            ),
            Text(strings.lastUpdated, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}
