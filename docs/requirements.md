# Requirements — Iraqi Domino
Status: DRAFT v0.1

## Product
Premium Iraqi Domino game in Flutter: realistic wooden table, ivory tiles,
smooth animations, Arabic-first RTL UI (Modern Standard Arabic), English LTR.

## Platforms
- Targets: Android and iOS (mobile only). No desktop target for now.
- Orientation: portrait only.
- Development machine: Windows; testing on Android emulator or a physical phone.
- Architecture must still allow other platforms later.

## Functional Requirements
### Modes & Multi-Game Hub
- App shell: modern 5-tab bottom navigation bar:
  1. Home (quick play + leaderboard preview + settings access)
  2. Games (extensible game catalog hosting Iraqi Domino now and additional
     traditional games in the future)
  3. Challenges & Tournaments
  4. Shop (tile skins live now; virtual-currency table themes/avatars later)
  5. Profile & Settings
- Iraqi Domino modes:
  - 2 players: Play vs AI, 3 Local Multiplayer channels (Offline Wi-Fi / Hotspot / Wi-Fi Direct, Bluetooth, Local Wi-Fi), and Online.
  - 4 players (2 teams): Play vs AI, 3 Local Multiplayer channels with seat/partner selection & AI bot fill, and Online.
  - Azneef: future, rules to be supplied by owner.
- Unified Data & Account Hub:
  - Single central `GameDataCenter` managing player identity across Guest mode ("اللعب كضيف") and Authenticated accounts (Phase 7 Sign-In), public peer profile, and cumulative player statistics across all offline, local, and online modes.

### Rules
- As defined in game_rules.md (single source of truth).
- Configurable via GameRulesConfig (target score at minimum).

### AI
- Legal-move detection, board awareness, played-tile tracking,
  team play (4 players).
- Levels: Easy, Medium, Hard, Expert. Deterministic, testable rules-based.

### Online (Phase 7)
- Accounts, guest mode, profiles, friends, invitations, private rooms,
  public matchmaking, room codes, real-time sync, reconnection,
  server-authoritative validation, anti-cheat, connection status.

### Future
- Virtual economy, skins, shop, tournaments, leaderboards.
- Real money / prizes: NOT implemented without legal, platform, payment
  and age-restriction review. Virtual currency kept separate.

## Non-Functional Requirements
- Game engine in pure Dart, independent of UI, fully unit-testable.
- Separation: rules, engine, AI, rendering, UI, networking.
- No backend or subscription cost in early phases.
- No package added without a stated reason.
- Tiles readable at all screen sizes; no flat rectangles as final art.
- Documentation updated whenever architecture or requirements change.

## Working Process
- One phase at a time, owner approval before each next phase.
- Full code per file with exact paths; build/test commands each step.
