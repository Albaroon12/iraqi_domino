import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'الدومينو العراقي'**
  String get appTitle;

  /// No description provided for @phaseOneReady.
  ///
  /// In ar, this message translates to:
  /// **'هيكل التطبيق جاهز'**
  String get phaseOneReady;

  /// No description provided for @tileGallery.
  ///
  /// In ar, this message translates to:
  /// **'معرض القطع'**
  String get tileGallery;

  /// No description provided for @tablePreview.
  ///
  /// In ar, this message translates to:
  /// **'معاينة الطاولة'**
  String get tablePreview;

  /// No description provided for @skinIvory.
  ///
  /// In ar, this message translates to:
  /// **'عاجي'**
  String get skinIvory;

  /// No description provided for @skinEbony.
  ///
  /// In ar, this message translates to:
  /// **'أبنوس'**
  String get skinEbony;

  /// No description provided for @skinRuby.
  ///
  /// In ar, this message translates to:
  /// **'ياقوتي'**
  String get skinRuby;

  /// No description provided for @play.
  ///
  /// In ar, this message translates to:
  /// **'العب'**
  String get play;

  /// No description provided for @settings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settings;

  /// No description provided for @chooseMode.
  ///
  /// In ar, this message translates to:
  /// **'اختر نمط اللعب'**
  String get chooseMode;

  /// No description provided for @modeTwoPlayers.
  ///
  /// In ar, this message translates to:
  /// **'لاعبان'**
  String get modeTwoPlayers;

  /// No description provided for @modeTwoPlayersDesc.
  ///
  /// In ar, this message translates to:
  /// **'مواجهة مباشرة، سبع قطع لكل لاعب'**
  String get modeTwoPlayersDesc;

  /// No description provided for @modeFourPlayers.
  ///
  /// In ar, this message translates to:
  /// **'أربعة لاعبين'**
  String get modeFourPlayers;

  /// No description provided for @modeFourPlayersDesc.
  ///
  /// In ar, this message translates to:
  /// **'فريقان، وشريكك يجلس مقابلك'**
  String get modeFourPlayersDesc;

  /// No description provided for @modeAzneef.
  ///
  /// In ar, this message translates to:
  /// **'أزنيف'**
  String get modeAzneef;

  /// No description provided for @comingSoon.
  ///
  /// In ar, this message translates to:
  /// **'قريباً'**
  String get comingSoon;

  /// No description provided for @gameScreenComingSoon.
  ///
  /// In ar, this message translates to:
  /// **'شاشة اللعب تأتي في الخطوة القادمة'**
  String get gameScreenComingSoon;

  /// No description provided for @targetScoreLabel.
  ///
  /// In ar, this message translates to:
  /// **'الهدف: {score} نقطة'**
  String targetScoreLabel(int score);

  /// No description provided for @settingsLanguage.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get settingsLanguage;

  /// No description provided for @settingsTargetScore.
  ///
  /// In ar, this message translates to:
  /// **'هدف النقاط (الافتراضي للعب المحلي)'**
  String get settingsTargetScore;

  /// No description provided for @settingsTileSkin.
  ///
  /// In ar, this message translates to:
  /// **'شكل القطع'**
  String get settingsTileSkin;

  /// No description provided for @settingsSound.
  ///
  /// In ar, this message translates to:
  /// **'الأصوات'**
  String get settingsSound;

  /// No description provided for @playerYou.
  ///
  /// In ar, this message translates to:
  /// **'أنت'**
  String get playerYou;

  /// No description provided for @playerPartner.
  ///
  /// In ar, this message translates to:
  /// **'شريكك'**
  String get playerPartner;

  /// No description provided for @opponentRight.
  ///
  /// In ar, this message translates to:
  /// **'الخصم الأيمن'**
  String get opponentRight;

  /// No description provided for @opponentLeft.
  ///
  /// In ar, this message translates to:
  /// **'الخصم الأيسر'**
  String get opponentLeft;

  /// No description provided for @opponentSingle.
  ///
  /// In ar, this message translates to:
  /// **'الخصم'**
  String get opponentSingle;

  /// No description provided for @teamUs.
  ///
  /// In ar, this message translates to:
  /// **'فريقنا'**
  String get teamUs;

  /// No description provided for @teamThem.
  ///
  /// In ar, this message translates to:
  /// **'فريقهم'**
  String get teamThem;

  /// No description provided for @targetShort.
  ///
  /// In ar, this message translates to:
  /// **'الهدف'**
  String get targetShort;

  /// No description provided for @tilesLeft.
  ///
  /// In ar, this message translates to:
  /// **'القطع: {count}'**
  String tilesLeft(int count);

  /// No description provided for @boneyardCount.
  ///
  /// In ar, this message translates to:
  /// **'السحب: {count}'**
  String boneyardCount(int count);

  /// No description provided for @passButton.
  ///
  /// In ar, this message translates to:
  /// **'ما عندي'**
  String get passButton;

  /// No description provided for @drawButton.
  ///
  /// In ar, this message translates to:
  /// **'اسحب'**
  String get drawButton;

  /// No description provided for @featureComingSoon.
  ///
  /// In ar, this message translates to:
  /// **'هذه الميزة تأتي في مرحلة لاحقة'**
  String get featureComingSoon;

  /// No description provided for @previewRoundResult.
  ///
  /// In ar, this message translates to:
  /// **'معاينة نتيجة الجولة'**
  String get previewRoundResult;

  /// No description provided for @weWonRound.
  ///
  /// In ar, this message translates to:
  /// **'فزتم بالجولة'**
  String get weWonRound;

  /// No description provided for @theyWonRound.
  ///
  /// In ar, this message translates to:
  /// **'فاز الخصم بالجولة'**
  String get theyWonRound;

  /// No description provided for @roundBurned.
  ///
  /// In ar, this message translates to:
  /// **'جولة محروقة'**
  String get roundBurned;

  /// No description provided for @reasonDomino.
  ///
  /// In ar, this message translates to:
  /// **'أنهى لاعب كل قطعه'**
  String get reasonDomino;

  /// No description provided for @reasonBlocked.
  ///
  /// In ar, this message translates to:
  /// **'انقفلت اللعبة، والأقل نقاطاً يفوز'**
  String get reasonBlocked;

  /// No description provided for @reasonBurned.
  ///
  /// In ar, this message translates to:
  /// **'تعادل عند القفل، بدون نقاط وتُعاد الجولة'**
  String get reasonBurned;

  /// No description provided for @roundPoints.
  ///
  /// In ar, this message translates to:
  /// **'نقاط الجولة: {points}'**
  String roundPoints(int points);

  /// No description provided for @totalsLine.
  ///
  /// In ar, this message translates to:
  /// **'المجموع: {ours} مقابل {theirs}'**
  String totalsLine(int ours, int theirs);

  /// No description provided for @nextRound.
  ///
  /// In ar, this message translates to:
  /// **'الجولة التالية'**
  String get nextRound;

  /// No description provided for @youStartRound.
  ///
  /// In ar, this message translates to:
  /// **'تبدأ الجولة بالقطعة {piece}'**
  String youStartRound(String piece);

  /// No description provided for @otherStartsRound.
  ///
  /// In ar, this message translates to:
  /// **'{name} يبدأ الجولة بالقطعة {piece}'**
  String otherStartsRound(String name, String piece);

  /// No description provided for @redeal.
  ///
  /// In ar, this message translates to:
  /// **'إعادة التوزيع'**
  String get redeal;

  /// No description provided for @youStartRoundFree.
  ///
  /// In ar, this message translates to:
  /// **'تبدأ الجولة'**
  String get youStartRoundFree;

  /// No description provided for @otherStartsRoundFree.
  ///
  /// In ar, this message translates to:
  /// **'{name} يبدأ الجولة'**
  String otherStartsRoundFree(String name);

  /// No description provided for @saysNoTiles.
  ///
  /// In ar, this message translates to:
  /// **'{name}: ما عندي'**
  String saysNoTiles(String name);

  /// No description provided for @passesTurn.
  ///
  /// In ar, this message translates to:
  /// **'{name}: عبور'**
  String passesTurn(String name);

  /// No description provided for @drawsTile.
  ///
  /// In ar, this message translates to:
  /// **'{name}: سحب قطعة'**
  String drawsTile(String name);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
