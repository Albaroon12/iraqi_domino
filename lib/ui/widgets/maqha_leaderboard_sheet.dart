import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../ai/ai_persona.dart';
import '../../core/games/game_catalog.dart';
import '../../core/theme/maqha_design_system.dart';
import '../../data/cafe_progression.dart';
import '../../data/player_account.dart';
import '../../network/transport/online_ws_transport.dart';
import 'ai_persona_avatar.dart';

/// Filter scopes shown at the top of the Leaderboard modal sheet.
enum LeaderboardScope {
  rating,
  allTime,
  monthly,
  weekly;

  String label(bool isAr) => switch (this) {
    LeaderboardScope.rating => isAr ? 'التصنيف' : 'Rating',
    LeaderboardScope.allTime => isAr ? 'كل الوقت' : 'All Time',
    LeaderboardScope.monthly => isAr ? 'الشهر' : 'Month',
    LeaderboardScope.weekly => isAr ? 'الأسبوع' : 'Week',
  };
}

/// Resolved leaderboard row model.
class LeaderboardEntryItem {
  const LeaderboardEntryItem({
    required this.nameAr,
    required this.nameEn,
    required this.countryCode,
    required this.points,
    required this.monogramColor,
    this.persona,
    this.isMe = false,
  });

  final String nameAr;
  final String nameEn;
  final String countryCode;
  final int points;
  final Color monogramColor;
  final AiPersona? persona;
  final bool isMe;

  String displayName(bool isAr) => isAr ? nameAr : nameEn;
}

/// Formats integer scores with thousands commas (`1450` -> `1,450`).
String formatLeaderboardPoints(int value) {
  final raw = value.toString();
  final buf = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0 && raw[i - 1] != '-') {
      buf.write(',');
    }
    buf.write(raw[i]);
  }
  return buf.toString();
}

