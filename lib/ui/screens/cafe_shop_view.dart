import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ai/ai_persona.dart';
import '../../core/constants/app_colors.dart';
import '../../core/games/game_catalog.dart';
import '../../core/theme/maqha_design_system.dart';
import '../../data/cafe_shop_catalog.dart';
import '../../data/game_data_center.dart';
import '../../data/player_account.dart';
import '../../rendering/board_frame.dart';
import '../../rendering/board_theme.dart';
import '../../rendering/domino_tile.dart';
import '../../rendering/tile_skin.dart';
import '../widgets/ai_persona_avatar.dart';
import '../widgets/cafe_avatar_frame.dart';
import '../widgets/cafe_prop_widget.dart';

/// Complete 6-category Shop experience for **المقهى** (`Al-Maqha`):
/// 1. Tables & Country Flags (`tables`)
/// 2. Avatar Frames (`frames`)
/// 3. Multi-Game Pieces (`gamePieces` — Domino + future Café games)
/// 4. Café Table Props (`cafeProps`)
/// 5. Smart Boosters & Table Expressions (`boosters`)
/// 6. Council of Sheikhs VIP Membership (`vip`)
class CafeShopView extends ConsumerStatefulWidget {
  const CafeShopView({super.key, required this.isAr});

  final bool isAr;

  @override
  ConsumerState<CafeShopView> createState() => _CafeShopViewState();
}

class _CafeShopViewState extends ConsumerState<CafeShopView> {
  ShopCategory _selectedCategory = ShopCategory.tables;
  String _selectedGameFilter = 'iraqi_domino';

  bool get isAr => widget.isAr;

  bool _isEquipped(PlayerAccount account, ShopItemDefinition item) {
    return switch (item.category) {
      ShopCategory.tables => account.effectiveTableId() == item.id,
      ShopCategory.frames => account.effectiveFrameId() == item.id,
      ShopCategory.gamePieces =>
        item.gameId == 'iraqi_domino' &&
            account.effectiveDominoItemId() == item.id,
      ShopCategory.cafeProps => account.effectiveCafePropId() == item.id,
      ShopCategory.boosters =>
        item.id == 'chat_sheikh_pack' && account.hasLuxuryQuickChat(),
      ShopCategory.vip => false,
    };
  }

  String _formatRemaining(Duration rem) {
    if (rem.inDays >= 1) {
      final d = rem.inDays;
      final h = rem.inHours % 24;
      return isAr ? 'متبقي $dي $hس' : '${d}d ${h}h left';
    }
    final h = rem.inHours.clamp(1, 23);
    return isAr ? 'متبقي $h ساعة' : '${h}h left';
  }

