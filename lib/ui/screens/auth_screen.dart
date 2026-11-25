import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_colors.dart';
import '../../data/game_data_center.dart';
import '../../rendering/domino_tile.dart';
import '../../rendering/tile_skin.dart';
import '../../rendering/wood_table.dart';
import '../../state/settings_provider.dart';
import '../widgets/game_button.dart';
import '../widgets/game_loading_overlay.dart';
import 'app_shell_screen.dart';

/// Account gateway screen supporting:
/// 1. Sign-In with existing account (`تسجيل الدخول`)
/// 2. Create a new account & link guest progress (`إنشاء حساب جديد`)
/// 3. Instant 1-tap Guest entry (`المتابعة كضيف`)
///
/// Can be shown on first app launch after [SplashScreen] or opened from the
/// Profile tab (`[popOnComplete] = true`) when a Guest wants to link/upgrade
/// their account without losing their match stats.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.popOnComplete = false});

  final bool popOnComplete;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

enum _AuthMode { login, register }

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final current = ref.read(gameDataCenterProvider);
    if (!current.displayName.startsWith('ضيف')) {
      _nameCtrl.text = current.displayName;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _finishNavigation() {
    if (!mounted) return;
    if (widget.popOnComplete) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const AppShellScreen()),
      );
    }
  }

  Future<void> _submitAuth() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final center = ref.read(gameDataCenterProvider.notifier);
      if (_mode == _AuthMode.login) {
        await center.signInWithEmail(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
        );
      } else {
        await center.registerWithEmail(
          displayName: _nameCtrl.text,
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
        );
      }
      _finishNavigation();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e
            .toString()
            .replaceFirst('Invalid argument(s): ', '')
            .replaceFirst('Bad state: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _enterAsGuest() {
    final customName = _nameCtrl.text.trim();
    ref.read(gameDataCenterProvider.notifier).continueAsGuest(
          guestDisplayName: customName.isEmpty ? null : customName,
        );
    _finishNavigation();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final skin = TileSkin.byId(ref.watch(settingsProvider).tileSkinId);
    final account = ref.watch(gameDataCenterProvider);

    return Scaffold(
      appBar: widget.popOnComplete
          ? AppBar(
              toolbarHeight: 46,
              title: Text(
                isAr ? 'حساب اللاعب' : 'Player Account',
                style: const TextStyle(fontSize: 16),
              ),
            )
          : null,
      body: GameLoadingOverlay(
        visible: _loading,
        title: isAr ? 'جارٍ توثيق الحساب...' : 'Verifying Account...',
        subtitle: isAr
            ? 'يتم حفظ ومزامنة بياناتك في مركز البيانات'
            : 'Syncing your profile with the Data Center',
        child: WoodTable(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 370),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header emblem
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DominoTile(
                            top: 6,
                            bottom: 6,
                            width: 30,
                            skin: skin,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isAr ? 'الدومينو العراقي' : 'Iraqi Domino',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAr
                            ? 'سجّل دخولك لحفظ نقاطك أو العب فوراً كضيف'
                            : 'Sign in to save your progress or play as Guest',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.ivory.withValues(alpha: 0.72),
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Auth Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xDD1D110A),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Mode Switcher: Login vs Register
                            Row(
                              children: [
                                Expanded(
                                  child: _AuthTabChip(
                                    label: isAr
                                        ? 'تسجيل الدخول'
                                        : 'Sign In',
                                    selected: _mode == _AuthMode.login,
                                    onTap: () => setState(() {
                                      _mode = _AuthMode.login;
                                      _error = null;
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _AuthTabChip(
                                    label: isAr
                                        ? 'إنشاء حساب جديد'
                                        : 'Create Account',
                                    selected: _mode == _AuthMode.register,
                                    onTap: () => setState(() {
                                      _mode = _AuthMode.register;
                                      _error = null;
                                    }),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xCC4E1616),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFE57373),
                                  ),
                                ),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: AppColors.ivory,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            if (_mode == _AuthMode.register) ...[
                              TextField(
                                controller: _nameCtrl,
                                style: const TextStyle(
                                  color: AppColors.ivory,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  prefixIcon: const Icon(
                                    Icons.person_outline_rounded,
                                    color: AppColors.gold,
                                    size: 20,
                                  ),
                                  hintText: isAr
                                      ? 'اسم اللاعب في الطاولة'
                                      : 'Display Name',
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],

                            TextField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(
                                color: AppColors.ivory,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                prefixIcon: const Icon(
                                  Icons.alternate_email_rounded,
                                  color: AppColors.gold,
                                  size: 20,
                                ),
                                hintText: isAr
                                    ? 'البريد الإلكتروني'
                                    : 'Email Address',
                              ),
                            ),
                            const SizedBox(height: 10),

                            TextField(
                              controller: _passwordCtrl,
                              obscureText: true,
                              style: const TextStyle(
                                color: AppColors.ivory,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: AppColors.gold,
                                  size: 20,
                                ),
                                hintText: isAr
                                    ? 'كلمة المرور (6 أحرف فأكثر)'
                                    : 'Password (6+ chars)',
                              ),
                            ),
                            const SizedBox(height: 14),

                            if (account.stats.matchesPlayed > 0 &&
                                account.isGuest)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  isAr
                                      ? '✓ سيتم نقل إحصائياتك الحالية (${account.stats.matchesWon} فوز • تقييم ${account.rating}) إلى حسابك تلقائياً.'
                                      : '✓ Your current Guest stats (${account.stats.matchesWon} wins) will be linked automatically.',
                                  style: const TextStyle(
                                    color: Color(0xFF81C784),
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),

                            GameButton(
                              label: _mode == _AuthMode.login
                                  ? (isAr ? 'دخول للحساب' : 'Sign In')
                                  : (isAr
                                        ? 'إنشاء وربط الحساب'
                                        : 'Create & Link Account'),
                              icon: Icons.verified_user_outlined,
                              primary: true,
                              onPressed: _loading ? null : _submitAuth,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Play as Guest Button
                      SizedBox(
                        width: double.infinity,
                        child: GameButton(
                          label: isAr ? 'المتابعة كضيف' : 'Continue as Guest',
                          subtitle: isAr
                              ? 'دخول فوري بدون حساب (${account.displayName})'
                              : 'Instant play without registration (${account.displayName})',
                          icon: Icons.play_circle_outline_rounded,
                          onPressed: _loading ? null : _enterAsGuest,
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
}

class _AuthTabChip extends StatelessWidget {
  const _AuthTabChip({
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
        padding: const EdgeInsets.symmetric(vertical: 10),
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
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? AppColors.gold : AppColors.ivory,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
