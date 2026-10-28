// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appTitle => 'স্পাই লাভ';

  @override
  String get accountSecurityTitle => 'অ্যাকাউন্ট ও নিরাপত্তা';

  @override
  String get accountSecuritySubtitle =>
      'ওয়ার্কস্পেস পরিচয়, সাইন-ইন লিংক এবং পারস্পরিক সম্মতি নিয়ন্ত্রণ';

  @override
  String get appearanceTitle => 'চেহারা';

  @override
  String get appearanceHint =>
      'হোম ও ডিভাইস স্ক্রিন Consent Horizon লাইট/ডার্ক টোকেন অনুসরণ করে।';

  @override
  String get themeSystem => 'সিস্টেম';

  @override
  String get themeLight => 'লাইট';

  @override
  String get themeDark => 'ডার্ক';

  @override
  String get offlineTitle => 'আপনি অফলাইন';

  @override
  String get offlineBody =>
      'শেষ জানা অবস্থা দেখানো হচ্ছে। পেয়ারিং ও লাইভ সিঙ্কের জন্য সংযোগ দরকার।';

  @override
  String get retry => 'আবার চেষ্টা';

  @override
  String get signInSecurityTitle => 'সাইন-ইন ও নিরাপত্তা';

  @override
  String get signInSecurityBody =>
      'গুগল লিংক করুন বা পাসওয়ার্ড সেট করুন যাতে সম্মতির ইতিহাস না হারিয়ে অ্যাক্সেস ফেরাতে পারেন।';

  @override
  String get l10nRemainingNote =>
      'লোকালাইজেশন কাঠামো চালু; বেশিরভাগ স্ক্রিন এখনও ইংরেজি আক্ষরিক ব্যবহার করে।';
}
