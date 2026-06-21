import 'package:flutter/widgets.dart';

class AppStrings {
  const AppStrings._(this.languageCode);

  final String languageCode;

  bool get isEnglish => languageCode.toLowerCase().startsWith('en');

  static AppStrings of(BuildContext context) {
    return AppStrings._(Localizations.localeOf(context).languageCode);
  }

  static AppStrings forLanguage(String languageCode) {
    return AppStrings._(languageCode);
  }

  String get appName => 'SaFocus';

  String get today => isEnglish ? 'Today' : 'Hoy';
  String get yesterday => isEnglish ? 'Yesterday' : 'Ayer';
  String get settings => isEnglish ? 'Settings' : 'Ajustes';
  String get appearance => isEnglish ? 'Appearance' : 'Apariencia';
  String get security => isEnglish ? 'Security' : 'Seguridad';
  String get data => isEnglish ? 'Data' : 'Datos';
  String get theme => isEnglish ? 'Theme' : 'Tema';
  String get language => isEnglish ? 'Language' : 'Idioma';
  String get darkTheme => isEnglish ? 'Dark' : 'Oscuro';
  String get spanish => isEnglish ? 'Spanish' : 'Español';
  String get english => isEnglish ? 'English' : 'Inglés';
  String get pinProtection =>
      isEnglish ? 'Protection PIN' : 'PIN de protección';
  String get pinProtectionSubtitle =>
      isEnglish
          ? 'Requires a PIN to disable blocks'
          : 'Requiere PIN para desactivar bloqueos';
  String get resetAllData =>
      isEnglish ? 'Reset all data' : 'Restablecer todos los datos';
  String get resetAllDataSubtitle =>
      isEnglish
          ? 'Deletes settings, limits, and statistics'
          : 'Borra configuración, límites y estadísticas';
  String get resetDataTitle => isEnglish ? 'Reset data' : 'Restablecer datos';
  String get resetDataBody =>
      isEnglish
          ? 'This will delete all limits, blocks, statistics, and settings. It cannot be undone.'
          : 'Esta acción eliminará todos los límites, bloqueos, estadísticas y configuración. No se puede deshacer.';
  String get cancel => isEnglish ? 'Cancel' : 'Cancelar';
  String get deleteAll => isEnglish ? 'Delete all' : 'Eliminar todo';
  String get deletedSuccessfully =>
      isEnglish
          ? 'Data deleted successfully.'
          : 'Datos eliminados correctamente.';
  String get pinConfiguredSuccessfully =>
      isEnglish
          ? 'PIN configured successfully.'
          : 'PIN configurado correctamente.';
  String get minimum4Digits =>
      isEnglish ? 'Minimum 4 digits' : 'Mínimo 4 dígitos';
  String get pinsDoNotMatch =>
      isEnglish ? 'PINs do not match' : 'Los PINs no coinciden';
  String get createPin => isEnglish ? 'Create PIN' : 'Crear PIN';
  String get newPinHint =>
      isEnglish ? 'New PIN (4–6 digits)' : 'Nuevo PIN (4–6 dígitos)';
  String get confirmPin => isEnglish ? 'Confirm PIN' : 'Confirmar PIN';
  String get save => isEnglish ? 'Save' : 'Guardar';
  String get create => isEnglish ? 'Create' : 'Crear';
  String get setupLater => isEnglish ? 'Do it later' : 'Hacerlo después';
  String get skip => isEnglish ? 'Skip' : 'Omitir';
  String get next => isEnglish ? 'Next' : 'Siguiente';
  String get start => isEnglish ? 'Start' : 'Empezar';
  String get onboardingCta => isEnglish ? 'Lock in' : 'Quiero locked in';

  String get permissionsBlocking =>
      isEnglish ? 'Blocking permissions' : 'Permisos de bloqueo';
  String get usageStats =>
      isEnglish ? 'Usage statistics' : 'Estadísticas de uso';
  String get usageStatsSubtitle =>
      isEnglish
          ? 'Required to detect time spent in each app'
          : 'Necesario para detectar el tiempo en cada app';
  String get overlayWindows =>
      isEnglish ? 'Overlay windows' : 'Superponer ventanas';
  String get overlayWindowsSubtitle =>
      isEnglish
          ? 'Required to show the blocking screen'
          : 'Necesario para mostrar la pantalla de bloqueo';
  String get activate => isEnglish ? 'Activate' : 'Activar';

