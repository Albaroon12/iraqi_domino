import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_colors.dart';
import '../../data/game_data_center.dart';
import '../../engine/game_rules_config.dart';
import '../../rendering/wood_table.dart';
import '../../state/multiplayer_session_controller.dart';
import '../widgets/game_loading_overlay.dart';
import 'game_screen.dart';

/// Live matchmaking screen ("لعب عشوائي أونلاين") that joins the server's
/// matchmaking queue, shows the live count of matched players (`1/4` .. `4/4`),
/// and transitions automatically into [GameScreen] when the match starts.
class OnlineMatchmakingScreen extends ConsumerStatefulWidget {
  const OnlineMatchmakingScreen({
    super.key,
    required this.playerCount,
    required this.rules,
  }) : assert(playerCount == 2 || playerCount == 4);

  final int playerCount;
  final GameRulesConfig rules;

  @override
  ConsumerState<OnlineMatchmakingScreen> createState() =>
      _OnlineMatchmakingScreenState();
}

class _OnlineMatchmakingScreenState
    extends ConsumerState<OnlineMatchmakingScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(multiplayerSessionProvider.notifier).startOnlineMatchmaking(
            playerCount: widget.playerCount,
            rules: widget.rules,
          );
    });
  }

  void _cancelSearch() {
    ref.read(multiplayerSessionProvider.notifier).leaveSession();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final account = ref.watch(gameDataCenterProvider);
    final session = ref.watch(multiplayerSessionProvider);

    ref.listen<MultiplayerSessionState>(multiplayerSessionProvider, (
      prev,
      next,
    ) {
      if (!_navigated && next.matchView != null) {
        _navigated = true;
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

    final humanCount = session.lobby?.humanCount ?? 1;
    final total = widget.playerCount;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_navigated) {
          ref.read(multiplayerSessionProvider.notifier).leaveSession();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 46,
          title: Text(
            isAr ? 'لعب عشوائي (أونلاين)' : 'Random Online Match',
            style: const TextStyle(fontSize: 16),
          ),
        ),
        body: WoodTable(
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: session.errorMessage != null
                    ? Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xDD1D110A),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE57373)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFE57373),
                              size: 36,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              session.errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.ivory,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton(
                              onPressed: _cancelSearch,
                              child: Text(isAr ? 'رجوع' : 'Back'),
                            ),
                          ],
                        ),
                      )
                    : GameLoadingCard(
                        title: isAr
                            ? 'جارٍ البحث عن لاعبين ($humanCount/$total)...'
                            : 'Searching for players ($humanCount/$total)...',
                        subtitle: isAr
                            ? 'حسابك: ${account.displayName} • الهدف ${widget.rules.targetScore}\n(يكمل الذكاء الاصطناعي أي مقعد شاغر تلقائياً)'
                            : 'Player: ${account.displayName} • Target ${widget.rules.targetScore}',
                        onCancel: _cancelSearch,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
