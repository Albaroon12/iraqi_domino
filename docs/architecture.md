# Architecture — Iraqi Domino
Status: DRAFT v0.1

## Layers
1. engine/ (pure Dart, no Flutter imports)
   - tile, deck, dealing (2-2-3), board, move validation, turn manager,
     round manager, scoring, block/tie handling, GameRulesConfig.
2. ai/ (pure Dart): strategies per difficulty; reads engine state only.
3. state/ (Riverpod): connects engine to UI; one controller per match.
4. ui/ (Flutter): screens, widgets, themes, localization (ar RTL, en LTR).
5. rendering/: tile and table painting (widgets + CustomPainter first;
   evaluate Flame in Phase 3 only if animation needs justify it).
6. data/: local persistence (settings, stats).
7. network/ (Phase 7): WebSocket client; server reuses engine for
   authoritative validation.

## Key Decisions
- Riverpod: simple, testable, less boilerplate than Bloc here.
- Engine is immutable-state + pure functions: easy tests, replay,
  and reuse on a future Dart server.
- Rules live in GameRulesConfig, so Azneef can be added as a variant
  (spinner support) without rewriting core logic.
- Backend decision deferred to Phase 7 (Firebase vs Dart WebSocket server).
- Settings live in a Riverpod NotifierProvider (immutable SettingsState),
  persisted with shared_preferences (small key/value data only). Storage is
  injected via sharedPreferencesProvider so tests use a fake one. Invalid
  saved values fall back to defaults. The app root watches the language from
  it, so switching language updates direction (RTL/LTR) instantly.
- Screens receive plain data (names, scores, counts) and know nothing about
  the engine, so the game screen layout is independent of the visual style.
  A future redesign changes widgets/painters, not the layout contract.
- engine/ holds pure-Dart game logic: DominoPiece, Dealer (2-2-3 deal,
  invalid-deal prevention, 2p alternate-draw opening double), Board (line of
  play, end matching, orientation), RoundState (turns, legal moves,
  pass/draw, playHistory, passHistory, drawHistory, domino/blocked/burned),
  RoundResult, GameRulesConfig (targetScore, aiDifficulty), SeatOccupant
  (human vs bot seat state + endgame hot-join cutoff), and MatchState
  (multi-round scoring, round history, target-score match end).
- ai/ holds pure-Dart AI strategies (`AiDifficulty`, `DominoAi`,
  `UserPlayProfile`, and the 10 named `AiPersona` characters) supporting 4
  deterministic difficulty levels (`easy`, `medium`, `hard`, `expert`) with
  Bayesian unseen-tile hand prediction, pass & 2p boneyard draw deduction,
  partner move-signal analysis, 2-ply lookahead resilience, and persistent
  learning from the human player's moves.
- state/ holds MatchController (`matchControllerProvider`, Riverpod
  `NotifierProvider.autoDispose.family`) which owns MatchState, per-seat
  `SeatOccupant`s (with distinct `AiPersona` bots, `replaceHumanWithBot`, and
  `tryHotJoinHuman`), turn timers, and AI/draw/pass scheduling, emitting
  immutable MatchViewState snapshots to GameScreen.
- core/games/game_catalog.dart provides a data-driven GameCatalog registry so
  additional games can be plugged in under `lib/games/<game_id>/` without
  modifying the 5-tab AppShellScreen (`lib/ui/screens/app_shell_screen.dart`).
- rendering/ holds SerpentineLayout (pure Dart, fixed tile width from area),
  BoardFrame, BoardView (with smooth pan + fallback scale for single-arm
  overflow), DominoTile/DominoBack painters, and tile/table skins.

## Proposed Folder Structure
lib/
  engine/  ai/  state/  ui/  rendering/  data/  l10n/  core/
test/
  engine/  ai/
docs/

## Technical Risks
- Realistic tile art quality.
- UI built (Phase 3) before the real engine (Phase 4): UI must depend on
  an interface so the engine can be swapped in without rewrites.
- Legal/platform review for any real-money feature.
- Rule ambiguity: tracked as [ASSUMED] items in game_rules.md.
- Each match carries its own GameRulesConfig (target score, later more
  options). A running match never reads the global settings. Online, the
  server stores the config in the room and uses the same object.