import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_colors.dart';
import '../../data/game_data_center.dart';
import '../../network/protocol/connection_channel.dart';
import '../../network/protocol/wire_messages.dart';
import '../../rendering/wood_table.dart';
import '../../state/multiplayer_session_controller.dart';
import '../widgets/ai_persona_avatar.dart';
import '../widgets/game_button.dart';
import '../widgets/game_loading_overlay.dart';
import 'game_screen.dart';

/// Interactive pre-match table lobby shared across all 3 Local Multiplayer
/// channels (Offline Wi-Fi, Bluetooth, Local Wi-Fi) and ready for Phase 7
/// Online Friends Rooms.
///
/// Players can tap any AI-held seat to switch teams/partners before the Host
/// starts the match. Remaining seats stay filled by distinct [AiPersona] bots.
class RoomLobbyScreen extends ConsumerStatefulWidget {
  const RoomLobbyScreen({super.key});

  @override
  ConsumerState<RoomLobbyScreen> createState() => _RoomLobbyScreenState();
}

class _RoomLobbyScreenState extends ConsumerState<RoomLobbyScreen> {
  bool _navigatedToGame = false;
  bool _copied = false;

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final myAccount = ref.watch(gameDataCenterProvider);
    final session = ref.watch(multiplayerSessionProvider);
    final controller = ref.read(multiplayerSessionProvider.notifier);