  String get home => isEnglish ? 'Home' : 'Inicio';
  String get blocking => isEnglish ? 'Lock In' : 'Escudo';
  String get statistics => isEnglish ? 'Stats' : 'Métricas';
  String get limits => isEnglish ? 'Limits' : 'Límites';

  String get focusScore => isEnglish ? 'Lock-In Score' : 'Lock-In Score';
  String get basedOnActiveBlocks =>
      isEnglish
          ? 'Based on your focus and habits today'
          : 'Basado en tu enfoque y hábitos de hoy';
  String get webBlocking => isEnglish ? 'Lock In Shield' : 'Escudo Lock In';
  String get active => isEnglish ? 'Active' : 'Activo';
  String get inactive => isEnglish ? 'Inactive' : 'Inactivo';
  String get blockedToday => isEnglish ? 'Today' : 'Hoy';
  String get appUsageLimits => isEnglish ? 'Your setup' : 'Tu setup';
  String get seeAll => isEnglish ? 'See all' : 'Ver todos';
  String get noLimitsConfigured =>
      isEnglish ? 'No setup yet' : 'Sin setup aún';
  String get addAppsToLimitSubtitle =>
      isEnglish
          ? 'Add daily limits to your distracting apps'
          : 'Agrega límites diarios a tus apps distractoras';
  String get addUsageLimitsSubtitle =>
      isEnglish
          ? 'Add limits to the apps that pull you away'
          : 'Agregá límites a las apps que te distraen';
  String get addLimit => isEnglish ? 'Add limit' : 'Agregar límite';
  String get addApplication => isEnglish ? 'Add app' : 'Agregar aplicación';
  String get blockingNotActiveTitle =>
      isEnglish
          ? 'App blocking is not active'
          : 'El bloqueo de apps no está activo';
  String get missingPermissionsBanner =>
      isEnglish
          ? 'Missing permissions so SaFocus can block apps when the daily limit is exceeded.'
          : 'Faltan permisos para que SaFocus bloquee apps al superar el límite diario.';
  String get appLimitScreenTitle =>
      isEnglish ? 'Your setup' : 'Tu setup';
  String get appLimitScreenSubtitle =>
      isEnglish
          ? 'The stuff that tempts you. You set the rules.'
          : 'Lo que te tienta. Vos ponés las reglas.';
  String get delete => isEnglish ? 'Delete' : 'Eliminar';
  String get used => isEnglish ? 'used' : 'usado';
  String get limitPrefix => isEnglish ? 'Limit:' : 'Límite:';
  String get emergencyExtensionAlreadyUsed =>
      isEnglish
          ? "You already used today's emergency extension."
          : 'Ya utilizaste la extensión de emergencia hoy.';
  String emergencyExtensionLabel(int minutes) =>
      isEnglish
          ? '+${minutes}min — use it wisely'
          : '+${minutes}min — usalo bien';
  String get limitExceeded => isEnglish ? 'Comeback time.' : 'Va de nuevo.';
  String remainingMinutes(String formatted) =>
      isEnglish ? '$formatted left' : '$formatted restantes';

  String get selectApp => isEnglish ? 'Select app' : 'Seleccionar app';
  String get chooseAppToLimit =>
      isEnglish
          ? 'Choose the app you want to limit'
          : 'Elige la app a la que quieres poner límite';
  String get searchApp => isEnglish ? 'Search app...' : 'Buscar app...';
  String get noResults => isEnglish ? 'No results' : 'Sin resultados';
  String get timeLimit => isEnglish ? 'Time limit' : 'Límite de tiempo';
  String get maximumDailyTime =>
      isEnglish ? 'Maximum daily time' : 'Tiempo máximo diario';
  String get saveLimit => isEnglish ? 'Save limit' : 'Guardar límite';
  String failedToLoadApps(String error) =>
      isEnglish
          ? 'Could not load apps: $error'
          : 'No se pudieron cargar las apps: $error';

