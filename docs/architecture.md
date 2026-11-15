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