  void _showFeedback(String message, {bool success = true}) {
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

  void _handlePurchase(
    ShopItemDefinition item,
    PurchaseDuration duration,
  ) {
    final res = ref
        .read(gameDataCenterProvider.notifier)
        .purchaseShopItem(itemId: item.id, duration: duration);

    switch (res) {
      case ShopPurchaseStatus.success:
        final actionLabel = item.kind == ShopItemKind.equippable
            ? (duration.isRental
                  ? (isAr
                        ? 'تم تفعيل وتجهيز "${item.title(isAr)}" لمدة ${duration.label(isAr)}!'
                        : 'Rented & equipped "${item.title(isAr)}" (${duration.label(isAr)})!')
                  : (isAr
                        ? 'مبارك! امتلكت "${item.title(isAr)}" بشكل دائم وتم تجهيزه!'
                        : 'Owned "${item.title(isAr)}" permanently & equipped!'))
            : (isAr
                  ? 'تم تفعيل "${item.title(isAr)}" بنجاح!'
                  : 'Activated "${item.title(isAr)}"!');
        _showFeedback(actionLabel, success: true);

      case ShopPurchaseStatus.insufficientDinars:
        _showFeedback(
          isAr
              ? 'رصيدك من دينار المقهى غير كافٍ — شارك في البطولات والإيفنتات لكسب الدنانير!'
              : 'Not enough Al-Maqha Dinars — join Tournaments & Events to earn Dinars!',
          success: false,
        );

      case ShopPurchaseStatus.alreadyOwnedPermanently:
        _showFeedback(
          isAr
              ? 'أنت تمتلك هذا الغرض بشكل دائم بالفعل!'
              : 'You already own this item permanently!',
        );

      case ShopPurchaseStatus.gameNotAvailableYet:
        _showFeedback(
          isAr
              ? 'هذه اللعبة ستُفتح قريباً في المقهى — عندها يتاح شراء أطقمها!'
              : 'This game opens soon in Al-Maqha!',
          success: false,
        );

      case ShopPurchaseStatus.itemNotFound:
        break;
    }
  }

  Future<void> _openPurchaseSheet(
    ShopItemDefinition item,
    PlayerAccount account,
  ) async {
    if (item.requiresFutureGame) {
      _handlePurchase(item, PurchaseDuration.permanent);
      return;
    }

    final isVip = account.isVipActive();
    final avatarPersona =
        AiPersona.all[account.avatarIndex % AiPersona.all.length];

    final chosen = await showModalBottomSheet<PurchaseDuration>(
      context: context,
      backgroundColor: MaqhaColors.cardCharcoal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: SizedBox(
                    height: 92,
                    width: 140,
                    child: Center(
                      child: _ShopItemPreview(
                        item: item,
                        avatarPersona: avatarPersona,
                        large: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  item.title(isAr),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description(isAr),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.ivory.withValues(alpha: 0.76),
                    fontSize: 12.5,
                  ),
                ),
                if (isVip && item.kind != ShopItemKind.vipMembership) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.gold),
                      ),
                      child: Text(
                        isAr
                            ? 'خصم مجلس شيوخ المقهى (15%) مفعّل ✓'
                            : 'Council of Sheikhs 15% VIP Discount Active ✓',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                if (item.kind == ShopItemKind.equippable) ...[
                  for (final dur in PurchaseDuration.values)
                    if (item.priceFor(dur, isVipActive: isVip) != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: _DurationOptionTile(
                          duration: dur,
                          price: item.priceFor(dur, isVipActive: isVip)!,
                          canAfford:
                              account.cafeDinars >=
                              item.priceFor(dur, isVipActive: isVip)!,
                          isAr: isAr,
                          onTap: () => Navigator.of(ctx).pop(dur),
                        ),
                      ),
                ] else ...[
                  _DurationOptionTile(
                    duration: PurchaseDuration.permanent,
                    customLabel: isAr ? 'تفعيل الآن' : 'Activate Now',
                    price: item.priceFor(
                      PurchaseDuration.permanent,
                      isVipActive: isVip,
                    )!,
                    canAfford:
                        account.cafeDinars >=
                        item.priceFor(
                          PurchaseDuration.permanent,
                          isVipActive: isVip,
                        )!,
                    isAr: isAr,
                    onTap: () =>
                        Navigator.of(ctx).pop(PurchaseDuration.permanent),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

    if (chosen != null) {
      _handlePurchase(item, chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(gameDataCenterProvider);
    final isVip = account.isVipActive();
    final has2xXp = account.hasActiveDoubleXp();
    final shields = account.ratingShieldCharges;
    final tickets = account.extraTournamentTickets;
    final avatarPersona =
        AiPersona.all[account.avatarIndex % AiPersona.all.length];

    final filteredItems = CafeShopCatalog.byCategory(
      _selectedCategory,
      gameIdFilter: _selectedCategory == ShopCategory.gamePieces
          ? _selectedGameFilter
          : null,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
      children: [
        // 1. Header + Live دينار المقهى Balance
        Row(
          children: [
            Expanded(
              child: Text(
                isAr ? 'السوق' : 'Shop',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            CafeDinarPill(amount: account.cafeDinars, isAr: isAr),
          ],
        ),

        // Active VIP / Boosters Strip
        if (isVip || has2xXp || shields > 0 || tickets > 0) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (isVip)
                _ActiveBuffChip(
                  icon: Icons.workspace_premium_rounded,
                  label: isAr ? 'VIP -15%' : 'VIP -15%',
                ),
              if (has2xXp)
                _ActiveBuffChip(
                  icon: Icons.bolt_rounded,
                  label: isAr ? '2x XP' : '2x XP',
                ),
              if (shields > 0)
                _ActiveBuffChip(
                  icon: Icons.shield_rounded,
                  label: isAr ? 'درع: $shields' : 'Shield: $shields',
                ),
              if (tickets > 0)
                _ActiveBuffChip(
                  icon: Icons.confirmation_number_rounded,
                  label: isAr ? 'تذاكر: $tickets' : 'Tickets: $tickets',
                ),
            ],
          ),
        ],

        const SizedBox(height: 12),

        // 2. Category Selector Bar (6 Categories)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final cat in ShopCategory.values)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(
                      cat.label(isAr),
                      style: TextStyle(
                        fontWeight: _selectedCategory == cat
                            ? FontWeight.w800
                            : FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                    selected: _selectedCategory == cat,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  ),
                ),
            ],
          ),
        ),

        // Sub-filter per game when inside "أحجار الألعاب"
        if (_selectedCategory == ShopCategory.gamePieces) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final game in GameCatalog.entries)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        game.available
                            ? game.title(isAr)
                            : '${game.title(isAr)} (${isAr ? "قريباً" : "Soon"})',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      selected: _selectedGameFilter == game.id,
                      onSelected: (_) =>
                          setState(() => _selectedGameFilter = game.id),
                    ),
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),

        // 3. Shop Items List / Cards
        for (final item in filteredItems)
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: _ShopItemCard(
              item: item,
              account: account,
              avatarPersona: avatarPersona,
              isVip: isVip,
              equipped: _isEquipped(account, item),
              remainingRental: account.remainingRental(item.id),
              formatRemaining: _formatRemaining,
              isAr: isAr,
              onEquip: () {
                ref.read(gameDataCenterProvider.notifier).equipShopItem(
                  item.id,
                );
                _showFeedback(
                  isAr
                      ? 'تم تجهيز "${item.title(isAr)}"!'
                      : 'Equipped "${item.title(isAr)}"!',
                );
              },
              onBuyOrRent: () => _openPurchaseSheet(item, account),
            ),
          ),
      ],
    );
  }
}