  String get blockWebDescription =>
      isEnglish
          ? 'Activate the VPN shield to lock in from distracting sites'
          : 'Activá el escudo VPN para locked in de los sitios que te distraen';
  String get vpnCouldNotActivate =>
      isEnglish
          ? 'Could not activate VPN. Check permissions.'
          : 'No se pudo activar el VPN. Verifica los permisos.';
  String get mySites => isEnglish ? 'My sites' : 'Mis sitios';
  String get predefined => isEnglish ? 'Predefined' : 'Predefinidos';
  String get shieldActive => isEnglish ? 'Locked In' : 'Locked In';
  String get shieldInactive =>
      isEnglish ? 'Lock In off' : 'Lock In apagado';
  String customSitesCount(int count) =>
      isEnglish ? '$count sites locked out' : '$count sitios bloqueados';
  String get tapToEnableVpn =>
      isEnglish
          ? 'Tap to lock in'
          : 'Toca para locked in';
  String get noCustomSites =>
      isEnglish ? 'No custom sites' : 'Sin sitios personalizados';
  String get addUrlsToBlock =>
      isEnglish ? 'Add URLs to block' : 'Agrega URLs que quieres bloquear';
  String get addSite => isEnglish ? 'Add site' : 'Agregar sitio';
  String get enterDomainWithoutHttps =>
      isEnglish
          ? 'Enter the domain without "https://" (e.g. facebook.com)'
          : 'Introduce el dominio sin "https://" (ej. facebook.com)';
  String get domainPlaceholder => isEnglish ? 'domain.com' : 'dominio.com';
  String get noBlockedAttemptsYet =>
      isEnglish
          ? 'No blocked attempts recorded yet.'
          : 'Todavía no hay intentos bloqueados registrados.';
  String get customSiteBlocking =>
      isEnglish ? 'Custom site blocking' : 'Bloqueo de sitios personalizados';
  String get defaultSiteBlocking =>
      isEnglish ? 'Default site blocking' : 'Bloqueo de sitios predefinidos';
  // ── App uniqueness validation ─────────────────────────────────────────────
  String appAlreadyInCategory(String appName, String categoryName) =>
      isEnglish
          ? '$appName is already in $categoryName'
          : '$appName ya está en $categoryName';
  String get moveAppToThisCategory =>
      isEnglish
          ? 'Do you want to move it to this category?'
          : '¿Querés moverla a esta categoría?';
  String get moveApp => isEnglish ? 'Move' : 'Mover';
  String get keepInCurrent =>
      isEnglish ? 'Keep there' : 'Dejar ahí';

  String categoryLabel(String key) {
    switch (key) {
      case 'Redes sociales':
        return isEnglish ? 'Social networks' : 'Redes sociales';
      case 'Adulto':
        return isEnglish ? 'Adult' : 'Adulto';
      case 'Video / streaming':
        return isEnglish ? 'Video / streaming' : 'Video / streaming';
      case 'Apuestas / juegos':
        return isEnglish ? 'Betting / games' : 'Apuestas / juegos';
      case 'Noticias / clickbait':
        return isEnglish ? 'News / clickbait' : 'Noticias / clickbait';
      default:
        return key;
    }
  }

  String get motivation => isEnglish ? 'Motivation' : 'Motivación';
  String get phrasesReminder =>
      isEnglish
          ? 'Phrases that remind you why you started'
          : 'Frases que te recuerdan por qué empezaste';
  String get activeReminders =>
      isEnglish ? 'Active reminders' : 'Recordatorios activos';
  String get receiveMotivationalPhrases =>
      isEnglish
          ? 'Receive motivational phrases'
          : 'Recibe frases motivacionales';
  String get frequency => isEnglish ? 'Frequency' : 'Frecuencia';
  String everyHours(int hours) =>
      isEnglish ? 'Every ${hours}h' : 'Cada ${hours}h';
  String phrasesCount(int count) =>
      isEnglish ? 'Phrases ($count)' : 'Frases ($count)';
  String get addPhrase => isEnglish ? 'Add' : 'Agregar';
  String get newPhrase => isEnglish ? 'New phrase' : 'Nueva frase';
  String get writeInspiringPhrase =>
      isEnglish
          ? 'Write a phrase that inspires you...'
          : 'Escribe una frase que te inspire...';
  String get languageLabel => isEnglish ? 'Language:' : 'Idioma:';
  String get savePhrase => isEnglish ? 'Save phrase' : 'Guardar frase';

