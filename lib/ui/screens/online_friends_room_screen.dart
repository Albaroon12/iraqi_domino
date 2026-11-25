import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ai/ai_difficulty.dart';
import '../../core/constants/app_colors.dart';
import '../../data/game_data_center.dart';
import '../../engine/game_rules_config.dart';
import '../../network/protocol/connection_channel.dart';
import '../../network/transport/online_ws_transport.dart';
import '../../network/transport/peer_transport.dart';
import '../../rendering/wood_table.dart';
import '../../state/multiplayer_session_controller.dart';
import '../../state/settings_provider.dart';
import '../localized_names.dart';
import '../widgets/game_button.dart';
import '../widgets/game_loading_overlay.dart';
import 'auth_screen.dart';
import 'room_lobby_screen.dart';

/// Online Friends Room screen ("غرفة أصدقاء أونلاين") powered by
/// `DominoOnlineServer` over WebSocket:
/// 1. Shows the player's unified [GameDataCenter] account (Guest or Signed-In)
///    with a quick link to [AuthScreen].
/// 2. Host creates an online room on the server with an automatic 4-digit Room
///    Number (e.g. `# 4829`).
/// 3. Friends from anywhere enter the 4-digit Room Number OR browse open rooms
///    on the server, then pick their seats/partners in [RoomLobbyScreen].
class OnlineFriendsRoomScreen extends ConsumerStatefulWidget {
  const OnlineFriendsRoomScreen({super.key, required this.playerCount})
    : assert(playerCount == 2 || playerCount == 4);

  final int playerCount;

  @override
  ConsumerState<OnlineFriendsRoomScreen> createState() =>
      _OnlineFriendsRoomScreenState();
}

enum _OnlineJoinTab { byRoomNumber, browseServer }

