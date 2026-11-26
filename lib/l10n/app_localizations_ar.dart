// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'المقهى';

  @override
  String get tileGallery => 'معرض القطع';

  @override
  String get tablePreview => 'معاينة الطاولة';

  @override
  String get skinIvory => 'عاجي';

  @override
  String get skinEbony => 'أبنوس';

  @override
  String get skinRuby => 'ياقوتي';

  @override
  String get play => 'العب';

  @override
  String get settings => 'الإعدادات';

  @override
  String get chooseMode => 'اختر نمط اللعب';

  @override
  String get modeTwoPlayers => 'لاعبان';

  @override
  String get modeTwoPlayersDesc => 'مواجهة مباشرة، سبع قطع لكل لاعب';

  @override
  String get modeFourPlayers => 'أربعة لاعبين';

  @override
  String get modeFourPlayersDesc => 'فريقان، وشريكك يجلس مقابلك';

  @override
  String get modeAzneef => 'أزنيف';

  @override
  String get comingSoon => 'قريباً';

  @override
  String targetScoreLabel(int score) {
    return 'الهدف: $score نقطة';
  }

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsTargetScore => 'هدف النقاط (الافتراضي للعب المحلي)';

  @override
  String get settingsTileSkin => 'شكل القطع';

  @override
  String get settingsSound => 'الأصوات';

  @override
  String get playerYou => 'أنت';

  @override
  String get playerPartner => 'شريكك';

  @override
  String get opponentRight => 'الخصم الأيمن';

  @override
  String get opponentLeft => 'الخصم الأيسر';

  @override
  String get opponentSingle => 'الخصم';

  @override
  String get teamUs => 'فريقنا';

  @override
  String get teamThem => 'فريقهم';

  @override
  String get targetShort => 'الهدف';

  @override
  String boneyardCount(int count) {
    return 'السحب: $count';
  }

  @override
  String get weWonRound => 'فزتم بالجولة';

  @override
  String get theyWonRound => 'فاز الخصم بالجولة';

  @override
  String get roundBurned => 'جولة محروقة';

  @override
  String get reasonDomino => 'أنهى لاعب كل قطعه';

  @override
  String get reasonBlocked => 'انقفلت اللعبة، والأقل نقاطاً يفوز';

  @override
  String get reasonBurned => 'تعادل عند القفل، بدون نقاط وتُعاد الجولة';

  @override
  String roundPoints(int points) {
    return 'نقاط الجولة: $points';
  }

  @override
  String totalsLine(int ours, int theirs) {
    return 'المجموع: $ours مقابل $theirs';
  }

  @override
  String get nextRound => 'الجولة التالية';

  @override
  String youStartRound(String piece) {
    return 'تبدأ الجولة بالقطعة $piece';
  }

  @override
  String otherStartsRound(String name, String piece) {
    return '$name يبدأ الجولة بالقطعة $piece';
  }

  @override
  String get redeal => 'إعادة التوزيع';

  @override
  String get youStartRoundFree => 'تبدأ الجولة بأي قطعة';

  @override
  String otherStartsRoundFree(String name) {
    return '$name يبدأ الجولة';
  }

  @override
  String saysNoTiles(String name) {
    return '$name: ما عندي';
  }

  @override
  String passesTurn(String name) {
    return '$name: عبور';
  }

  @override
  String drawsTile(String name) {
    return '$name: سحب قطعة';
  }
}