  String get statisticsTitle => isEnglish ? 'Your week locked in' : 'Tu semana locked in';
  String get last7Days => isEnglish ? 'Last 7 days' : 'Últimos 7 días';
  String get todayScore => isEnglish ? 'Lock-In Score' : 'Lock-In Score';
  String get streak => isEnglish ? 'Streak 🔥' : 'Racha 🔥';
  String dayWord(int days) =>
      isEnglish ? (days == 1 ? 'day' : 'days') : (days == 1 ? 'día' : 'días');
  String get dailyUsageMinutes =>
      isEnglish ? 'Daily usage minutes' : 'Minutos de uso diario';
  String get noUsageHistory =>
      isEnglish
          ? 'There is not enough history yet to show the chart. The app needs a few days of usage.'
          : 'Aún no hay historial suficiente para mostrar la gráfica. La app necesita registrar algunos días de uso.';
  String get enableUsageStatsPermission =>
      isEnglish
          ? 'Enable the "Usage statistics" permission to record daily minutes and fill this chart.'
          : 'Activa el permiso de "Uso de apps" para registrar minutos diarios y llenar esta gráfica.';
  String get goToSettings => isEnglish ? 'Go to settings' : 'Ir a ajustes';
  String get usageByApp => isEnglish ? 'Usage by app' : 'Uso por app';
  String get blockedAttempts =>
      isEnglish ? 'Blocked attempts' : 'Intentos bloqueados';
  String get detail => isEnglish ? 'Details' : 'Detalle';
  String get clear => isEnglish ? 'Clear' : 'Limpiar';
  String get blockedHistoryDeleted =>
      isEnglish
          ? 'Blocked history deleted.'
          : 'Historial de bloqueos eliminado.';
  String get week => isEnglish ? 'Week' : 'Semana';
  String get unique => isEnglish ? 'Unique' : 'Únicos';
  String get activeSites => isEnglish ? 'Active sites' : 'Sitios activos';
  String get mostBlockedDomains =>
      isEnglish ? 'Most blocked domains' : 'Dominios más bloqueados';
  String get moreAttempts => isEnglish ? 'times' : 'veces';
  String origin(String sample) =>
      isEnglish ? 'Source: $sample' : 'Origen: $sample';
  String get blockedDetailsTitle =>
      isEnglish ? 'Blocked attempts details' : 'Detalle de bloqueos';
  String get blockedDetailsSubtitle =>
      isEnglish
          ? 'This screen separates blocked attempts from configured sites.'
          : 'Esta pantalla separa los intentos bloqueados de los sitios configurados.';
  String get noBlockedAttemptsRecorded =>
      isEnglish
          ? 'No blocked attempts have been recorded yet.'
          : 'Todavía no hay intentos bloqueados registrados.';
  String get noUsageData =>
      isEnglish
          ? 'No usage data recorded yet.'
          : 'Sin datos de uso registrados aún.';

  String get authTitle => isEnglish ? 'Enter your PIN' : 'Ingresa tu PIN';
  String get authSubtitle =>
      isEnglish ? 'Protect your settings' : 'Protege tus configuraciones';
  String get confirmPinButton => isEnglish ? 'Confirm' : 'Confirmar';
  String get useBiometrics => isEnglish ? 'Use biometrics' : 'Usar biometría';
  String incorrectPin(int remaining) =>
      isEnglish
          ? 'Incorrect PIN. $remaining attempt${remaining == 1 ? '' : 's'} remaining.'
          : 'PIN incorrecto. $remaining intento${remaining == 1 ? '' : 's'} restante${remaining == 1 ? '' : 's'}.';
  String get tooManyAttempts =>
      isEnglish
          ? 'Too many attempts. Wait 1 minute.'
          : 'Demasiados intentos. Espera 1 minuto.';
  String lockedOutIn(int seconds) =>
      isEnglish
          ? 'Locked out. Try again in ${seconds}s.'
          : 'Bloqueado. Intenta de nuevo en ${seconds}s.';