/// Computes the ranked list for [gameId] and [scope], always including [account].
List<LeaderboardEntryItem> buildLeaderboardEntries({
  required PlayerAccount account,
  required String gameId,
  required LeaderboardScope scope,
}) {
  final gameStats = account.statsForGame(gameId);
  final myBaseRating = gameId == 'iraqi_domino'
      ? account.rating
      : (1000 + gameStats.matchesWon * 25);

  final myPts = switch (scope) {
    LeaderboardScope.rating => myBaseRating,
    LeaderboardScope.allTime =>
      myBaseRating + gameStats.matchesWon * 18 + gameStats.roundsWon * 4,
    LeaderboardScope.monthly =>
      (myBaseRating * 0.85).round() + gameStats.matchesWon * 12,
    LeaderboardScope.weekly =>
      (myBaseRating * 0.72).round() + gameStats.roundsWon * 8,
  };

  final seedRivals = switch (gameId) {
    'backgammon' => const <({
      String ar,
      String en,
      String cc,
      int pts,
      int color,
    })>[
      (ar: 'سعد الكرخ', en: 'Saad', cc: 'IQ', pts: 1410, color: 0xFFDDA938),
      (ar: 'مرتضى النجفي', en: 'Murtadha', cc: 'IQ', pts: 1365, color: 0xFF2E7D6B),
      (ar: 'زيد الأعظمي', en: 'Zaid', cc: 'IQ', pts: 1320, color: 0xFFD99B38),
      (ar: 'فهد الدوسري', en: 'Fahad', cc: 'SA', pts: 1295, color: 0xFF7B3FA0),
      (ar: 'أبو عمر', en: 'Abu Omar', cc: 'KW', pts: 1270, color: 0xFFDDA938),
      (ar: 'طلال الشام', en: 'Talal', cc: 'SY', pts: 1240, color: 0xFF397398),
      (ar: 'مازن البصري', en: 'Mazin', cc: 'IQ', pts: 1190, color: 0xFFDDA938),
    ],
    'cards' => const <({
      String ar,
      String en,
      String cc,
      int pts,
      int color,
    })>[
      (ar: 'وسام المنصور', en: 'Wissam', cc: 'IQ', pts: 1395, color: 0xFFDDA938),
      (ar: 'مصطفى الكرادة', en: 'Mustafa', cc: 'IQ', pts: 1350, color: 0xFF2E7D6B),
      (ar: 'عمر الموصلي', en: 'Omar', cc: 'IQ', pts: 1318, color: 0xFFD99B38),
      (ar: 'جاسم السالم', en: 'Jassim', cc: 'KW', pts: 1290, color: 0xFF7B3FA0),
      (ar: 'رامي العلي', en: 'Rami', cc: 'JO', pts: 1264, color: 0xFFDDA938),
      (ar: 'ياسر الحلي', en: 'Yasser', cc: 'IQ', pts: 1230, color: 0xFF397398),
      (ar: 'أحمد سامي', en: 'Ahmed', cc: 'EG', pts: 1185, color: 0xFFDDA938),
    ],
    _ => const <({
      String ar,
      String en,
      String cc,
      int pts,
      int color,
    })>[
      (ar: 'أبو علي البغدادي', en: 'Abu Ali', cc: 'IQ', pts: 1450, color: 0xFFDDA938),
      (ar: 'حيدر المنصور', en: 'Haider', cc: 'IQ', pts: 1385, color: 0xFF2E7D6B),
      (ar: 'كرار البصري', en: 'Karrar', cc: 'IQ', pts: 1342, color: 0xFFD99B38),
      (ar: 'علي حمدي', en: 'Ali Hamdy', cc: 'EG', pts: 1315, color: 0xFF7B3FA0),
      (ar: 'أبو عمر', en: 'Abu Omar', cc: 'KW', pts: 1308, color: 0xFFDDA938),
      (ar: 'أحمد أشرف', en: 'Ahmed Ashraf', cc: 'EG', pts: 1296, color: 0xFFDDA938),
      (ar: 'ليث الموصلي', en: 'Laith', cc: 'IQ', pts: 1275, color: 0xFF397398),
    ],
  };

  int adjustForScope(int base, int index) => switch (scope) {
    LeaderboardScope.rating => base,
    LeaderboardScope.allTime => base + (8 - index) * 42,
    LeaderboardScope.monthly => (base * 0.86).round() + (index % 3) * 14,
    LeaderboardScope.weekly => (base * 0.73).round() + ((7 - index) % 4) * 19,
  };

  final myPersona = AiPersona.all[account.avatarIndex % AiPersona.all.length];
  final entries = <LeaderboardEntryItem>[
    for (var i = 0; i < seedRivals.length; i++)
      LeaderboardEntryItem(
        nameAr: seedRivals[i].ar,
        nameEn: seedRivals[i].en,
        countryCode: seedRivals[i].cc,
        points: adjustForScope(seedRivals[i].pts, i),
        monogramColor: Color(seedRivals[i].color),
        persona: i < 2 ? AiPersona.all[(i + 1) % AiPersona.all.length] : null,
      ),
    LeaderboardEntryItem(
      nameAr: account.displayName,
      nameEn: account.displayName,
      countryCode: 'IQ',
      points: myPts,
      monogramColor: MaqhaColors.avatarJade,
      persona: myPersona,
      isMe: true,
    ),
  ]..sort((a, b) => b.points.compareTo(a.points));

  return entries;
}

/// Subtle, shaded button on the Home tab (calm & understated compared to the
/// primary `العب` gold pill) that opens the full-height Leaderboard sheet.
class MaqhaLeaderboardShadedButton extends StatelessWidget {
  const MaqhaLeaderboardShadedButton({
    super.key,
    required this.gameTitle,
    required this.myRank,
    required this.myPoints,
    required this.isAr,
    required this.onTap,
  });

