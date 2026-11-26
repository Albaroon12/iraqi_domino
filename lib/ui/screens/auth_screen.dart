import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/maqha_design_system.dart';
import '../../data/game_data_center.dart';
import '../../rendering/domino_tile.dart';
import '../../rendering/tile_skin.dart';
import '../../rendering/wood_table.dart';
import '../../state/settings_provider.dart';
import '../widgets/game_button.dart';
import '../widgets/game_loading_overlay.dart';
import 'app_shell_screen.dart';

/// Account gateway screen for **المقهى** (`Al-Maqha`) supporting:
/// 1. **تسجيل الدخول (`Sign In`)** & **إنشاء حساب جديد (`Create Account`)**
/// 2. **3 Authentication Methods**:
///    - **البريد الإلكتروني وكلمة السر (`Email & Password`)** — active
///    - **حساب Google (`Google Account / Gmail on phone`)** — active
///    - **رقم الهاتف (`Phone Number`)** — visible & marked disabled (`غير مفعل`)
/// 3. **المتابعة كضيف (`Continue as Guest`)**
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

  Future<void> _submitEmailAuth() async {
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

  Future<void> _submitGoogleAccountAuth(bool isAr) async {
    final initialMail = _emailCtrl.text.trim().contains('@')
        ? _emailCtrl.text.trim()
        : '';
    final mailCtrl = TextEditingController(text: initialMail);
    final chosenEmail = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MaqhaColors.cardCharcoal,
        title: Row(
          children: [
            const _GoogleGlyphIcon(size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isAr
                    ? 'اختر حساب Google على الهاتف'
                    : 'Choose Google Account',
                style: const TextStyle(color: AppColors.gold, fontSize: 15.5),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: mailCtrl,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          style: const TextStyle(color: AppColors.ivory),
          decoration: InputDecoration(
            hintText: isAr ? 'example@gmail.com' : 'example@gmail.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(mailCtrl.text.trim()),
            child: Text(
              isAr ? 'متابعة بحساب Google' : 'Continue',
              style: const TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    mailCtrl.dispose();
    if (chosenEmail == null || chosenEmail.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(gameDataCenterProvider.notifier).signInWithGoogle(
            googleEmail: chosenEmail,
            displayNameOverride: _nameCtrl.text.trim(),
          );
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
            ? 'يتم حفظ ومزامنة بياناتك في مركز بيانات المقهى'
            : 'Syncing your profile with Al-Maqha Data Center',
        child: WoodTable(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DominoTile(
                            top: 6,
                            bottom: 6,
                            width: 28,
                            skin: skin,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isAr ? 'المقهى' : 'Al-Maqha',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAr ? 'تسجيل الدخول وحفظ التقدم' : 'Sign in & save progress',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: MaqhaColors.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Main Auth Card (Login vs Register + 3 Provider Options)
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: MaqhaColors.cardCharcoal,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: MaqhaColors.borderSubtle),
                          boxShadow: MaqhaShadows.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Mode Switcher: Sign In vs Create Account
                            Row(
                              children: [
                                Expanded(
                                  child: _AuthTabChip(
                                    label: isAr ? 'تسجيل الدخول' : 'Sign In',
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
                            const SizedBox(height: 12),

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

                            // 2. Method A: Email & Password
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
                                      ? 'اسم اللاعب في المقهى'
                                      : 'Display Name',
                                ),
                              ),
                              const SizedBox(height: 9),
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
                            const SizedBox(height: 9),

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
                            const SizedBox(height: 12),

                            if (account.stats.matchesPlayed > 0 &&
                                account.isGuest)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  isAr
                                      ? '✓ سيتم ربط إحصائياتك ودنانيرك الحالية (${account.cafeDinars} د) بحسابك تلقائياً.'
                                      : '✓ Your Guest stats & Dinars will be linked automatically.',
                                  style: const TextStyle(
                                    color: Color(0xFF81C784),
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),

                            GameButton(
                              label: _mode == _AuthMode.login
                                  ? (isAr
                                        ? 'دخول بالبريد الإلكتروني'
                                        : 'Sign In with Email')
                                  : (isAr
                                        ? 'إنشاء وربط الحساب'
                                        : 'Create & Link Account'),
                              icon: Icons.verified_user_outlined,
                              primary: true,
                              onPressed: _loading ? null : _submitEmailAuth,
                            ),

                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: AppColors.gold.withValues(
                                      alpha: 0.22,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    isAr
                                        ? 'أو المتابعة السريعة عبر'
                                        : 'Or continue via',
                                    style: TextStyle(
                                      color: AppColors.ivory.withValues(
                                        alpha: 0.65,
                                      ),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: AppColors.gold.withValues(
                                      alpha: 0.22,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // 3. Method B: Google Account on Phone (Active!)
                            _ProviderOptionTile(
                              customLeading: const _GoogleGlyphIcon(size: 20),
                              icon: Icons.mail_outline_rounded,
                              accentColor: const Color(0xFF4285F4),
                              title: _mode == _AuthMode.login
                                  ? (isAr
                                        ? 'تسجيل الدخول باستخدام Google'
                                        : 'Sign In with Google')
                                  : (isAr
                                        ? 'التسجيل باستخدام حساب Google'
                                        : 'Sign Up with Google'),
                              subtitle: isAr
                                  ? 'عبر حساب Google في الهاتف'
                                  : 'Google account on phone',
                              enabled: !_loading,
                              onTap: () => _submitGoogleAccountAuth(isAr),
                            ),
                            const SizedBox(height: 8),

                            // 4. Method C: Phone Number (Visible, Currently Disabled!)
                            _ProviderOptionTile(
                              icon: Icons.phone_iphone_rounded,
                              accentColor: AppColors.ivory.withValues(
                                alpha: 0.45,
                              ),
                              title: _mode == _AuthMode.login
                                  ? (isAr
                                        ? 'الدخول عن طريق رقم الهاتف'
                                        : 'Sign In with Phone Number')
                                  : (isAr
                                        ? 'التسجيل عن طريق رقم الهاتف'
                                        : 'Register with Phone Number'),
                              subtitle: isAr
                                  ? 'يتوفر قريباً'
                                  : 'Coming soon',
                              badgeText: isAr ? 'غير مفعل' : 'Disabled',
                              enabled: false,
                              onTap: null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Play as Guest Button
                      SizedBox(
                        width: double.infinity,
                        child: GameButton(
                          label: isAr ? 'المتابعة كضيف' : 'Continue as Guest',
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

class _ProviderOptionTile extends StatelessWidget {
  const _ProviderOptionTile({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
    this.customLeading,
    this.badgeText,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;
  final Widget? customLeading;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.56,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: MaqhaColors.bgDeepTeal.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: enabled
                  ? accentColor.withValues(alpha: 0.55)
                  : MaqhaColors.borderSubtle,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: customLeading != null
                      ? Colors.white
                      : accentColor.withValues(alpha: 0.16),
                ),
                child:
                    customLeading ?? Icon(icon, color: accentColor, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.ivory,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.ivory.withValues(alpha: 0.68),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x66000000),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.ivory.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    badgeText!,
                    style: TextStyle(
                      color: AppColors.ivory.withValues(alpha: 0.78),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: accentColor,
                  size: 14,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleGlyphIcon extends StatelessWidget {
  const _GoogleGlyphIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            color: const Color(0xFF4285F4),
            fontSize: size * 0.82,
            fontWeight: FontWeight.w900,
            height: 1,
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