  String get onboardingSkip => isEnglish ? 'Skip' : 'Omitir';
  String get onboardingPinLater =>
      isEnglish ? 'Do it later' : 'Hacerlo después';
  String get onboardingUsageStatsButton =>
      isEnglish ? 'Enable: Usage statistics' : 'Activar: Estadísticas de uso';
  String get onboardingOverlayButton =>
      isEnglish ? 'Enable: Overlay windows' : 'Activar: Superponer ventanas';
  String get onboardingCreatePin => isEnglish ? 'Create PIN' : 'Crear PIN';
  String get onboardingSlide1Title =>
      isEnglish ? 'You scroll more than you think' : 'Scrolleás más de lo que creés';
  String get onboardingSlide1Body =>
      isEnglish
          ? 'The average person spends 3h/day on distracting apps. That\'s 45 days a year — gone. Safocus shows you the real cost.'
          : 'La persona promedio gasta 3h/día en apps que la distraen. Eso son 45 días al año — idos. Safocus te muestra el costo real.';
  String get onboardingSlide2Title =>
      isEnglish ? 'Who do you want to be?' : '¿Quién querés ser?';
  String get onboardingSlide2Body =>
      isEnglish
          ? 'Someone who studies with full focus. Works out consistently. Creates without distraction. Sleeps without doomscrolling. Safocus gives you the proof you\'re getting there.'
          : 'Alguien que estudia con foco total. Entrena seguido. Crea sin distracciones. Duerme sin doomscrolling. Safocus te da la prueba de que lo estás logrando.';
  String get onboardingSlide3Title =>
      isEnglish ? 'Your Lock-In Score' : 'Tu Lock-In Score';
  String get onboardingSlide3Body =>
      isEnglish
          ? 'Built day by day. VPN shield on, limits respected, streak growing — every action raises your score. Share it when you\'re proud.'
          : 'Se construye día a día. Escudo VPN activo, límites respetados, racha creciendo — cada acción sube tu score. Compartilo cuando estés orgulloso.';
  String get onboardingSlide4Title =>
      isEnglish ? 'Lock your setup' : 'Bloquea tu setup';
  String get onboardingSlide4Body =>
      isEnglish
          ? 'Set a PIN so you can\'t undo your progress in a weak moment. Only destructive actions will ask for it.'
          : 'Poné un PIN para que no puedas deshacer tu progreso en un momento débil. Solo acciones destructivas lo pedirán.';
  String get onboardingSlide5Title =>
      isEnglish ? 'Activate the shield' : 'Activá el escudo';
  String get onboardingSlide5Body =>
      isEnglish
          ? 'To block apps when they reach their limit, Safocus needs Usage statistics and Overlay permissions. Takes 30 seconds.'
          : 'Para bloquear apps cuando alcanzan el límite, Safocus necesita permiso de Uso de apps y Superponer ventanas. Son 30 segundos.';
  String get onboardingUsagePermissionFallback =>
      isEnglish
          ? 'Go to Settings → Privacy → Usage statistics and enable SaFocus.'
          : 'Ve a Ajustes → Privacidad → Estadísticas de uso y activa SaFocus.';
  String get onboardingOverlayPermissionFallback =>
      isEnglish
          ? 'Go to Settings → Special permissions → Overlay windows and enable SaFocus.'
          : 'Ve a Ajustes → Permisos especiales → Superponer ventanas y activa SaFocus.';

  String get settingsLanguageHint =>
      isEnglish ? 'Choose language' : 'Elige idioma';
  String get themeDarkLabel => darkTheme;

  String get pinSaveError =>
      isEnglish ? 'Error saving PIN' : 'Error al guardar el PIN';

