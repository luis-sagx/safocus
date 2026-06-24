import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../widgets/legal_section.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
        title: Text(strings.privacyPolicy, style: AppTypography.headlineMedium),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LegalSection(
              title: isEn ? 'Data We Collect' : 'Datos que recopilamos',
              body:
                  isEn
                      ? 'Safocus stores all data exclusively on your device. We do not operate servers or collect personal information.\n\n'
                          '• App usage statistics (which apps you use and for how long) — stored locally to enforce limits you set.\n'
                          '• App limits and categories you configure.\n'
                          '• Blocked sites list.\n'
                          '• Focus streak and score data.\n'
                          '• A PIN hash stored in your device\'s secure enclave (never sent anywhere).\n'
                          '• Focus Duo data (your invite code and streak) — stored locally, no server involved.\n\n'
                          'We do NOT collect: your name, email, location, browsing history, or any personally identifiable information.'
                      : 'Safocus almacena todos los datos exclusivamente en tu dispositivo. No operamos servidores ni recopilamos información personal.\n\n'
                          '• Estadísticas de uso de apps (qué apps usás y por cuánto tiempo) — almacenadas localmente para aplicar los límites que configurás.\n'
                          '• Límites y categorías de apps que configurás.\n'
                          '• Lista de sitios bloqueados.\n'
                          '• Datos de racha y puntuación de enfoque.\n'
                          '• Un hash de PIN almacenado en el enclave seguro de tu dispositivo (nunca se envía a ningún lado).\n'
                          '• Datos de Focus Duo (tu código de invitación y racha) — almacenados localmente, sin servidor involucrado.\n\n'
                          'NO recopilamos: tu nombre, email, ubicación, historial de navegación ni ninguna información de identificación personal.',
            ),
            LegalSection(
              title: isEn ? 'VPN Usage' : 'Uso del VPN',
              body:
                  isEn
                      ? 'Safocus uses Android\'s VpnService API exclusively to block access to distracting websites you choose to block. '
                          'This VPN tunnel is local to your device.\n\n'
                          'We DO NOT:\n'
                          '• Monitor, log, or store your internet traffic.\n'
                          '• Collect data from the VPN tunnel.\n'
                          '• Send your traffic to external servers.\n'
                          '• Sell or share any data obtained through the VPN.\n\n'
                          'The VPN is used solely to filter outbound DNS requests for domains on your personal blocklist.'
                      : 'Safocus usa la API VpnService de Android exclusivamente para bloquear el acceso a sitios web distractores que elegís bloquear. '
                          'Este túnel VPN es local a tu dispositivo.\n\n'
                          'NO hacemos:\n'
                          '• Monitorear, registrar ni almacenar tu tráfico de internet.\n'
                          '• Recopilar datos del túnel VPN.\n'
                          '• Enviar tu tráfico a servidores externos.\n'
                          '• Vender ni compartir ningún dato obtenido a través del VPN.\n\n'
                          'El VPN se usa únicamente para filtrar solicitudes DNS salientes de los dominios en tu lista personal de bloqueo.',
            ),
            LegalSection(
              title: isEn ? 'Permissions' : 'Permisos',
              body:
                  isEn
                      ? '• Usage Statistics (PACKAGE_USAGE_STATS): Required to detect how long you use each app so limits can be enforced.\n'
                          '• Overlay Windows (SYSTEM_ALERT_WINDOW): Required to show the blocking screen when an app limit is reached.\n'
                          '• VPN (BIND_VPN_SERVICE): Required for local site blocking. See VPN Usage section above.\n'
                          '• Notifications: Required to send you motivational reminders and limit alerts.\n'
                          '• Biometrics / Device credentials: Optional, used as a fallback for PIN authentication — no biometric data is stored.'
                      : '• Estadísticas de uso (PACKAGE_USAGE_STATS): Necesario para detectar cuánto tiempo usás cada app y aplicar los límites.\n'
                          '• Superponer ventanas (SYSTEM_ALERT_WINDOW): Necesario para mostrar la pantalla de bloqueo cuando se alcanza el límite de una app.\n'
                          '• VPN (BIND_VPN_SERVICE): Necesario para el bloqueo local de sitios. Ver sección Uso del VPN arriba.\n'
                          '• Notificaciones: Necesario para enviarte recordatorios motivacionales y alertas de límite.\n'
                          '• Biometría / Credenciales del dispositivo: Opcional, usado como alternativa para autenticación PIN — no se almacena ningún dato biométrico.',
            ),
            LegalSection(
              title: isEn ? 'Data Sharing' : 'Compartir datos',
              body:
                  isEn
                      ? 'We do not share any data with third parties. Safocus has no analytics SDK, no advertising SDK, and no backend server. '
                          'All your data stays on your device.'
                      : 'No compartimos ningún dato con terceros. Safocus no tiene SDK de analítica, SDK de publicidad ni servidor backend. '
                          'Todos tus datos permanecen en tu dispositivo.',
            ),
            LegalSection(
              title: isEn ? 'Data Deletion' : 'Eliminación de datos',
              body:
                  isEn
                      ? 'You can delete all your data at any time via Settings → Reset all data. '
                          'Uninstalling the app also removes all stored data.'
                      : 'Podés eliminar todos tus datos en cualquier momento desde Ajustes → Restablecer todos los datos. '
                          'Desinstalar la app también elimina todos los datos almacenados.',
            ),
            LegalSection(
              title: isEn ? 'Children\'s Privacy' : 'Privacidad de menores',
              body:
                  isEn
                      ? 'Safocus does not knowingly collect personal information from any user, including children under 13. '
                          'Since no personal data is collected or transmitted, the app is safe for all ages. '
                          'Parents are encouraged to configure limits and PIN protection for younger users.'
                      : 'Safocus no recopila intencionalmente información personal de ningún usuario, incluidos menores de 13 años. '
                          'Dado que no se recopila ni transmite datos personales, la app es segura para todas las edades. '
                          'Se recomienda a los padres configurar límites y protección con PIN para usuarios más jóvenes.',
            ),
            LegalSection(
              title:
                  isEn ? 'Changes to This Policy' : 'Cambios en esta política',
              body:
                  isEn
                      ? 'We may update this Privacy Policy occasionally. '
                          'The current version is always available within the app under Settings → Privacy Policy.'
                      : 'Podemos actualizar esta Política de Privacidad ocasionalmente. '
                          'La versión actual siempre está disponible dentro de la app en Ajustes → Política de privacidad.',
            ),
            LegalSection(
              title: isEn ? 'Contact' : 'Contacto',
              body:
                  isEn
                      ? 'Questions about this policy? Contact us at: sagxluis@gmail.com'
                      : '¿Preguntas sobre esta política? Contactanos en: sagxluis@gmail.com',
            ),
            Text(strings.lastUpdated, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}