class _ActiveBuffChip extends StatelessWidget {
  const _ActiveBuffChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.gold, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopItemCard extends StatelessWidget {
  const _ShopItemCard({
    required this.item,
    required this.account,
    required this.avatarPersona,
    required this.isVip,
    required this.equipped,
    required this.remainingRental,
    required this.formatRemaining,
    required this.isAr,
    required this.onEquip,
    required this.onBuyOrRent,
  });

  final ShopItemDefinition item;
  final PlayerAccount account;
  final AiPersona avatarPersona;
  final bool isVip;
  final bool equipped;
  final Duration? remainingRental;
  final String Function(Duration) formatRemaining;
  final bool isAr;
  final VoidCallback onEquip;
  final VoidCallback onBuyOrRent;

  @override
  Widget build(BuildContext context) {
    final rarityColor = Color(item.rarity.colorHex);
    final isOwned =
        item.kind == ShopItemKind.equippable && account.isItemOwned(item.id);
    final isPermanent =
        item.kind == ShopItemKind.equippable &&
        account.isItemPermanent(item.id);

    final startPrice3d = item.priceFor(
      PurchaseDuration.days3,
      isVipActive: isVip,
    );
    final permPrice = item.priceFor(
      PurchaseDuration.permanent,
      isVipActive: isVip,
    );

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: equipped
            ? MaqhaColors.cardCharcoalElevated
            : MaqhaColors.cardCharcoal,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: equipped ? AppColors.gold : MaqhaColors.borderSubtle,
          width: equipped ? 1.6 : 1.0,
        ),
        boxShadow: MaqhaShadows.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Live visual preview box
              Container(
                width: 76,
                height: 68,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0x66000000),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: rarityColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Center(
                  child: _ShopItemPreview(
                    item: item,
                    avatarPersona: avatarPersona,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title(isAr),
                            style: const TextStyle(
                              color: AppColors.ivory,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: rarityColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: rarityColor.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Text(
                            item.rarity.label(isAr),
                            style: TextStyle(
                              color: rarityColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description(isAr),
                      style: TextStyle(
                        color: AppColors.ivory.withValues(alpha: 0.72),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: AppColors.gold.withValues(alpha: 0.16)),
          const SizedBox(height: 10),

          // Pricing / Ownership / Action bar
          Row(
            children: [
              Expanded(
                child: _buildPriceOrOwnershipSummary(
                  isOwned: isOwned,
                  isPermanent: isPermanent,
                  startPrice3d: startPrice3d,
                  permPrice: permPrice,
                ),
              ),
              const SizedBox(width: 8),
              if (item.requiresFutureGame)
                _ActionChipButton(
                  label: isAr ? 'قريباً' : 'Soon',
                  filled: false,
                  onTap: onBuyOrRent,
                )
              else if (isOwned) ...[
                if (!isPermanent) ...[
                  _ActionChipButton(
                    label: isAr ? 'تمديد / دائم' : 'Upgrade',
                    filled: false,
                    onTap: onBuyOrRent,
                  ),
                  const SizedBox(width: 6),
                ],
                if (item.id == 'chat_sheikh_pack')
                  _ActionChipButton(
                    label: isAr ? 'مفعّل ✓' : 'Active ✓',
                    filled: true,
                    onTap: null,
                  )
                else if (equipped)
                  _ActionChipButton(
                    label: isAr ? 'مجهّز ✓' : 'Equipped ✓',
                    filled: true,
                    onTap: null,
                  )
                else
                  _ActionChipButton(
                    label: isAr ? 'تجهيز' : 'Equip',
                    filled: true,
                    onTap: onEquip,
                  ),
              ] else
                _ActionChipButton(
                  label: item.kind == ShopItemKind.equippable
                      ? (isAr ? 'استئجار / شراء' : 'Rent / Buy')
                      : (isAr ? 'تفعيل' : 'Activate'),
                  filled: true,
                  onTap: onBuyOrRent,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceOrOwnershipSummary({
    required bool isOwned,
    required bool isPermanent,
    required int? startPrice3d,
    required int? permPrice,
  }) {
    if (isPermanent) {
      return Text(
        item.isDefaultFree
            ? (isAr ? 'متاح مجاناً للجميع' : 'Starter Default')
            : (isAr ? 'مملوك للأبد ✓' : 'Owned Permanently ✓'),
        style: const TextStyle(
          color: Color(0xFF81C784),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    if (isOwned && remainingRental != null) {
      return Text(
        formatRemaining(remainingRental!),
        style: const TextStyle(
          color: Color(0xFFFFD54F),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    if (item.kind == ShopItemKind.equippable &&
        startPrice3d != null &&
        permPrice != null) {
      return Wrap(
        spacing: 8,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            isAr ? '3 أيام: $startPrice3d د' : '3d: $startPrice3d D',
            style: TextStyle(
              color: AppColors.ivory.withValues(alpha: 0.85),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '•',
            style: TextStyle(color: AppColors.gold.withValues(alpha: 0.5)),
          ),
          Text(
            isAr ? 'دائم: $permPrice د' : 'Perm: $permPrice D',
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
    }

    return Text(
      isAr
          ? 'السعر: ${permPrice ?? 0} دينار المقهى'
          : 'Price: ${permPrice ?? 0} Dinars',
      style: const TextStyle(
        color: AppColors.gold,
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: filled && active
              ? const LinearGradient(
                  colors: [Color(0xFFE5C158), Color(0xFFB8860B)],
                )
              : null,
          color: !filled
              ? const Color(0x55000000)
              : (!active ? AppColors.gold.withValues(alpha: 0.22) : null),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: active ? 0.85 : 0.45),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled && active ? const Color(0xFF1E1006) : AppColors.gold,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _DurationOptionTile extends StatelessWidget {
  const _DurationOptionTile({
    required this.duration,
    required this.price,
    required this.canAfford,
    required this.isAr,
    required this.onTap,
    this.customLabel,
  });

  final PurchaseDuration duration;
  final int price;
  final bool canAfford;
  final bool isAr;
  final VoidCallback onTap;
  final String? customLabel;

  @override
  Widget build(BuildContext context) {
    final isPerm = duration == PurchaseDuration.permanent && customLabel == null;
    final title =
        customLabel ??
        switch (duration) {
          PurchaseDuration.days3 => isAr ? 'استئجار 3 أيام' : 'Rent 3 Days',
          PurchaseDuration.days7 => isAr ? 'استئجار 7 أيام' : 'Rent 7 Days',
          PurchaseDuration.permanent => isAr ? 'تملّك دائم' : 'Own Permanently',
        };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isPerm
              ? AppColors.gold.withValues(alpha: 0.14)
              : MaqhaColors.bgDeepTeal.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPerm ? AppColors.gold : MaqhaColors.borderSubtle,
            width: isPerm ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            if (isPerm) ...[
              const Icon(
                Icons.workspace_premium_rounded,
                color: AppColors.gold,
                size: 18,
              ),
              const SizedBox(width: 7),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isPerm ? AppColors.gold : AppColors.ivory,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Opacity(
              opacity: canAfford ? 1.0 : 0.55,
              child: CafeDinarPill(
                amount: price,
                isAr: isAr,
                compact: true,
                showCurrencyWord: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopItemPreview extends StatelessWidget {
  const _ShopItemPreview({
    required this.item,
    required this.avatarPersona,
    this.large = false,
  });

  final ShopItemDefinition item;
  final AiPersona avatarPersona;
  final bool large;

  @override
  Widget build(BuildContext context) {
    switch (item.category) {
      case ShopCategory.tables:
        return SizedBox(
          width: large ? 124 : 64,
          height: large ? 82 : 52,
          child: BoardFrame(
            theme: BoardTheme.byId(item.id),
            frameWidth: large ? 7 : 4,
            child: const SizedBox.expand(),
          ),
        );

      case ShopCategory.frames:
        final sz = large ? 58.0 : 40.0;
        return CafeAvatarFrame(
          frameId: item.id,
          size: sz,
          child: AiPersonaAvatar(persona: avatarPersona, size: sz),
        );

      case ShopCategory.gamePieces:
        if (item.gameId == 'iraqi_domino') {
          return DominoTile(
            top: 6,
            bottom: 6,
            width: large ? 34 : 24,
            skin: TileSkin.byId(item.effectiveAssetId),
          );
        }
        return Icon(
          item.gameId == 'backgammon'
              ? Icons.grid_view_rounded
              : Icons.style_rounded,
          color: AppColors.gold,
          size: large ? 46 : 32,
        );

      case ShopCategory.cafeProps:
        return CafePropWidget(propId: item.id, size: large ? 66 : 46);

      case ShopCategory.boosters:
        final icon = switch (item.id) {
          'boost_xp_2x_24h' || 'boost_xp_2x_3d' => Icons.bolt_rounded,
          'boost_daily_cap_1000' => Icons.trending_up_rounded,
          'boost_rating_shield_3' => Icons.shield_rounded,
          'boost_tournament_ticket' => Icons.confirmation_number_rounded,
          _ => Icons.chat_bubble_rounded,
        };
        return Icon(icon, color: AppColors.gold, size: large ? 48 : 34);

      case ShopCategory.vip:
        return Icon(
          Icons.workspace_premium_rounded,
          color: AppColors.gold,
          size: large ? 54 : 38,
        );
    }
  }
}
