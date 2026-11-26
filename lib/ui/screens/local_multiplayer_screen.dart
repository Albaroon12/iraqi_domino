import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ai/ai_difficulty.dart';
import '../../core/constants/app_colors.dart';
import '../../data/game_data_center.dart';
import '../../data/player_account.dart';
import '../../engine/game_rules_config.dart';
import '../../network/protocol/connection_channel.dart';
import '../../network/transport/peer_transport.dart';
import '../../rendering/wood_table.dart';
import '../../state/multiplayer_session_controller.dart';
import '../../state/settings_provider.dart';
import '../localized_names.dart';
import '../widgets/game_button.dart';
import '../widgets/game_loading_overlay.dart';
import 'room_lobby_screen.dart';

/// Local Play hub reached from the single "اللعب المحلي" button:
/// 1. Choose the connection method:
///    - واي فاي بدون إنترنت (Wi-Fi Direct / Hotspot)
///    - بلوتوث (Bluetooth)
///    - شبكة الواي فاي (Wi-Fi)
/// 2. Host creates a room with an automatic 4-digit Room Number (e.g. `4829`).
/// 3. Second player either:
///    - Enters the 4-digit Room Number directly, OR
///    - Searches & picks from the Available Rooms list.
class LocalMultiplayerScreen extends ConsumerStatefulWidget {
  const LocalMultiplayerScreen({
    super.key,
    required this.playerCount,
    this.initialChannel = SessionChannel.wifiOffline,
  }) : assert(playerCount == 2 || playerCount == 4);

  final int playerCount;
  final SessionChannel initialChannel;

  @override
  ConsumerState<LocalMultiplayerScreen> createState() =>
      _LocalMultiplayerScreenState();
}

enum _JoinTab { byRoomNumber, browseAvailable }

