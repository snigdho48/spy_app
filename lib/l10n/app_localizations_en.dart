// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Spy Love';

  @override
  String get accountSecurityTitle => 'Account & security';

  @override
  String get accountSecuritySubtitle =>
      'Workspace identity, linked sign-in, and mutual consent controls';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get appearanceHint =>
      'Home and device screens follow Consent Horizon light and dark tokens.';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get offlineTitle => 'You\'re offline';

  @override
  String get offlineBody =>
      'Showing last known status. Pairing and live sync need a connection.';

  @override
  String get retry => 'Retry';

  @override
  String get signInSecurityTitle => 'Sign-in & security';

  @override
  String get signInSecurityBody =>
      'Link Google or set a password so you can recover access without losing consent history.';

  @override
  String get l10nRemainingNote =>
      'Localization scaffold is active; most screens still use English literals.';
}