  final String gameTitle;
  final int myRank;
  final int myPoints;
  final bool isAr;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x9E132524),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: MaqhaColors.goldPrimary.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: MaqhaColors.goldPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.emoji_events_outlined,
                  color: MaqhaColors.goldPrimary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isAr
                          ? 'المتصدرين — $gameTitle'
                          : '$gameTitle Leaderboard',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MaqhaColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      isAr
                          ? 'ترتيبك الحالي #$myRank'
                          : 'Your rank #$myRank',
                      style: const TextStyle(
                        color: MaqhaColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x550B1F1E),
                  borderRadius: MaqhaRadii.pill,
                  border: Border.all(color: MaqhaColors.borderSubtle),
                ),
                child: Text(
                  formatLeaderboardPoints(myPoints),
                  style: const TextStyle(
                    color: MaqhaColors.goldPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: MaqhaColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Large popup Leaderboard sheet styled 1:1 after the Emerald Podium reference:
/// - Centered `المتصدرين` header + concise per-game subtitle
/// - 4 filter pills (`التصنيف`, `كل الوقت`, `الشهر`, `الأسبوع`)
/// - Top-3 Podium (`3` on left, `1` elevated center, `2` on right)
/// - Full-width ranked rows `4+` below
class MaqhaLeaderboardSheet extends StatefulWidget {
  const MaqhaLeaderboardSheet({
    super.key,
    required this.account,
    required this.selectedGame,
    required this.isAr,
  });

  final PlayerAccount account;
  final GameEntry selectedGame;
  final bool isAr;

  static Future<void> show(
    BuildContext context, {
    required PlayerAccount account,
    required GameEntry selectedGame,
    required bool isAr,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.90,
        child: MaqhaLeaderboardSheet(
          account: account,
          selectedGame: selectedGame,
          isAr: isAr,
        ),
      ),
    );
  }

  @override
  State<MaqhaLeaderboardSheet> createState() => _MaqhaLeaderboardSheetState();
}

class _MaqhaLeaderboardSheetState extends State<MaqhaLeaderboardSheet> {
  LeaderboardScope _scope = LeaderboardScope.rating;
  List<LeaderboardEntryItem>? _remoteDominoRatingEntries;

  @override
  void initState() {
    super.initState();
    if (widget.selectedGame.id == 'iraqi_domino' &&
        HttpOverrides.current == null) {
      _tryFetchLiveDominoLeaderboard();
    }
  }

  Future<void> _tryFetchLiveDominoLeaderboard() async {
    try {
      final uri = Uri.parse('${OnlineServerManager.baseUrl}/api/leaderboard');
      final client = HttpClient()
        ..connectionTimeout = const Duration(milliseconds: 750);
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(const Duration(milliseconds: 750));
      if (res.statusCode == HttpStatus.ok) {
        final raw = await utf8.decoder.bind(res).join();
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, Object?>) {
          final list = decoded['leaders'] as List<Object?>?;
          if (list != null && list.length >= 4 && mounted) {
            final parsed = <LeaderboardEntryItem>[];
            for (final item in list) {
              if (item is Map<String, Object?>) {
                final pid = (item['playerId'] as String?) ?? '';
                final name = (item['displayName'] as String?) ?? 'لاعب';
                final rating = (item['rating'] as num?)?.toInt() ?? 1000;
                final av = (item['avatarIndex'] as num?)?.toInt() ?? 0;
                parsed.add(
                  LeaderboardEntryItem(
                    nameAr: name,
                    nameEn: name,
                    countryCode: 'IQ',
                    points: rating,
                    monogramColor: const Color(0xFFDDA938),
                    persona: AiPersona.all[av % AiPersona.all.length],
                    isMe: pid == widget.account.playerId,
                  ),
                );
              }
            }
            if (parsed.length >= 4) {
              setState(() => _remoteDominoRatingEntries = parsed);
            }
          }
        }
      }
      client.close(force: true);
    } catch (_) {}
  }

  String _tierLabel(int rank, int points) {
    return CafeProgression.cafeTitleForRank(
      leaderboardRank: rank,
      rating: points,
      isAr: widget.isAr,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isAr;
    final entries = (_scope == LeaderboardScope.rating &&
            widget.selectedGame.id == 'iraqi_domino' &&
            _remoteDominoRatingEntries != null)
        ? _remoteDominoRatingEntries!
        : buildLeaderboardEntries(
            account: widget.account,
            gameId: widget.selectedGame.id,
            scope: _scope,
          );

    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;
    final rest = entries.length > 3
        ? entries.sublist(3)
        : const <LeaderboardEntryItem>[];
    final pointsWord = _scope == LeaderboardScope.rating
        ? (isAr ? 'نقطة تصنيف' : 'Rating pts')
        : (isAr ? 'نقطة' : 'Points');

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF104932),
            Color(0xFF0C3926),
            Color(0xFF092B1F),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: MaqhaColors.goldPrimary.withValues(alpha: 0.45),
            width: 1.2,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Drag handle + close icon row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.24),
                        border: Border.all(color: MaqhaColors.borderSubtle),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: MaqhaColors.textPrimary,
                        size: 17,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Title & Game Subtitle
          Text(
            isAr ? 'المتصدرين' : 'Leaderboard',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MaqhaColors.goldBright,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isAr
                ? 'أبطال ${widget.selectedGame.title(true)} في المقهى'
                : 'Top ${widget.selectedGame.title(false)} players',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFC7DDD3),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),

          // 4 Filter Pills (Left to Right: التصنيف | كل الوقت | الشهر | الأسبوع)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final tab in LeaderboardScope.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _ScopeFilterPill(
                          label: tab.label(isAr),
                          selected: _scope == tab,
                          onTap: () => setState(() => _scope = tab),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Scrollable Podium (1, 2, 3) + Ranked List (4+)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
              children: [
                // Top-3 Podium: physically Left = #3, Center = #1, Right = #2
                if (first != null)
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: third != null
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 22),
                                  child: _PodiumCard(
                                    rank: 3,
                                    entry: third,
                                    isAr: isAr,
                                    pointsUnit: pointsWord,
                                    tierBadge: _tierLabel(3, third.points),
                                    borderColor: const Color(0xFFBD973E),
                                    rankColor: const Color(0xFFE3A94B),
                                    cardHeight: 146,
                                    avatarSize: 46,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _PodiumCard(
                            rank: 1,
                            entry: first,
                            isAr: isAr,
                            pointsUnit: pointsWord,
                            tierBadge: _tierLabel(1, first.points),
                            borderColor: MaqhaColors.goldBright,
                            rankColor: MaqhaColors.goldBright,
                            cardHeight: 168,
                            avatarSize: 54,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: second != null
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 14),
                                  child: _PodiumCard(
                                    rank: 2,
                                    entry: second,
                                    isAr: isAr,
                                    pointsUnit: pointsWord,
                                    tierBadge: _tierLabel(2, second.points),
                                    borderColor: const Color(0xFF5EC4B6),
                                    rankColor: const Color(0xFF6CD4C5),
                                    cardHeight: 156,
                                    avatarSize: 48,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 18),

                // Ranks 4+ Horizontal Bars
                for (var i = 0; i < rest.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _LeaderboardListRow(
                      rank: i + 4,
                      entry: rest[i],
                      isAr: isAr,
                      pointsUnit: pointsWord,
                      tierBadge: _tierLabel(i + 4, rest[i].points),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeFilterPill extends StatelessWidget {
  const _ScopeFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF2C957) : const Color(0xFF0A2B1D),
          borderRadius: MaqhaRadii.pill,
          border: Border.all(
            color: selected
                ? const Color(0xFFF2C957)
                : const Color(0xFF285B44),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF1B1405) : MaqhaColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({
    required this.rank,
    required this.entry,
    required this.isAr,
    required this.pointsUnit,
    required this.tierBadge,
    required this.borderColor,
    required this.rankColor,
    required this.cardHeight,
    required this.avatarSize,
  });

  final int rank;
  final LeaderboardEntryItem entry;
  final bool isAr;
  final String pointsUnit;
  final String tierBadge;
  final Color borderColor;
  final Color rankColor;
  final double cardHeight;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final overlap = avatarSize * 0.50;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Player name + country code above the avatar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.displayName(isAr),
                    style: TextStyle(
                      color: entry.isMe
                          ? MaqhaColors.goldBright
                          : MaqhaColors.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    entry.countryCode,
                    style: const TextStyle(
                      color: Color(0xFF9AB8AC),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Card with overlapping circular avatar on top border
          SizedBox(
            height: cardHeight + overlap,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: overlap,
                  left: 0,
                  right: 0,
                  height: cardHeight,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(6, overlap + 4, 6, 8),
                    decoration: BoxDecoration(
                      color: entry.isMe
                          ? const Color(0xFF134631)
                          : const Color(0xFF0B3624),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: borderColor,
                        width: rank == 1 ? 1.5 : 1.1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$rank',
                          style: TextStyle(
                            color: rankColor,
                            fontSize: rank == 1 ? 25 : 22,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formatLeaderboardPoints(entry.points),
                              style: const TextStyle(
                                color: MaqhaColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              pointsUnit,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF93B3A5),
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                        _TierPillBadge(label: tierBadge),
                      ],
                    ),
                  ),
                ),
                _LeaderboardAvatarCircle(
                  entry: entry,
                  size: avatarSize,
                  ringColor: borderColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardListRow extends StatelessWidget {
  const _LeaderboardListRow({
    required this.rank,
    required this.entry,
    required this.isAr,
    required this.pointsUnit,
    required this.tierBadge,
  });

  final int rank;
  final LeaderboardEntryItem entry;
  final bool isAr;
  final String pointsUnit;
  final String tierBadge;

  @override
  Widget build(BuildContext context) {
    // Matches the screenshot: right side has Rank -> Avatar -> Name -> Tier Pill,
    // left side has Score stacked above "نقطة تصنيف".
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: entry.isMe
              ? const Color(0xFF144732)
              : const Color(0xFF0C3826),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: entry.isMe
                ? MaqhaColors.goldPrimary.withValues(alpha: 0.75)
                : const Color(0xFF1D543D),
            width: entry.isMe ? 1.3 : 1.0,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MaqhaColors.goldBright,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _LeaderboardAvatarCircle(
              entry: entry,
              size: 34,
              ringColor: entry.monogramColor,
              preferMonogram: !entry.isMe,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 3,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    entry.displayName(isAr),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: entry.isMe
                          ? MaqhaColors.goldBright
                          : MaqhaColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    entry.countryCode,
                    style: const TextStyle(
                      color: Color(0xFF93B3A5),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _TierPillBadge(label: tierBadge),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatLeaderboardPoints(entry.points),
                  style: const TextStyle(
                    color: MaqhaColors.goldBright,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                Text(
                  pointsUnit,
                  style: const TextStyle(
                    color: Color(0xFF93B3A5),
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TierPillBadge extends StatelessWidget {
  const _TierPillBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF243A1F),
        borderRadius: MaqhaRadii.pill,
        border: Border.all(
          color: const Color(0xFFB5943B),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFF2C957),
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LeaderboardAvatarCircle extends StatelessWidget {
  const _LeaderboardAvatarCircle({
    required this.entry,
    required this.size,
    required this.ringColor,
    this.preferMonogram = false,
  });

  final LeaderboardEntryItem entry;
  final double size;
  final Color ringColor;
  final bool preferMonogram;

  @override
  Widget build(BuildContext context) {
    final trimmed = entry.nameAr.trim();
    final letter = trimmed.isEmpty ? 'م' : trimmed.characters.first;
    final showPersona = entry.persona != null && !preferMonogram;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: entry.monogramColor,
        border: Border.all(color: ringColor, width: 1.6),
      ),
      child: showPersona
          ? ClipOval(
              child: AiPersonaAvatar(persona: entry.persona!, size: size - 3),
            )
          : Text(
              letter,
              style: TextStyle(
                color: entry.monogramColor.computeLuminance() > 0.42
                    ? const Color(0xFF1A1204)
                    : Colors.white,
                fontSize: size * 0.42,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
    );
  }
}
