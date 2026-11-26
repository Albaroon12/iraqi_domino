import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ai/ai_difficulty.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/maqha_design_system.dart';
import '../../data/cafe_events_and_tournaments.dart';
import '../../data/game_data_center.dart';
import '../../data/player_account.dart';
import '../../engine/game_rules_config.dart';
import '../../network/transport/online_ws_transport.dart';
import '../widgets/cafe_prop_widget.dart';
import '../widgets/game_button.dart';
import 'game_screen.dart';

/// Phase 10+: Interactive Tournaments (daily free cup + staked 10%-rake cups),
/// Fixed Recurring Events (`daily`/`weekly`/`monthly`), Seasonal Events
/// (`Ramadan`/`Eid`), and Custom Sponsored Ad Events with Banner Images.
class CafeTournamentsView extends ConsumerStatefulWidget {
  const CafeTournamentsView({super.key, required this.isAr});

  final bool isAr;

  @override
  ConsumerState<CafeTournamentsView> createState() =>
      _CafeTournamentsViewState();
}

enum _LiveOpsSection { tournaments, events }

class _CafeTournamentsViewState extends ConsumerState<CafeTournamentsView> {
  _LiveOpsSection _section = _LiveOpsSection.tournaments;
  List<CafeTournamentTier> _tournaments = CafeLiveOpsDefaults.tournaments;
  List<CafeEventDefinition> _events = [
    for (final e in CafeLiveOpsDefaults.events)
      if (e.isActiveOn()) e,
  ];
  bool _syncing = false;
  bool _syncedFromServer = false;

  bool get isAr => widget.isAr;

  @override
  void initState() {
    super.initState();
    if (HttpOverrides.current == null) {
      _syncFromServer(autoBootLocalIfNeeded: false);
    }
  }