class _OnlineFriendsRoomScreenState
    extends ConsumerState<OnlineFriendsRoomScreen> {
  final TextEditingController _roomNumberCtrl = TextEditingController();
  _OnlineJoinTab _joinTab = _OnlineJoinTab.byRoomNumber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(multiplayerSessionProvider.notifier).stopScanning();
    });
  }

  @override
  void dispose() {
    _roomNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _switchJoinTab(_OnlineJoinTab tab) async {
    setState(() => _joinTab = tab);
    if (tab == _OnlineJoinTab.browseServer) {
      await ref
          .read(multiplayerSessionProvider.notifier)
          .selectChannel(SessionChannel.onlineRoom);
      await ref
          .read(multiplayerSessionProvider.notifier)
          .startScanning(playerCount: widget.playerCount);
    } else {
      await ref.read(multiplayerSessionProvider.notifier).stopScanning();
    }
  }

  Future<void> _editServerUrl(bool isAr) async {
    final ctrl = TextEditingController(text: OnlineServerManager.baseUrl);
    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF23140C),
        title: Text(
          isAr ? 'عنوان سيرفر الأونلاين' : 'Online Server URL',
          style: const TextStyle(color: AppColors.gold, fontSize: 16),
        ),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: AppColors.ivory, fontSize: 13.5),
          decoration: const InputDecoration(
            hintText: 'http://127.0.0.1:8080',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: Text(
              isAr ? 'حفظ' : 'Save',
              style: const TextStyle(color: AppColors.gold),
            ),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (updated != null && updated.trim().isNotEmpty) {
      setState(() => OnlineServerManager.setBaseUrl(updated));
    }
  }

  Future<void> _hostOnlineRoom(GameRulesConfig rules) async {
    final ok = await ref
        .read(multiplayerSessionProvider.notifier)
        .hostOnlineRoom(playerCount: widget.playerCount, rules: rules);
    if (!ok || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RoomLobbyScreen()),
    );
  }

  Future<void> _joinByCode() async {
    final code = _roomNumberCtrl.text.trim();
    if (code.isEmpty) return;
    final ok = await ref
        .read(multiplayerSessionProvider.notifier)
        .joinOnlineRoom(playerCount: widget.playerCount, roomCode: code);
    if (!ok || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RoomLobbyScreen()),
    );
  }

  Future<void> _joinDiscovered(DiscoveredRoom room) async {
    final ok = await ref
        .read(multiplayerSessionProvider.notifier)
        .joinOnlineRoom(playerCount: widget.playerCount, room: room);
    if (!ok || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RoomLobbyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final account = ref.watch(gameDataCenterProvider);
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final session = ref.watch(multiplayerSessionProvider);

    final rules = GameRulesConfig(
      targetScore: settings.targetScore,
      aiDifficulty: settings.aiDifficulty,
    );

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          ref.read(multiplayerSessionProvider.notifier).stopScanning();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 46,
          title: Text(
            isAr
                ? 'غرفة أصدقاء أونلاين (${widget.playerCount == 4 ? "4 لاعبين" : "لاعبان"})'
                : 'Online Friends Room (${widget.playerCount}P)',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.dns_outlined,
                color: AppColors.gold,
                size: 20,
              ),
              tooltip: isAr ? 'عنوان السيرفر' : 'Server URL',
              onPressed: () => _editServerUrl(isAr),
            ),
          ],
        ),
        body: GameLoadingOverlay(
          visible: session.connecting,
          title: session.isHost
              ? (isAr
                    ? 'جارٍ إنشاء الغرفة على السيرفر...'
                    : 'Creating Online Room...')
              : (isAr
                    ? 'جارٍ الاتصال بغرفة الصديق...'
                    : 'Joining Online Room...'),
          subtitle: OnlineServerManager.baseUrl,
          onCancel: () =>
              ref.read(multiplayerSessionProvider.notifier).leaveSession(),
          child: WoodTable(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Player Account Strip (Guest / Signed-In)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xCC180E09),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                account.isGuest
                                    ? Icons.person_outline_rounded
                                    : Icons.verified_user_rounded,
                                color: AppColors.gold,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      account.displayName,
                                      style: const TextStyle(
                                        color: AppColors.ivory,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      account.isGuest
                                          ? (isAr
                                                ? 'تلعب كضيف • التقييم ${account.rating}'
                                                : 'Guest Mode • Rating ${account.rating}')
                                          : (isAr
                                                ? 'حساب موثّق • التقييم ${account.rating}'
                                                : 'Verified • Rating ${account.rating}'),
                                      style: TextStyle(
                                        color: AppColors.ivory.withValues(
                                          alpha: 0.65,
                                        ),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (account.isGuest)
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const AuthScreen(
                                          popOnComplete: true,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    isAr ? 'ربط حساب' : 'Sign In',
                                    style: const TextStyle(
                                      color: AppColors.gold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (session.errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xCC4E1616),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE57373),
                              ),
                            ),
                            child: Text(
                              session.errorMessage!,
                              style: const TextStyle(
                                color: AppColors.ivory,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // 2. Host Online Room Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xDD1D110A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAr
                                    ? '1. إنشاء غرفة أونلاين جديدة'
                                    : '1. Create Online Room',
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isAr
                                    ? 'يُنشئ السيرفر رقم غرفة تلقائياً من 4 أرقام لتشاركه مع أصدقائك وتختاروا المقاعد والشركاء'
                                    : 'Server generates a 4-digit room code for your friends',
                                style: TextStyle(
                                  color: AppColors.ivory.withValues(alpha: 0.7),
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final d in AiDifficulty.values)
                                    ChoiceChip(
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      label: Text(
                                        aiDifficultyName(isAr, d),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      selected: settings.aiDifficulty == d,
                                      onSelected: (_) =>
                                          settingsNotifier.setAiDifficulty(d),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: GameButton(
                                  label: isAr
                                      ? 'إنشاء غرفة على السيرفر'
                                      : 'Create Online Room',
                                  icon: Icons.cloud_done_outlined,
                                  primary: true,
                                  onPressed: session.connecting
                                      ? null
                                      : () => _hostOnlineRoom(rules),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 3. Join Friend's Online Room Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xDD1D110A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                isAr
                                    ? '2. الانضمام لغرفة صديق أونلاين'
                                    : '2. Join Friend\'s Online Room',
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _OnlineTabButton(
                                      label: isAr
                                          ? 'إدخال رقم الغرفة'
                                          : 'Room Number',
                                      icon: Icons.pin_outlined,
                                      selected:
                                          _joinTab ==
                                          _OnlineJoinTab.byRoomNumber,
                                      onTap: () => _switchJoinTab(
                                        _OnlineJoinTab.byRoomNumber,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _OnlineTabButton(
                                      label: isAr
                                          ? 'الغرف المتاحة (${session.discoveredRooms.length})'
                                          : 'Open Rooms (${session.discoveredRooms.length})',
                                      icon: Icons.public_rounded,
                                      selected:
                                          _joinTab ==
                                          _OnlineJoinTab.browseServer,
                                      onTap: () => _switchJoinTab(
                                        _OnlineJoinTab.browseServer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              if (_joinTab == _OnlineJoinTab.byRoomNumber) ...[
                                TextField(
                                  controller: _roomNumberCtrl,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.ivory,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 3,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: isAr
                                        ? 'أدخل رقم الغرفة (مثال: 4829)'
                                        : 'Enter Room # (e.g. 4829)',
                                    hintStyle: TextStyle(
                                      color: AppColors.ivory.withValues(
                                        alpha: 0.45,
                                      ),
                                      fontSize: 13.5,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: GameButton(
                                    label: isAr
                                        ? 'دخول الغرفة عبر السيرفر'
                                        : 'Join Online Room',
                                    icon: Icons.login_rounded,
                                    onPressed: session.connecting
                                        ? null
                                        : _joinByCode,
                                  ),
                                ),
                              ] else ...[
                                if (session.discoveredRooms.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      isAr
                                          ? 'لا توجد غرف مفتوحة حالياً على السيرفر — أنشئ غرفة أو ادخل برقم الغرفة.'
                                          : 'No open rooms on server right now.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppColors.ivory.withValues(
                                          alpha: 0.65,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                else
                                  for (final room in session.discoveredRooms)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 4,
                                            ),
                                        tileColor: const Color(0x66000000),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          side: BorderSide(
                                            color: AppColors.gold.withValues(
                                              alpha: 0.4,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          '${room.hostName}  •  #${room.roomCode}',
                                          style: const TextStyle(
                                            color: AppColors.ivory,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        subtitle: Text(
                                          isAr
                                              ? 'اللاعبون: ${room.occupiedHumans}/${room.playerCount} • الهدف: ${room.targetScore}'
                                              : 'Players: ${room.occupiedHumans}/${room.playerCount} • Target: ${room.targetScore}',
                                          style: TextStyle(
                                            color: AppColors.ivory.withValues(
                                              alpha: 0.7,
                                            ),
                                            fontSize: 11.5,
                                          ),
                                        ),
                                        trailing: ElevatedButton(
                                          onPressed: session.connecting
                                              ? null
                                              : () => _joinDiscovered(room),
                                          child: Text(isAr ? 'انضمام' : 'Join'),
                                        ),
                                      ),
                                    ),
                              ],
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
      ),
    );
  }
}

class _OnlineTabButton extends StatelessWidget {
  const _OnlineTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.22)
              : const Color(0x55000000),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.gold
                : AppColors.gold.withValues(alpha: 0.25),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppColors.gold : AppColors.ivory,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? AppColors.gold : AppColors.ivory,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