class _LocalMultiplayerScreenState
    extends ConsumerState<LocalMultiplayerScreen> {
  final TextEditingController _roomNumberCtrl = TextEditingController();
  late SessionChannel _selectedChannel;
  _JoinTab _joinTab = _JoinTab.byRoomNumber;

  @override
  void initState() {
    super.initState();
    _selectedChannel = widget.initialChannel;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(multiplayerSessionProvider.notifier)
          .selectChannel(_selectedChannel);
    });
  }

  @override
  void dispose() {
    _roomNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _switchChannel(SessionChannel channel) async {
    setState(() => _selectedChannel = channel);
    await ref.read(multiplayerSessionProvider.notifier).selectChannel(channel);
  }

  Future<void> _switchJoinTab(_JoinTab tab) async {
    setState(() => _joinTab = tab);
    if (tab == _JoinTab.browseAvailable) {
      await ref.read(multiplayerSessionProvider.notifier).startScanning();
    }
  }

  Future<void> _editPlayerName(PlayerAccount account, bool isAr) async {
    final textCtrl = TextEditingController(text: account.displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF23140C),
        title: Text(
          isAr ? 'اسم اللاعب في الطاولة' : 'Player Display Name',
          style: const TextStyle(color: AppColors.gold, fontSize: 16),
        ),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          maxLength: 24,
          style: const TextStyle(color: AppColors.ivory),
          decoration: InputDecoration(
            hintText: isAr ? 'أدخل اسمك...' : 'Enter your name...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(textCtrl.text),
            child: Text(
              isAr ? 'حفظ' : 'Save',
              style: const TextStyle(color: AppColors.gold),
            ),
          ),
        ],
      ),
    );
    textCtrl.dispose();
    if (newName != null && newName.trim().isNotEmpty) {
      ref.read(gameDataCenterProvider.notifier).updateDisplayName(newName);
    }
  }

  Future<void> _hostTable(GameRulesConfig rules) async {
    final ok = await ref.read(multiplayerSessionProvider.notifier).hostRoom(
          channel: _selectedChannel,
          playerCount: widget.playerCount,
          rules: rules,
        );
    if (!ok || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RoomLobbyScreen()),
    );
    if (mounted) {
      ref
          .read(multiplayerSessionProvider.notifier)
          .selectChannel(_selectedChannel);
    }
  }

  Future<void> _joinDiscovered(DiscoveredRoom room) async {
    final ok = await ref.read(multiplayerSessionProvider.notifier).joinRoom(
          channel: _selectedChannel,
          room: room,
        );
    if (!ok || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RoomLobbyScreen()),
    );
    if (mounted) {
      ref
          .read(multiplayerSessionProvider.notifier)
          .selectChannel(_selectedChannel);
    }
  }

  Future<void> _joinByRoomNumber() async {
    final code = _roomNumberCtrl.text.trim();
    if (code.isEmpty) return;
    final ok = await ref.read(multiplayerSessionProvider.notifier).joinRoom(
          channel: _selectedChannel,
          codeOrEndpoint: code,
        );
    if (!ok || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RoomLobbyScreen()),
    );
    if (mounted) {
      ref
          .read(multiplayerSessionProvider.notifier)
          .selectChannel(_selectedChannel);
    }
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
                ? 'اللعب المحلي (${widget.playerCount == 4 ? "4 لاعبين" : "لاعبان"})'
                : 'Local Play (${widget.playerCount}P)',
            style: const TextStyle(fontSize: 16),
          ),
        ),
        body: GameLoadingOverlay(
          visible: session.connecting,
          title: session.isHost
              ? (isAr ? 'جارٍ تجهيز الغرفة...' : 'Creating Room...')
              : (isAr ? 'جارٍ الاتصال بالغرفة...' : 'Connecting to Room...'),
          subtitle: _selectedChannel.label(isAr),
          onCancel: () =>
              ref.read(multiplayerSessionProvider.notifier).leaveSession(),
          child: WoodTable(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Unified GameDataCenter Identity Strip
                      _IdentityBanner(
                        account: account,
                        isAr: isAr,
                        onEditName: () => _editPlayerName(account, isAr),
                      ),
                      const SizedBox(height: 12),

                      // 2. Step 1: Choose Local Method
                      Text(
                        isAr
                            ? '1. اختر طريقة اللعب المحلي'
                            : '1. Choose Connection Method',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final ch in SessionChannel.localChannels) ...[
                        _ChannelSelectorTile(
                          channel: ch,
                          selected: _selectedChannel == ch,
                          isAr: isAr,
                          onTap: () => _switchChannel(ch),
                        ),
                        const SizedBox(height: 8),
                      ],

                      if (session.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xCC4E1616),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE57373)),
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

                      const SizedBox(height: 4),

                      // 3. Host Card (Automatic 4-digit Room Number)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCharcoal,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAr ? 'إنشاء غرفة جديدة' : 'Create Room',
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
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
                                    ? 'إنشاء غرفة (${_selectedChannel.label(true)})'
                                    : 'Create Room (${_selectedChannel.label(false)})',
                                icon: Icons.add_circle_outline_rounded,
                                primary: true,
                                onPressed: session.connecting
                                    ? null
                                    : () => _hostTable(rules),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 4. Second Player Join Card: (Enter Room Number OR Search Available Rooms)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCharcoal,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              isAr ? 'الانضمام لغرفة' : 'Join Room',
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Toggle between "Enter Room Number" and "Available Rooms"
                            Row(
                              children: [
                                Expanded(
                                  child: _ModeSegmentButton(
                                    label: isAr
                                        ? 'إدخال رقم الغرفة'
                                        : 'Room Number',
                                    icon: Icons.pin_outlined,
                                    selected:
                                        _joinTab == _JoinTab.byRoomNumber,
                                    onTap: () =>
                                        _switchJoinTab(_JoinTab.byRoomNumber),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _ModeSegmentButton(
                                    label: isAr
                                        ? 'الغرف المتاحة (${session.discoveredRooms.length})'
                                        : 'Available (${session.discoveredRooms.length})',
                                    icon: Icons.radar_rounded,
                                    selected:
                                        _joinTab == _JoinTab.browseAvailable,
                                    onTap: () => _switchJoinTab(
                                      _JoinTab.browseAvailable,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            if (_joinTab == _JoinTab.byRoomNumber) ...[
                              TextField(
                                controller: _roomNumberCtrl,
                                keyboardType: TextInputType.text,
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
                                      ? 'دخول برقم الغرفة'
                                      : 'Join by Room Number',
                                  icon: Icons.login_rounded,
                                  onPressed: session.connecting
                                      ? null
                                      : _joinByRoomNumber,
                                ),
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.gold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isAr
                                          ? 'جاري البحث في الغرف المتاحة قريباً منك...'
                                          : 'Searching nearby available rooms...',
                                      style: TextStyle(
                                        color: AppColors.ivory.withValues(
                                          alpha: 0.72,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      color: AppColors.gold,
                                      size: 20,
                                    ),
                                    onPressed: () => ref
                                        .read(
                                          multiplayerSessionProvider.notifier,
                                        )
                                        .startScanning(),
                                  ),
                                ],
                              ),
                              if (session.discoveredRooms.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    isAr
                                        ? 'لم تظهر غرف بعد — تأكد أن المضيف أنشأ الغرفة على نفس الطريقة، أو ادخل رقم الغرفة مباشرةً.'
                                        : 'No rooms found yet — ensure host created a room or join by Room Number.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.ivory.withValues(
                                        alpha: 0.6,
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
                                        borderRadius: BorderRadius.circular(12),
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

class _ModeSegmentButton extends StatelessWidget {
  const _ModeSegmentButton({
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

class _IdentityBanner extends StatelessWidget {
  const _IdentityBanner({
    required this.account,
    required this.isAr,
    required this.onEditName,
  });

  final PlayerAccount account;
  final bool isAr;
  final VoidCallback onEditName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCharcoal,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_circle_rounded, color: AppColors.gold),
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
                            ? 'مركز البيانات: وضع الضيف (${account.rating} نقطة)'
                            : 'Data Hub: Guest Mode (${account.rating} pts)')
                      : (isAr
                            ? 'حساب مسجل (${account.rating} نقطة)'
                            : 'Signed-In (${account.rating} pts)'),
                  style: TextStyle(
                    color: AppColors.ivory.withValues(alpha: 0.65),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEditName,
            icon: const Icon(
              Icons.edit_outlined,
              color: AppColors.gold,
              size: 19,
            ),
            tooltip: isAr ? 'تعديل الاسم' : 'Edit name',
          ),
        ],
      ),
    );
  }
}

class _ChannelSelectorTile extends StatelessWidget {
  const _ChannelSelectorTile({
    required this.channel,
    required this.selected,
    required this.isAr,
    required this.onTap,
  });

  final SessionChannel channel;
  final bool selected;
  final bool isAr;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (channel) {
      SessionChannel.wifiOffline => Icons.wifi_tethering_rounded,
      SessionChannel.bluetooth => Icons.bluetooth_connected_rounded,
      _ => Icons.wifi_rounded,
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.14)
              : AppColors.surfaceCharcoal,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.borderSubtle,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.gold, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.label(isAr),
                    style: const TextStyle(
                      color: AppColors.ivory,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    channel.subtitle(isAr),
                    style: TextStyle(
                      color: AppColors.ivory.withValues(alpha: 0.7),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected
                  ? AppColors.gold
                  : AppColors.ivory.withValues(alpha: 0.45),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