  String get focusScoreExcellent =>
      isEnglish ? 'Locked in' : 'Locked in';
  String get focusScoreVeryGood =>
      isEnglish ? 'On track' : 'En racha';
  String get focusScoreRegular =>
      isEnglish ? 'Building momentum' : 'Tomando impulso';
  String get focusScoreImproving =>
      isEnglish ? 'Comeback mode' : 'Modo comeback';
  String get focusScoreLow => isEnglish ? 'Time to lock in' : 'Hora de locked in';

  String focusScoreLabel(int score) {
    if (score >= 90) return focusScoreExcellent;
    if (score >= 70) return focusScoreVeryGood;
    if (score >= 50) return focusScoreRegular;
    if (score >= 30) return focusScoreImproving;
    return focusScoreLow;
  }

  String get activeShort => isEnglish ? 'active' : 'activos';
  String get activeSitesShort => isEnglish ? 'Active' : 'Activos';
  String attemptsCount(int count) =>
      isEnglish ? '$count times' : '$count veces';
  String mostAttemptedLabel(String domain, int count) => isEnglish
      ? 'Most attempted: $domain ($count times)'
      : 'Más intentado: $domain ($count veces)';

  String presetLabel(int minutes) {
    switch (minutes) {
      case 15:
        return isEnglish ? '15 min' : '15 min';
      case 30:
        return isEnglish ? '30 min' : '30 min';
      case 60:
        return isEnglish ? '1 hour' : '1 hora';
      case 120:
        return isEnglish ? '2 hours' : '2 horas';
      default:
        return isEnglish ? '$minutes min' : '$minutes min';
    }
  }

  // ── Categories ───────────────────────────────────────────────────────
  String get categories => isEnglish ? 'Categories' : 'Categorías';
  String get newCategory => isEnglish ? 'New category' : 'Nueva categoría';
  String get categoryName => isEnglish ? 'Category name' : 'Nombre de categoría';
  String get categoryLimit => isEnglish ? 'Category limit' : 'Límite de categoría';
  String get selectCategory => isEnglish ? 'Select category' : 'Seleccionar categoría';
  String get noCategory => isEnglish ? 'No category' : 'Sin categoría';
  String get uncategorized => isEnglish ? 'Uncategorized' : 'Sin categoría';
  String get chooseCategory => isEnglish ? 'Choose category' : 'Elegir categoría';
  String get deleteCategory => isEnglish ? 'Delete category' : 'Eliminar categoría';
  String get appsInCategory => isEnglish ? 'Apps in category' : 'Apps en categoría';
  String get hoursLabel => isEnglish ? 'hours' : 'horas';
  String get minutesLabel => isEnglish ? 'minutes' : 'minutos';
  String get categoryNameHint =>
      isEnglish ? 'e.g. Social networks' : 'ej. Redes sociales';
  String get addCategory =>
      isEnglish ? 'Add category' : 'Agregar categoría';
  String get editCategory =>
      isEnglish ? 'Edit category' : 'Editar categoría';
  String get manageCategories =>
      isEnglish ? 'Manage categories' : 'Gestionar categorías';
  String get deleteCategoryConfirm =>
      isEnglish
          ? 'Deleting this category will move its apps to Uncategorized.'
          : 'Eliminar esta categoría moverá sus apps a Sin categoría.';
  String get chooseEmoji =>
      isEnglish ? 'Choose emoji' : 'Elegir emoji';
  String get categoryColor =>
      isEnglish ? 'Color' : 'Color';
  String categoryUsage(String used, String total) =>
      isEnglish ? '$used / $total' : '$used / $total';
  String get categoryLimitExceeded =>
      isEnglish ? 'Category limit exceeded' : 'Límite de categoría superado';
  String get newCategoryTitle =>
      isEnglish ? 'New category' : 'Nueva categoría';
  String get categoryCreated =>
      isEnglish ? 'Category created' : 'Categoría creada';
  String get categoryUpdated =>
      isEnglish ? 'Category updated' : 'Categoría actualizada';
  String get categoryDeleted =>
      isEnglish ? 'Category deleted' : 'Categoría eliminada';
  String get selectAppForCategory =>
      isEnglish
          ? 'Select apps for this category'
          : 'Selecciona apps para esta categoría';
  String get addAppToCategory =>
      isEnglish ? 'Add app' : 'Agregar app';
  String get refresh =>
      isEnglish ? 'Refresh' : 'Refrescar';
  String get loadingApps =>
      isEnglish ? 'Loading apps…' : 'Cargando aplicaciones…';
  String get loadingAppsSubtitle =>
      isEnglish
          ? 'Extracting icons, this may take a moment'
          : 'Extrayendo íconos, puede tardar un momento';
  String get noCategoriesYet =>
      isEnglish ? 'No categories yet' : 'Todavía no hay categorías';
  String get addCategorySubtitle =>
      isEnglish
          ? 'Create categories to group your apps and set shared limits'
          : 'Crea categorías para agrupar tus apps y definir límites compartidos';