  Future<void> _syncFromServer({bool autoBootLocalIfNeeded = true}) async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      if (autoBootLocalIfNeeded) {
        await OnlineServerManager.ensureServerReady();
      }
      final uri = Uri.parse('${OnlineServerManager.baseUrl}/api/live-ops');
      final client = HttpClient()
        ..connectionTimeout = const Duration(milliseconds: 900);
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(const Duration(milliseconds: 900));
      if (res.statusCode == HttpStatus.ok) {
        final raw = await utf8.decoder.bind(res).join();
        final map = jsonDecode(raw);
        if (map is Map<String, Object?>) {
          final evList = map['events'] as List<Object?>?;
          final cupList = map['tournaments'] as List<Object?>?;
          if (mounted) {
            setState(() {
              if (evList != null) {
                _events = [
                  for (final x in evList)
                    if (x is Map<String, Object?>)
                      CafeEventDefinition.fromJson(x),
                ];
              }
              if (cupList != null && cupList.isNotEmpty) {
                _tournaments = [
                  for (final x in cupList)
                    if (x is Map<String, Object?>)
                      CafeTournamentTier.fromJson(x),
                ];
              }
              _syncedFromServer = true;
            });
          }
        }
      }
      client.close(force: true);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _showToast(String message, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: success
              ? const Color(0xFF1F3B24)
              : const Color(0xFF4A1B18),
          behavior: SnackBarBehavior.floating,
          content: Text(
            message,
            style: const TextStyle(
              color: AppColors.ivory,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
  }

  Future<void> _openSponsorDetailsDialog(CafeEventDefinition ev) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MaqhaColors.cardCharcoal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.gold.withValues(alpha: 0.55)),
        ),
        title: Row(
          children: [
            const Icon(Icons.campaign_rounded, color: AppColors.gold, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ev.sponsorName.isNotEmpty
                    ? (isAr
                          ? 'برعاية: ${ev.sponsorName}'
                          : 'Sponsored by ${ev.sponsorName}')
                    : ev.title(isAr),
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ev.bannerImageUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 130,
                  child: _EventBannerImage(imageSource: ev.bannerImageUrl),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              ev.description(isAr),
              style: const TextStyle(color: AppColors.ivory, fontSize: 13),
            ),
            if (ev.sponsorUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              SelectableText(
                ev.sponsorUrl,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              isAr ? 'إغلاق' : 'Close',
              style: const TextStyle(color: AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onTapEnterTournament(
    CafeTournamentTier tier,
    PlayerAccount account,
  ) async {
    final freeAvailable = account.hasFreeDailyTournamentAvailable();
    if (tier.isDailyFree &&
        !freeAvailable &&
        account.extraTournamentTickets <= 0) {
      _showToast(
        isAr
            ? 'انتهى الدخول المجاني اليوم — يمكنك استخدام تذكرة إضافية من السوق'
            : 'Today\'s free entry is used — grab an Extra Ticket from Shop',
        success: false,
      );
      return;
    }

    if (!tier.isDailyFree && account.cafeDinars < tier.entryFeeDinars) {
      _showToast(
        isAr
            ? 'رصيدك من دينار المقهى غير كافٍ'
            : 'Insufficient Al-Maqha Dinars',
        success: false,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MaqhaColors.cardCharcoal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.gold.withValues(alpha: 0.55)),
        ),
        title: Text(
          tier.title(isAr),
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryLine(
              label: isAr ? 'رسم الدخول:' : 'Entry Fee:',
              value: tier.isDailyFree
                  ? (freeAvailable
                        ? (isAr ? 'مجاني اليوم' : 'Free Today')
                        : (isAr ? '1 تذكرة بطولة' : '1 Ticket'))
                  : '${tier.entryFeeDinars} ${isAr ? "دينار المقهى" : "Dinars"}',
            ),
            if (!tier.isDailyFree) ...[
              _SummaryLine(
                label: isAr
                    ? 'مجموع الطاولة (${tier.playerCount} لاعبين):'
                    : 'Gross Table Pool (${tier.playerCount}p):',
                value: '${tier.grossPoolDinars} د',
              ),
              _SummaryLine(
                label: isAr ? 'عمولة المقهى (10%):' : 'Commission (10%):',
                value: '-${tier.rakeDeductedDinars} د',
              ),
            ],
            const Divider(color: Color(0x44D4AF37), height: 18),
            _SummaryLine(
              label: isAr ? 'صافي الجائزة:' : 'Net Prize:',
              value:
                  '${tier.netPrizeDinars} ${isAr ? "دينار المقهى" : "Dinars"}',
              highlightGold: true,
            ),
            _SummaryLine(
              label: isAr ? 'خبرة الفوز:' : 'Bonus XP:',
              value: '+${tier.bonusXpForWinner} XP',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              isAr ? 'دخول وبدء البطولة' : 'Enter & Start',
              style: const TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final status = ref
        .read(gameDataCenterProvider.notifier)
        .startTournamentSession(tier);

    if (status == TournamentEntryStatus.enteredFreeDaily ||
        status == TournamentEntryStatus.enteredWithTicket ||
        status == TournamentEntryStatus.enteredPaid) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GameScreen(
            playerCount: tier.playerCount,
            rules: GameRulesConfig(
              targetScore: tier.targetScore,
              aiDifficulty: AiDifficulty.byId(tier.aiDifficultyId),
            ),
            activeTournament: tier,
          ),
        ),
      );
    }
  }

  void _onClaimEvent(CafeEventDefinition ev) {
    final ok = ref.read(gameDataCenterProvider.notifier).claimEventReward(ev);
    if (ok) {
      _showToast(
        isAr
            ? 'تم استلام +${ev.rewardDinars} دينار المقهى و +${ev.rewardBonusXp} XP'
            : 'Claimed +${ev.rewardDinars} Dinars & +${ev.rewardBonusXp} XP',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(gameDataCenterProvider);
    final claimableCount = [
      for (final e in _events)
        if (!e.isClaimedBy(account) && e.isCompletedBy(account)) e,
    ].length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isAr ? 'المهام والبطولات' : 'Missions & Cups',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            CafeDinarPill(amount: account.cafeDinars, isAr: isAr, compact: true),
            IconButton(
              onPressed: _syncing ? null : () => _syncFromServer(),
              tooltip: isAr ? 'مزامنة' : 'Sync',
              icon: _syncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _syncedFromServer
                          ? Icons.cloud_done_rounded
                          : Icons.sync_rounded,
                      color: AppColors.gold,
                      size: 20,
                    ),
            ),
          ],
        ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: MaqhaColors.cardCharcoal,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: MaqhaColors.borderSubtle),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: AppColors.gold,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isAr
                        ? 'كؤوس البطولات: ${account.tournamentsWon}'
                        : 'Cups Won: ${account.tournamentsWon}',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.confirmation_number_outlined,
                    color: MaqhaColors.textMuted,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isAr
                        ? 'التذاكر: ${account.extraTournamentTickets}'
                        : 'Tickets: ${account.extraTournamentTickets}',
                    style: const TextStyle(
                      color: AppColors.ivory,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                avatar: const Icon(Icons.emoji_events_outlined, size: 16),
                label: SizedBox(
                  width: double.infinity,
                  child: Text(
                    isAr ? 'البطولات' : 'Tournaments',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                selected: _section == _LiveOpsSection.tournaments,
                onSelected: (_) =>
                    setState(() => _section = _LiveOpsSection.tournaments),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                avatar: const Icon(Icons.track_changes_rounded, size: 16),
                label: SizedBox(
                  width: double.infinity,
                  child: Text(
                    claimableCount > 0
                        ? (isAr
                              ? 'الإيفنتات ($claimableCount)'
                              : 'Events ($claimableCount)')
                        : (isAr ? 'الإيفنتات' : 'Events'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                selected: _section == _LiveOpsSection.events,
                onSelected: (_) =>
                    setState(() => _section = _LiveOpsSection.events),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_section == _LiveOpsSection.tournaments) ...[
          for (final tier in _tournaments)
            Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: _TournamentCard(
                tier: tier,
                account: account,
                isAr: isAr,
                onEnter: () => _onTapEnterTournament(tier, account),
              ),
            ),
        ] else ...[
          if (_events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                isAr ? 'لا توجد إيفنتات نشطة حالياً' : 'No active events',
                textAlign: TextAlign.center,
                style: const TextStyle(color: MaqhaColors.textMuted),
              ),
            ),
          for (final ev in _events)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SeasonalOrSponsoredEventCard(
                event: ev,
                account: account,
                isAr: isAr,
                onClaim: () => _onClaimEvent(ev),
                onOpenSponsor: () => _openSponsorDetailsDialog(ev),
              ),
            ),
        ],
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.highlightGold = false,
  });

  final String label;
  final String value;
  final bool highlightGold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.ivory.withValues(alpha: 0.78),
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: highlightGold ? AppColors.gold : AppColors.ivory,
              fontSize: highlightGold ? 14 : 12.5,
              fontWeight: highlightGold ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  const _TournamentCard({
    required this.tier,
    required this.account,
    required this.isAr,
    required this.onEnter,
  });

  final CafeTournamentTier tier;
  final PlayerAccount account;
  final bool isAr;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final freeReady =
        tier.isDailyFree && account.hasFreeDailyTournamentAvailable();
    final canUseTicket = tier.isDailyFree && account.extraTournamentTickets > 0;

    final String entryBadge;
    if (tier.isDailyFree) {
      if (freeReady) {
        entryBadge = isAr ? 'مجاني اليوم' : 'Free Today';
      } else if (canUseTicket) {
        entryBadge = isAr ? 'بتذكرة بطولة' : 'Use Ticket';
      } else {
        entryBadge = isAr ? 'يتجدد غداً' : 'Resets Tomorrow';
      }
    } else {
      entryBadge = isAr
          ? 'الدخول: ${tier.entryFeeDinars} د'
          : 'Entry: ${tier.entryFeeDinars} D';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MaqhaColors.cardCharcoal,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: tier.isDailyFree
              ? const Color(0xFF66BB6A).withValues(alpha: 0.7)
              : MaqhaColors.borderSubtle,
          width: tier.isDailyFree ? 1.4 : 1.0,
        ),
        boxShadow: MaqhaShadows.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.18),
                  border: Border.all(color: AppColors.gold),
                ),
                child: Icon(
                  tier.isDailyFree
                      ? Icons.card_giftcard_rounded
                      : Icons.emoji_events_rounded,
                  color: AppColors.gold,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tier.title(isAr),
                      style: const TextStyle(
                        color: AppColors.ivory,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tier.description(isAr),
                      style: const TextStyle(
                        color: MaqhaColors.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          const Divider(height: 1, color: MaqhaColors.borderSubtle),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr
                          ? 'الجائزة: ${tier.netPrizeDinars} دينار المقهى'
                          : 'Prize: ${tier.netPrizeDinars} Dinars',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tier.isDailyFree
                          ? '$entryBadge  •  +${tier.bonusXpForWinner} XP'
                          : (isAr
                                ? '$entryBadge  •  عمولة 10% (-${tier.rakeDeductedDinars} د)'
                                : '$entryBadge  •  10% Rake (-${tier.rakeDeductedDinars} D)'),
                      style: const TextStyle(
                        color: MaqhaColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 108,
                child: GameButton(
                  label: isAr ? 'شارك' : 'Enter',
                  primary: true,
                  onPressed: onEnter,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeasonalOrSponsoredEventCard extends StatelessWidget {
  const _SeasonalOrSponsoredEventCard({
    required this.event,
    required this.account,
    required this.isAr,
    required this.onClaim,
    required this.onOpenSponsor,
  });

  final CafeEventDefinition event;
  final PlayerAccount account;
  final bool isAr;
  final VoidCallback onClaim;
  final VoidCallback onOpenSponsor;

  @override
  Widget build(BuildContext context) {
    final bannerColor = Color(event.theme.bannerHex);
    final claimed = event.isClaimedBy(account);
    final progress = event.clampedProgressOf(account);
    final target = event.targetValue;
    final completed = event.isCompletedBy(account);
    final ratio = (progress / target).clamp(0.0, 1.0);
    final recurrenceLabel = event.recurrence.badgeLabel(isAr);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            bannerColor.withValues(alpha: 0.42),
            MaqhaColors.cardCharcoal,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: event.isSponsored || (completed && !claimed)
              ? AppColors.gold
              : MaqhaColors.borderSubtle,
          width: event.isSponsored || (completed && !claimed) ? 1.6 : 1.0,
        ),
        boxShadow: MaqhaShadows.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (event.bannerImageUrl.isNotEmpty)
            SizedBox(
              height: 132,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _EventBannerImage(imageSource: event.bannerImageUrl),
                  if (event.sponsorName.isNotEmpty)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: MaqhaColors.cardCharcoal.withValues(
                            alpha: 0.9,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.gold),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.campaign_rounded,
                              color: AppColors.gold,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isAr
                                  ? 'برعاية: ${event.sponsorName}'
                                  : 'Sponsored: ${event.sponsorName}',
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x66000000),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.55),
                        ),
                      ),
                      child: Text(
                        event.sponsorName.isNotEmpty &&
                                event.bannerImageUrl.isEmpty
                            ? (isAr
                                  ? 'برعاية: ${event.sponsorName}'
                                  : 'Sponsored: ${event.sponsorName}')
                            : event.theme.badgeLabel(isAr),
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (recurrenceLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x55123824),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(
                              0xFF81C784,
                            ).withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          recurrenceLabel,
                          style: const TextStyle(
                            color: Color(0xFF81C784),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    if (event.endDateIso.isNotEmpty)
                      Text(
                        isAr
                            ? 'ينتهي: ${event.endDateIso}'
                            : 'Ends: ${event.endDateIso}',
                        style: const TextStyle(
                          color: MaqhaColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  event.title(isAr),
                  style: const TextStyle(
                    color: AppColors.ivory,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  event.description(isAr),
                  style: const TextStyle(
                    color: MaqhaColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                if (event.isSponsored &&
                    (event.sponsorCtaLabel.isNotEmpty ||
                        event.sponsorUrl.isNotEmpty)) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      onPressed: onOpenSponsor,
                      icon: const Icon(
                        Icons.open_in_new_rounded,
                        size: 15,
                        color: AppColors.gold,
                      ),
                      label: Text(
                        event.sponsorCtaLabel.isNotEmpty
                            ? event.sponsorCtaLabel
                            : (isAr ? 'تفاصيل الراعي' : 'Sponsor Info'),
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: claimed ? 1.0 : ratio,
                    backgroundColor: const Color(0x66000000),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.gold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isAr
                            ? '+${event.rewardDinars} دينار  •  +${event.rewardBonusXp} XP'
                            : '+${event.rewardDinars} Dinars  •  +${event.rewardBonusXp} XP',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (claimed)
                      Text(
                        isAr ? 'تم الاستلام' : 'Claimed',
                        style: const TextStyle(
                          color: Color(0xFF81C784),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    else if (completed)
                      GestureDetector(
                        onTap: onClaim,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            gradient: MaqhaGradients.primaryGoldCta,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isAr ? 'استلام' : 'Claim',
                            style: const TextStyle(
                              color: MaqhaColors.textOnGold,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        '$progress / $target',
                        style: const TextStyle(
                          color: AppColors.ivory,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders either an inline Base64 image (`data:image/...;base64,...`) uploaded
/// from `/admin` OR a remote `http(s)://` image URL with graceful fallback.
class _EventBannerImage extends StatelessWidget {
  const _EventBannerImage({required this.imageSource});

  final String imageSource;

  @override
  Widget build(BuildContext context) {
    if (imageSource.startsWith('data:image')) {
      final comma = imageSource.indexOf(',');
      if (comma >= 0 && comma + 1 < imageSource.length) {
        try {
          final bytes = base64Decode(imageSource.substring(comma + 1));
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallbackBanner(),
          );
        } catch (_) {
          return _fallbackBanner();
        }
      }
      return _fallbackBanner();
    }
    return Image.network(
      imageSource,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _fallbackBanner(),
    );
  }

  Widget _fallbackBanner() {
    return Container(
      color: MaqhaColors.bgMidTeal,
      alignment: Alignment.center,
      child: const Icon(
        Icons.campaign_rounded,
        color: AppColors.gold,
        size: 38,
      ),
    );
  }
}
