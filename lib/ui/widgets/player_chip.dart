import 'package:material_ui/material_ui.dart';

import '../../ai/ai_persona.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/maqha_design_system.dart';
import 'ai_persona_avatar.dart';
import 'cafe_avatar_frame.dart';

/// Compact player marker: a small avatar with a tile-count badge and the
/// name below it. The avatar glows gold when it is the player's turn.
///
/// When [aiPersona] is supplied, renders the persona's custom portrait and a
/// compact `AI` tag so players immediately recognize bot-controlled seats.
class PlayerChip extends StatelessWidget {
  const PlayerChip({
    super.key,
    required this.name,
    required this.tileCount,
    required this.isTurn,
    this.aiPersona,
    this.humanPersona,
    this.avatarFrameId = 'frame_none',
    this.showBotBadge = true,
    this.icon = Icons.person_rounded,
    this.secondsLeft,
    this.secondsTotal = 30,
    this.compact = false,
  });

  final String name;
  final int tileCount;
  final bool isTurn;
  final AiPersona? aiPersona;
  final AiPersona? humanPersona;
  final String avatarFrameId;
  final bool showBotBadge;
  final IconData icon;
  final int? secondsLeft;
  final int secondsTotal;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final left = secondsLeft;
    final urgent = left != null && left <= 10;
    const urgentColor = Color(0xFFE5533D);
    final avatarSize = compact ? 28.0 : 34.0;
    final badgeSize = compact ? 15.0 : 17.0;
    final persona = aiPersona ?? humanPersona;
    final isBot = aiPersona != null && showBotBadge;
    final hasCustomFrame = avatarFrameId != 'frame_none' && !urgent;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (hasCustomFrame)
              CafeAvatarFrame(
                frameId: avatarFrameId,
                size: avatarSize - 2,
                child: persona != null
                    ? AiPersonaAvatar(persona: persona, size: avatarSize - 2)
                    : ColoredBox(
                        color: MaqhaColors.avatarJade,
                        child: Icon(
                          icon,
                          size: compact ? 16 : 20,
                          color: AppColors.ivory,
                        ),
                      ),
              )
            else
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: avatarSize,
                height: avatarSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MaqhaColors.avatarJade,
                  border: Border.all(
                    color: isTurn
                        ? AppColors.gold
                        : AppColors.gold.withValues(alpha: 0.35),
                    width: isTurn ? 2.5 : 1.5,
                  ),
                  boxShadow: isTurn
                      ? [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.6),
                            blurRadius: 12,
                          ),
                        ]
                      : const [],
                ),
                child: urgent
                    ? Text(
                        '$left',
                        style: TextStyle(
                          color: urgentColor,
                          fontSize: compact ? 13 : 15,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      )
                    : (persona != null
                          ? AiPersonaAvatar(
                              persona: persona,
                              size: avatarSize - 4,
                            )
                          : Icon(
                              icon,
                              size: compact ? 16 : 20,
                              color: AppColors.ivory,
                            )),
              ),
            // Turn timer ring.
            if (left != null)
              Positioned(
                left: -5,
                top: -5,
                right: -5,
                bottom: -5,
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: left / secondsTotal),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.linear,
                    builder: (context, value, _) => CircularProgressIndicator(
                      value: value,
                      strokeWidth: 3,
                      color: urgent ? urgentColor : AppColors.gold,
                      backgroundColor: const Color(0x33FFFFFF),
                    ),
                  ),
                ),
              ),
            // AI bot badge on top-left when controlled by an AiPersona.
            if (isBot)
              Positioned(
                left: compact ? -6 : -7,
                top: -3,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 3 : 3.5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2634),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.7),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    'AI',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: compact ? 7 : 7.5,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                ),
              ),
            // Tile count badge.
            Positioned(
              right: compact ? -6 : -7,
              bottom: compact ? -2 : -3,
              child: Container(
                constraints: BoxConstraints(minWidth: badgeSize),
                height: badgeSize,
                padding: EdgeInsets.symmetric(horizontal: compact ? 3 : 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '$tileCount',
                  style: TextStyle(
                    color: AppColors.walnut,
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 3 : 4),
        Container(
          constraints: BoxConstraints(maxWidth: compact ? 52 : 76),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 5 : 6,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: MaqhaColors.cardCharcoal,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: MaqhaColors.borderSubtle, width: 0.8),
          ),
          // Long names shrink instead of overflowing.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              name,
              style: TextStyle(
                color: AppColors.ivory,
                fontSize: compact ? 10.5 : 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