  String countLabel(int value, {String unit = ''}) =>
      unit.isEmpty ? '$value' : '$value $unit';

  String get limitReachedTitle => isEnglish ? 'Comeback time. 💪' : 'Va de nuevo. 💪';
  String limitReachedBody(String appName) =>
      isEnglish
          ? 'You hit your limit on $appName. Your future self will thank you.'
          : 'Llegaste al límite de $appName. Tu yo del futuro te lo va a agradecer.';
  String get limitWarningTitle => isEnglish ? 'Heads up ⏰' : 'Ojo ⏰';
  String limitWarningBody(String appName, int minutes) =>
      isEnglish
          ? 'Eh… $minutes min left on $appName. Sure about this?'
          : 'Eh… $minutes min restantes en $appName. ¿Seguro/a?';
  String get weekSummaryTitle => isEnglish ? 'Your week locked in 🔥' : 'Tu semana locked in 🔥';

  // ── Focus Duo ──────────────────────────────────────────────────────────────
  String get focusDuo => isEnglish ? 'Focus Duo' : 'Focus Duo';
  String get focusDuoSubtitle =>
      isEnglish
          ? 'Lock in together. Neither of you quits.'
          : 'Locked in juntos. Ninguno se rinde.';
  String get myInviteCode => isEnglish ? 'My invite code' : 'Mi código de invitación';
  String get enterPartnerCode =>
      isEnglish ? 'Enter your partner\'s code' : 'Ingresá el código de tu duo';
  String get startDuo => isEnglish ? 'Start duo' : 'Empezar duo';
  String get joinDuo => isEnglish ? 'Join duo' : 'Unirme al duo';
  String get duoStreak => isEnglish ? 'Duo streak' : 'Racha del duo';
  String get lockedInToday => isEnglish ? 'Locked in today ✅' : 'Locked in hoy ✅';
  String get notYetToday => isEnglish ? 'Mark today as locked in' : 'Marcar hoy como locked in';
  String get duoActive => isEnglish ? 'Duo active 🔥' : 'Duo activo 🔥';
  String get noDuoYet => isEnglish ? 'No duo yet' : 'Sin duo aún';
  String get partnerName => isEnglish ? 'Partner name (optional)' : 'Nombre de tu duo (opcional)';
  String get leaveDuo => isEnglish ? 'Leave duo' : 'Salir del duo';
  String get leaveDuoConfirm =>
      isEnglish
          ? 'Leave this duo? The shared streak will reset.'
          : '¿Salir del duo? La racha compartida se reiniciará.';
  String get copiedToClipboard =>
      isEnglish ? 'Code copied!' : '¡Código copiado!';
  String get codePlaceholder => isEnglish ? 'e.g. ABC-123' : 'ej. ABC-123';
  String duoStreakLabel(int days) =>
      isEnglish
          ? '$days ${days == 1 ? "day" : "days"} locked in together'
          : '$days ${days == 1 ? "día" : "días"} locked in juntos';

  // ── Legal ─────────────────────────────────────────────────────────────────
  String get privacyPolicy => isEnglish ? 'Privacy Policy' : 'Política de privacidad';
  String get termsOfService => isEnglish ? 'Terms of Service' : 'Términos de servicio';
  String get legalSection => isEnglish ? 'Legal' : 'Legal';
  String get lastUpdated => isEnglish ? 'Last updated: June 2026' : 'Última actualización: junio 2026';
}