    ref.listen<MultiplayerSessionState>(multiplayerSessionProvider, (
      prev,
      next,
    ) {
      if (next.roomClosed && !(prev?.roomClosed ?? false)) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      if (!_navigatedToGame && next.matchView != null) {
        _navigatedToGame = true;
        final view = next.matchView!;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => GameScreen(
              playerCount: view.playerCount,
              rules: view.rules,
              isMultiplayer: true,
            ),
          ),
        );
      }
    });

    final lobby = session.lobby;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_navigatedToGame) {
          controller.leaveSession();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 46,
          title: Text(
            isAr ? 'لوبي الطاولة واختيار المقاعد' : 'Table Lobby & Seats',
            style: const TextStyle(fontSize: 16),
          ),
        ),
        body: WoodTable(
          child: SafeArea(
            child: lobby == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: GameLoadingCard(
                        title: isAr
                            ? 'جارٍ الاتصال بالطاولة...'
                            : 'Connecting to table...',
                        subtitle: session.channel.label(isAr),
                        onCancel: () => Navigator.of(context).pop(),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: Column(
                          children: [
                            _buildRoomHeader(
                              isAr: isAr,
                              lobby: lobby,
                              endpointLabel: session.endpointLabel,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              isAr
                                  ? (lobby.playerCount == 4
                                        ? 'اضغط على أي مقعد متاح لاختيار مكانك وشريكك (المقاعد المقابلة فريق واحد)'
                                        : 'اضغط على المقعد المتاح للتبديل؛ أي مقعد فارغ يكمله الذكاء الاصطناعي')
                                  : 'Tap an open seat to switch sides; AI fills remaining seats',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.ivory.withValues(alpha: 0.78),
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (lobby.playerCount == 4)
                              _buildFourSeatGrid(
                                isAr: isAr,
                                lobby: lobby,
                                myPlayerId: myAccount.playerId,
                                onPickSeat: controller.pickSeat,
                              )
                            else
                              _buildTwoSeatColumn(
                                isAr: isAr,
                                lobby: lobby,
                                myPlayerId: myAccount.playerId,
                                onPickSeat: controller.pickSeat,
                              ),
                            const SizedBox(height: 18),
                            if (session.isHost)
                              SizedBox(
                                width: double.infinity,
                                child: GameButton(
                                  label: isAr ? 'ابدأ المباراة' : 'Start Match',
                                  subtitle: isAr
                                      ? 'اللاعبون المتصلون: ${lobby.humanCount}/${lobby.playerCount} (الباقي شخصيات AI)'
                                      : 'Humans: ${lobby.humanCount}/${lobby.playerCount} (AI fills rest)',
                                  icon: Icons.play_arrow_rounded,
                                  primary: true,
                                  onPressed: controller.startMatchFromHost,
                                ),
                              )
                            else
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xCC1D110A),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.gold.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.gold,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        isAr
                                            ? 'بانتظار المضيف لبدء المباراة...'
                                            : 'Waiting for host to start...',
                                        style: const TextStyle(
                                          color: AppColors.ivory,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoomHeader({
    required bool isAr,
    required RoomLobbyState lobby,
    required String? endpointLabel,
  }) {
    final channelIcon = switch (lobby.channel) {
      SessionChannel.wifiOffline => Icons.wifi_tethering_rounded,
      SessionChannel.bluetooth => Icons.bluetooth_connected_rounded,
      _ => Icons.wifi_rounded,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCharcoal,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(channelIcon, color: AppColors.gold, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${lobby.channel.label(isAr)} • ${lobby.rules.targetScore}',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isAr
                ? 'رقم الغرفة التلقائي (أعطِ هذا الرقم لصديقك)'
                : 'Automatic Room Number (share with friends)',
            style: TextStyle(
              color: AppColors.ivory.withValues(alpha: 0.7),
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _copyCode(lobby.roomCode),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x66000000),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.55),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText(
                    '# ${lobby.roomCode}',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                    color: AppColors.ivory,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (endpointLabel != null && endpointLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              endpointLabel,
              style: TextStyle(
                color: AppColors.ivory.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTwoSeatColumn({
    required bool isAr,
    required RoomLobbyState lobby,
    required String myPlayerId,
    required ValueChanged<int> onPickSeat,
  }) {
    return Column(
      children: [
        _SeatCard(
          slot: lobby.seats[1],
          teamLabel: isAr ? 'المقعد المقابل (2)' : 'Top Seat (2)',
          isMe: lobby.seats[1].humanProfile?.playerId == myPlayerId,
          isAr: isAr,
          onTap: () => onPickSeat(1),
        ),
        const SizedBox(height: 10),
        _FeltTableDivider(isAr: isAr, fourPlayers: false),
        const SizedBox(height: 10),
        _SeatCard(
          slot: lobby.seats[0],
          teamLabel: isAr ? 'المقعد الرئيسي (1)' : 'Bottom Seat (1)',
          isMe: lobby.seats[0].humanProfile?.playerId == myPlayerId,
          isAr: isAr,
          onTap: () => onPickSeat(0),
        ),
      ],
    );
  }

  Widget _buildFourSeatGrid({
    required bool isAr,
    required RoomLobbyState lobby,
    required String myPlayerId,
    required ValueChanged<int> onPickSeat,
  }) {
    // Seats: 0 (Bottom, Team A), 2 (Top Partner, Team A),
    // 1 (Right, Team B), 3 (Left, Team B).
    return Column(
      children: [
        _SeatCard(
          slot: lobby.seats[2],
          teamLabel: isAr ? 'فريق 1 — الشريك المقابل' : 'Team 1 — Top Partner',
          isMe: lobby.seats[2].humanProfile?.playerId == myPlayerId,
          isAr: isAr,
          teamColor: const Color(0xFF4CAF50),
          onTap: () => onPickSeat(2),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SeatCard(
                slot: lobby.seats[3],
                teamLabel: isAr ? 'فريق 2 — يسار' : 'Team 2 — Left',
                isMe: lobby.seats[3].humanProfile?.playerId == myPlayerId,
                isAr: isAr,
                compact: true,
                teamColor: const Color(0xFFE57373),
                onTap: () => onPickSeat(3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SeatCard(
                slot: lobby.seats[1],
                teamLabel: isAr ? 'فريق 2 — يمين' : 'Team 2 — Right',
                isMe: lobby.seats[1].humanProfile?.playerId == myPlayerId,
                isAr: isAr,
                compact: true,
                teamColor: const Color(0xFFE57373),
                onTap: () => onPickSeat(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _FeltTableDivider(isAr: isAr, fourPlayers: true),
        const SizedBox(height: 10),
        _SeatCard(
          slot: lobby.seats[0],
          teamLabel: isAr ? 'فريق 1 — المقعد الأساسي' : 'Team 1 — Bottom',
          isMe: lobby.seats[0].humanProfile?.playerId == myPlayerId,
          isAr: isAr,
          teamColor: const Color(0xFF4CAF50),
          onTap: () => onPickSeat(0),
        ),
      ],
    );
  }
}

class _FeltTableDivider extends StatelessWidget {
  const _FeltTableDivider({required this.isAr, required this.fourPlayers});

  final bool isAr;
  final bool fourPlayers;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F5337), Color(0xFF123622)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Text(
        isAr
            ? (fourPlayers
                  ? 'طاولة الشراكة (فريق 1 أعلى وأسفل × فريق 2 يمين ويسار)'
                  : 'طاولة المواجهة الفردية')
            : (fourPlayers
                  ? 'Partnership Table (Top+Bottom vs Left+Right)'
                  : '1v1 Domino Table'),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.ivory,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SeatCard extends StatelessWidget {
  const _SeatCard({
    required this.slot,
    required this.teamLabel,
    required this.isMe,
    required this.isAr,
    required this.onTap,
    this.compact = false,
    this.teamColor,
  });

  final LobbySeatSlot slot;
  final String teamLabel;
  final bool isMe;
  final bool isAr;
  final VoidCallback onTap;
  final bool compact;
  final Color? teamColor;

  @override
  Widget build(BuildContext context) {
    final human = slot.humanProfile;
    final bot = slot.resolvedBotPersona;
    final canSwitchHere = human == null;

    return GestureDetector(
      onTap: canSwitchHere ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.all(compact ? 10 : 12),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.gold.withValues(alpha: 0.14)
              : AppColors.surfaceCharcoal,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isMe
                ? AppColors.gold
                : (teamColor?.withValues(alpha: 0.5) ?? AppColors.borderSubtle),
            width: isMe ? 1.6 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              teamLabel,
              style: TextStyle(
                color: teamColor ?? AppColors.gold,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (human != null)
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF4A3020),
                      border: Border.all(color: AppColors.gold),
                    ),
                    child: Icon(
                      slot.isHost ? Icons.workspace_premium : Icons.person,
                      color: AppColors.gold,
                      size: 19,
                    ),
                  )
                else
                  AiPersonaAvatar(persona: bot, size: 34),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        human != null
                            ? human.displayName
                            : (isAr ? bot.nameAr : bot.nameEn),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ivory,
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        human != null
                            ? (human.isGuest
                                  ? (isAr ? 'لاعب (ضيف)' : 'Human (Guest)')
                                  : (isAr ? 'حساب مسجل' : 'Verified'))
                            : (isAr
                                  ? 'متاح — اضغط للجلوس هنا (أو AI)'
                                  : 'Open — tap to sit (or AI)'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.ivory.withValues(alpha: 0.65),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
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
