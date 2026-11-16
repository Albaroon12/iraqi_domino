// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Iraqi Domino';

  @override
  String get phaseOneReady => 'App shell is ready';

  @override
  String get tileGallery => 'Tile Gallery';

  @override
  String get tablePreview => 'Table Preview';

  @override
  String get skinIvory => 'Ivory';

  @override
  String get skinEbony => 'Ebony';

  @override
  String get skinRuby => 'Ruby';

  @override
  String get play => 'Play';

  @override
  String get settings => 'Settings';

  @override
  String get chooseMode => 'Choose game mode';

  @override
  String get modeTwoPlayers => 'Two players';

  @override
  String get modeTwoPlayersDesc => 'Head to head, seven tiles each';

  @override
  String get modeFourPlayers => 'Four players';

  @override
  String get modeFourPlayersDesc => 'Two teams, your partner sits opposite you';

  @override
  String get modeAzneef => 'Azneef';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get gameScreenComingSoon => 'The game screen arrives in the next step';

  @override
  String targetScoreLabel(int score) {
    return 'Target: $score points';
  }

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsTargetScore => 'Target score (default for local games)';

  @override
  String get settingsTileSkin => 'Tile style';

  @override
  String get settingsSound => 'Sound';

  @override
  String get playerYou => 'You';

  @override
  String get playerPartner => 'Your partner';

  @override
  String get opponentRight => 'Right opponent';

  @override
  String get opponentLeft => 'Left opponent';

  @override
  String get opponentSingle => 'Opponent';

  @override
  String get teamUs => 'Us';

  @override
  String get teamThem => 'Them';

  @override
  String get targetShort => 'Target';

  @override
  String tilesLeft(int count) {
    return 'Tiles: $count';
  }

  @override
  String boneyardCount(int count) {
    return 'Draw pile: $count';
  }

  @override
  String get passButton => 'I have none';

  @override
  String get drawButton => 'Draw';

  @override
  String get featureComingSoon => 'This feature comes in a later phase';

  @override
  String get previewRoundResult => 'Preview round result';

  @override
  String get weWonRound => 'You won the round';

  @override
  String get theyWonRound => 'The opponent won the round';

  @override
  String get roundBurned => 'Burned round';

  @override
  String get reasonDomino => 'A player played all their tiles';

  @override
  String get reasonBlocked => 'The game is blocked; the lowest total wins';

  @override
  String get reasonBurned => 'Tie on a block: no points, the round is replayed';

  @override
  String roundPoints(int points) {
    return 'Round points: $points';
  }

  @override
  String totalsLine(int ours, int theirs) {
    return 'Total: $ours vs $theirs';
  }

  @override
  String get nextRound => 'Next round';

  @override
  String youStartRound(String piece) {
    return 'You start the round with $piece';
  }

  @override
  String otherStartsRound(String name, String piece) {
    return '$name starts the round with $piece';
  }

  @override
  String get redeal => 'Deal again';

  @override
  String get youStartRoundFree => 'You start the round with any piece';

  @override
  String otherStartsRoundFree(String name) {
    return '$name starts the round';
  }

  @override
  String saysNoTiles(String name) {
    return '$name: I have none';
  }

  @override
  String passesTurn(String name) {
    return '$name: passes';
  }

  @override
  String drawsTile(String name) {
    return '$name: draws a tile';
  }
}
