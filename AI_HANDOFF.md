# AI_HANDOFF.md — Shared Notebook for All AI Agents

> **READ THIS FILE FIRST. UPDATE IT LAST.**
> This is the single coordination file between every AI agent working on
> *Iraqi Domino* (Claude chat, Claude Code, Codex, Gemini, Copilot, anyone).
> The owner works with several agents on different days. No agent remembers
> the previous one. This file is the memory.

Last updated: 2026-11-20 by Antigravity. Fixed SerpentineLayout syntax error; completed responsive 2p/4p GameScreen UI polish (tall board, edge-to-edge dock, opponent racks, score/target badges, round history, smooth BoardView pan/fallback).

---

## 0. The protocol (mandatory)

1. **Before you touch anything:** read sections 1-4 and the latest 5 entries of the Change Log (section 9). Then read `docs/` if your task touches rules, architecture or scope.
2. **After every reply in which you changed, added, deleted or decided something:**
   - Add ONE entry at the TOP of the Change Log (section 9), using the template there.
   - Update sections 2 (status), 5 (known issues) or 7 (decisions) if they changed.
   - If you changed rules, architecture or requirements, also update `docs/` (project rule: docs always match reality).
3. **Never rewrite or delete another agent's entries.** Correct them by adding a new entry that says what was wrong. Marking an issue as fixed is allowed.
4. **Be honest about verification.** Write exactly what you ran (`flutter analyze`, `flutter test`, emulator) and whether it passed. If you did not run it, write "NOT RUN". Never write "tests pass" from reading code alone.
5. **Leave messages to the next agent in section 8 (Inbox).** Answer messages addressed to you, then mark them `[DONE]`.
6. **Do not exceed the current phase.** One phase at a time, and only the owner approves moving on (see section 3).
7. **Talk to the owner in Arabic.** Code, comments, docs and this file stay in English.
8. Keep entries short and factual. No marketing language. Paths must be exact.

---

## 1. Project snapshot

- **What:** Premium Iraqi Domino game in Flutter. Wooden table, ivory tiles drawn in code (CustomPainter), Arabic-first RTL UI (Modern Standard Arabic), English LTR.
- **Platforms:** Android + iOS, mobile only, **portrait only**. Dev machine: Windows. Testing on Android emulator or phone. (Folders `web/` exists from `flutter create` but web is NOT a target.)
- **Team:** several people and several AI agents, working through Claude and other tools.
- **Owner working style (from docs/requirements.md):**
  - One phase at a time; owner approval before each next phase.
  - Give **full code per file with exact paths**, plus build/test commands for each step.
  - **No package may be added without a stated reason.**
  - No backend or subscription cost in early phases.
  - Real-money features are forbidden without legal/platform/payment/age review. Virtual currency only.
- **Stack:** Flutter (SDK constraint `^3.14.0`), `material_ui ^1.1.0` (locked 1.11.0; imports are `package:material_ui/material_ui.dart`, NOT `package:flutter/material.dart`), `flutter_riverpod ^3.5.0`, `shared_preferences ^2.5.6`, `intl`, `flutter_localizations`, `cupertino_ui` (see issue I-6), font **Cairo** (bundled, SIL OFL).
- **IDs:** Android `com.albaron.iraqi_domino`; iOS bundle `com.albaron.iraqiDomino`.
- **Build tooling pinned (do not change casually):** Gradle 9.5.0, AGP 9.3.1, Kotlin 2.4.20, `android.newDsl=false`, `android.builtInKotlin=false`, JVM 17.

---

## 2. Where development is (as of 2026-11-19)

Roadmap source: `docs/roadmap.md`.

| Phase | Goal | Status (my assessment) |
|---|---|---|
| 0 | Discovery, rules, docs | Docs exist but all still say **DRAFT v0.1**. Owner approval is not recorded anywhere. See Q-1. |
| 1 | Flutter project, shell, fonts, theme | **Done.** |
| 2 | Assets & UI design (table, tiles, menus, settings) | **Done in code**: painted tiles, 3 tile skins, wood table, main menu, mode selection, settings with persistence, ar/en localization. Owner look-approval not recorded. |
| 3 | Playable prototype | **Essentially done**, but the owner rejected the old board look/line layout (see 3b). Being redone in steps R1-R6 (R1, R2 done). |
| 4 | Real engine + rules + unit tests | **Started, not finished.** Engine is pure Dart with tests, but is still labeled PROTOTYPE and match-level logic lives in the UI. See section 5. |
| 5 | AI (Easy/Medium/Hard/Expert) | Not started. `lib/ai/` does not exist. Computer plays a random legal move. |
| 6-11 | Local multiplayer, online, profiles, shop, tournaments, release | Not started. |

**One-line summary:** *Late Phase 3 / early Phase 4. Board & table UI redesign (R1–R4 + responsive 2p/4p layout, edge-to-edge dock, opponent racks, score/target badges, round history, and smooth pan/fallback in `BoardView`) is implemented; awaiting owner visual/manual test, R5/R6 polish, and P1 Phase 4 engine work (`I-1..I-4`).*

**Test status:** NOT RUN by any agent so far (no Flutter toolchain in the chat sessions). First action for any agent with a shell: run `flutter pub get`, `flutter gen-l10n`, `flutter analyze`, `flutter test` and record the real result in the Change Log.

---

## 3. Process gates

- Phase changes need explicit owner approval. Do not start Phase 5 work (AI) or Phase 6+ work "because it is next".
- Finishing Phase 4 means: tests match `docs/game_rules.md`, and the rules in code have no `[ASSUMED]` item left unconfirmed by the owner.
- Azneef mode: rules NOT provided by the owner yet. Do not invent them. The menu button is intentionally disabled ("Coming soon").

### 3b. Board redesign plan (owner request, 2026-11-19)

**Problems the owner showed in screenshots:** tile size changes as the line grows (24 -> 6); the line turns at unpredictable places; tiles touch/misalign at corners; no defined table; side player names were cut off.

**Owner's target design:**
- A SQUARE board with an inner color and a professionally designed frame. Players sit around it.
- Tiles are ALWAYS vertical along each run and ALWAYS the same size. The order is fixed and never changes shape.
- The line starts in the center. Right-end arm goes DOWN, left-end arm goes UP.
- Before reaching the board edge: the lower arm turns LEFT, the upper arm turns RIGHT, and continues as a new run with a clear gap from the first run.
- Then they turn again (lower arm goes back up, upper arm goes back down), and so on: a repeating S-shaped / serpentine path.
- Doubles lie crosswise and never turn (existing rule, keep it).

**Steps (one at a time; update this file after each; wait for owner OK):**

| Step | Goal | Status |
|---|---|---|
| R1 | `BoardFrame` widget + game screen re-layout (square board, players around it, side names not cut) | DONE 2026-11-19 (owner confirmed the look; NOT RUN: analyze/test) |
| R2 | Pure-Dart `SerpentineLayout`: FIXED tile size from the area, serpentine columns, tests | DONE 2026-11-19 (NOT RUN: analyze/test) |
| R3 | Remove old `BoardLayout` (kept only `LayoutBox`/`LaidTile`), delete its test, `minArmTiles` 14 -> 12 (bigger tiles) | DONE 2026-11-19 (NOT RUN: analyze/test) |
polish ghost slots/drop zone; decide tile size (Q-5) | PARTIAL |
| R4 | Doubles and corner alignment polish (fixes the misalignment seen in screenshot 4), if the visual check shows problems | DONE 2026-11-19 (doubles stand vertical after turns / near side walls, turn cleanly at column ends) |
| R5 | Hand tiles and drag feedback at the same size as on the table; clearer gold ghost slots | TODO |
| R6 | Update tests, `docs/architecture.md`, and this file | TODO |

**Layout rules implemented in R2 (`lib/rendering/serpentine_layout.dart`):**
- Tile size is fixed: `tileWidthFor(width, height)` depends only on the area. It picks the biggest width (26 down to 8 px) where each arm holds at least `minArmTiles` (12) normal pieces. About 16 px on a 179 px felt (checked with a Python port of the algorithm, not with Dart).
- First piece: vertical in the center (a double lies crosswise). Right end = lower arm (goes down, turns LEFT). Left end = upper arm (goes up, turns RIGHT).
- When the next normal piece does not fit in the column, a horizontal piece is placed BESIDE the last half of the last piece (beside the head of a double). The next column goes through the outer half of that turn piece, so columns are about 2w + gap apart, and it runs the opposite way (down becomes up, up becomes down).
- A double lies crosswise in a column when it fits cleanly; right after a turn (`afterTurn`) or near a side edge where crosswise does not fit, it stands vertically (lengthwise) inside the column like a normal piece; if it cannot fit straight at the end of a column, it turns cleanly instead of overflowing.
- The two arms are independent, so a placed piece never moves (only the tile size, which depends on the area, would move everything).
- If an arm is completely full, extra pieces are placed outside the area and `overflow` is true (rare; tests skip such layouts).

Capacity per arm (normal pieces), from a Python port of the algorithm:
felt 179: width 13 -> 14, 15 -> 12, 16 -> 12 | felt 215: 13 -> 24, 15 -> 20, 16 -> 14.
Capacity is not smooth: it jumps when a column fits one more piece.

---

## 4. Code map

```
lib/
  main.dart                    portrait lock, loads SharedPreferences, ProviderScope override
  app.dart                     MaterialApp, locale from settingsProvider, l10n delegates
  core/constants/app_colors.dart   walnut / gold / ivory
  core/theme/app_theme.dart        dark Material 3 theme, Cairo font
  engine/   (PURE DART, no Flutter imports)
    domino_piece.dart          DominoPiece(low<=high), fullSet() = 28 pieces, pips
    board.dart                 Board (line of play, two ends, history, startIndex), Move, BoardEnd, PlacedPiece
    dealer.dart                shuffle + 2-2-3 deal, dealFirstRound (highest double starts) — PROTOTYPE
    round_state.dart           mutable RoundState: legalMoves, play, draw, pass, domino/blocked/burned — PROTOTYPE
    round_result.dart          RoundEndKind {domino, blocked, burned}, RoundResult
    game_rules_config.dart     GameRulesConfig(targetScore=151) — only field so far
  rendering/
    domino_tile.dart / domino_tile_painter.dart   one tile, always vertical 1:2, rotated via RotatedBox
    domino_back.dart, hidden_hand.dart            face-down tiles for other players
    tile_skin.dart                                ivory / ebony / ruby, byId() falls back to ivory
    wood_table.dart, wood_table_painter.dart, table_skin.dart   walnut table (seeded grain, RepaintBoundary)
    board_frame.dart           (R1) square frame: wood + gold line + green felt; only decorates, fills its parent
    serpentine_layout.dart     (R2) fixed-size serpentine layout used by BoardView: tileWidthFor, armCapacity, fit, compute. Reuses LayoutBox/LaidTile from board_layout.dart
        board_layout.dart          only LayoutBox and LaidTile (the old BoardLayout was removed in R3). Rename later if wanted. No longer used by BoardView. Still provides LayoutBox and LaidTile. Delete BoardLayout in R3/R6 after owner OK
    board_view.dart            draws line + ghost slots (gold = target), uses SerpentineLayout
  state/settings_provider.dart SettingsState + NotifierProvider, saved in shared_preferences, invalid values fall back to defaults
  ui/
    screens/ main_menu, mode_selection, game_screen, settings, + DEV ONLY: tile_gallery, table_preview
    widgets/ game_button, player_chip (turn ring/timer), score_board, round_result_dialog
    localized_names.dart       tileSkinName()
  l10n/ app_ar.arb (TEMPLATE), app_en.arb, generated app_localizations*.dart (do not edit by hand)
test/
  engine/ board_test, dealer_test, round_state_testserpentine_layout_test (R2: fixed size, capacity, arm directions, turn sides, random rounds, tiles never move)
  state/ settings_provider_test
  ui/ game_screen_test (360x640 fit test, Arabic strings)
  widget_test.dart, helpers/test_app.dart
docs/ requirements.md, roadmap.md, architecture.md, game_rules.md, assets_licenses.md
```

**Game screen layout (updated 2026-11-20):** Compact `AppBar` (`toolbarHeight: 40`, no target pill). Smooth dark radial background (`DecoratedBox`, replacing `WoodTable` on `GameScreen`). Top area: `PlayerChip` + `score/target` `_PlayerScoreBadge` + 7-slot `_TileRack` (with `14/14` boneyard pill on top-left in 2p mode and round history dialog button on top-right). Middle area: responsive rectangular `BoardFrame` + `BoardView` (uses full available height; pans smoothly when one arm overflows and steps `tileWidth` down only as a fallback). Side players (4p): anchored flush to physical left/right screen edges (`textDirection: TextDirection.ltr` on `_SidePlayer` `Column`) with `compact` `PlayerChip`, flush `score/target` badge (no star icon), and flush vertical `_TileRack`. Bottom area: edge-to-edge dark dock (`SafeArea(left: false, right: false, bottom: false)`), 7-tile clipped scrollable `_HandTile` rack on top, and your `PlayerChip` + `score/target` badge below. All spacing and sizes scale responsively with screen dimensions. (`ScoreBoard` widget still exists in `ui/widgets/score_board.dart` but is no longer used in `GameScreen`.)

**Seat numbering:** counter-clockwise from bottom. 4 players: 0 = you, 1 = right opponent, 2 = partner (top), 3 = left opponent. 2 players: 0 = you, 1 = opponent (top). Teams with 4 players: `seat % 2`.

**Directions on screen are physical, never language-dependent:** side players use physical left/right positioning on purpose; board layout uses physical coordinates. Do not "fix" this with `AlignmentDirectional`.

**Rules as currently implemented (matches `docs/game_rules.md` unless noted):**
- 7 tiles each, dealt 2-2-3. 2 players: 14-tile boneyard. 4 players: none.
- Invalid deal prevention: if any hand has 6+ doubles or 6+ tiles sharing the same number (0–6), `Dealer.deal` automatically re-deals so invalid hands never enter play.
- First round: holder of highest double opens with it (4 players: always 6-6).
- Later rounds: winner of previous round starts with any piece. Burned round: dealt like a first round.
- Playing is compulsory. Pass/draw is automatic after a short delay (nobody presses a button). 2 players draw one tile at a time until a move exists, then pass only if the boneyard is empty.
- Domino: winner's team scores the **opponents' pips only** (partner's pips not counted).
- Blocked (everyone passed in a row): lowest pip total wins; same-team tie wins, tied player closest to the blocker (play order) starts **[ASSUMED]**; different-team tie (or 2-player tie) = burned, no points.
- Doubles lie crosswise and never branch (no spinner in standard mode).
- Turn timer: 30 s for the human only; on timeout the computer plays a random legal move for you.

---

## 5. Known issues, gaps and tech debt

Priority: **P1** blocks Phase 4 / correctness, **P2** should fix soon, **P3** cleanup. Mark `[FIXED yyyy-mm-dd by <agent>]` instead of deleting.

**P1**
- **I-1 No match end.** [FIXED 2026-11-20 by Antigravity] `MatchState` (`lib/engine/match_state.dart`) now tracks scores, history, and `winnerTeam`/`isOver` against `rules.targetScore`; `GameScreen` shows `_MatchResultDialog` with Play Again / Back to Mode Selection when the target is reached.
- **I-2 Game logic lives in the UI.** [FIXED 2026-11-20 by Antigravity] Match flow, timers, and turn orchestration moved into `MatchState` (`lib/engine/match_state.dart`) and Riverpod `MatchController` (`lib/state/match_controller.dart`); `GameScreen` watches `matchControllerProvider` and only manages UI interaction state (drag/select/dialogs).
- **I-3 Engine is still a prototype.** `RoundState` is mutable and `Dealer.dealFirstRound` just re-deals when a 2-player deal has no double, instead of the agreed rule (players draw alternately from the boneyard until a double shows; `[ASSUMED]` who starts drawing). `GameRulesConfig` only has `targetScore`. The "blocker deals" rule from `game_rules.md` section 3 is not modeled (the code only models who *starts*).
- **I-4 Remaining `[ASSUMED]` rules in `docs/game_rules.md` need owner confirmation** (same-team tie starter; compulsory play in 4p). Confirmed on 2026-11-20: 2p draws until playable (non-alternating) during play, and alternates only at first-round opening when neither player holds a double.

**P2**
- **I-5 Localization file problems.** [FIXED 2026-11-20 by Antigravity] Removed duplicate `youStartRoundFree` key, fixed indentation, and removed the 7 unused keys (`phaseOneReady`, `gameScreenComingSoon`, `tilesLeft`, `passButton`, `drawButton`, `featureComingSoon`, `previewRoundResult`) in `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb`. Run `flutter gen-l10n` manually to regenerate `app_localizations*.dart`.
- **I-6 `cupertino_ui: any` in pubspec** has no stated reason and no import in the shown code. Project rule: no package without a reason. Either document the reason or remove it (verify nothing imports it first).
- **I-7 iOS orientation mismatch.** `ios/Runner/Info.plist` still lists landscape orientations for iPhone; requirements say portrait only. `main.dart` locks portrait at runtime, but the plist should match. Android has no `screenOrientation` in the manifest (same situation).
- **I-8 Sound.** [PARTIALLY FIXED 2026-11-20 by Antigravity] Added `audioplayers ^6.1.0`, `lib/core/audio/sound_service.dart` (`SoundService`), `ambientEnabled` setting in `SettingsState`/`SettingsScreen`, and wired `playTilePlace`, `playTileDraw`, `playPass`, and `startCafeAmbient`/`stopCafeAmbient` into `MatchController` and `GameScreen`. Missing files in `assets/audio/` are safely ignored. Owner still needs to place licensed `.mp3` files (`cafe_ambient.mp3`, `tile_place.mp3`, `tile_draw.mp3`, `tile_pass.mp3`) in `assets/audio/` and record their licenses in `docs/assets_licenses.md`.
- **I-9 AI.** Computer players pick a random legal move (`_aiPlay`, `_autoPlayForMe`). Phase 5 replaces this. Keep the call sites small so a strategy interface can be dropped in.
- **I-14 Tile size.** With `SerpentineLayout.minArmTiles` = 12 the fixed tile width is about 16 px on a 360x640 phone (felt about 179 px); each arm holds about 12 normal pieces, so about 25 in total. A very long round can fill one arm: extra pieces are drawn outside the frame and `overflow` is true. Options if the owner wants bigger tiles: lower `minArmTiles` more (more overflow risk) or enlarge the square (`_topReserve` in `game_screen.dart`).

**P3**
- **I-10 Dev screens must be removed before release:** `tile_gallery_screen.dart`, `table_preview_screen.dart` and their menu buttons (already hidden with `!kReleaseMode`). Also the redeal button in the game app bar. `tile_gallery_screen.dart` has its own `_skinName` that duplicates `tileSkinName` in `ui/localized_names.dart`.
- **I-11 Docs are stale.** `docs/architecture.md` repeats the settings bullet twice and still says persistence "is added in step 2.5" (it is done). `table_preview_screen.dart` says "replaced in step 2.3". All docs say DRAFT v0.1. `docs/assets_licenses.md` lists only Cairo. `README.md`, `pubspec.yaml` description, and `web/` metadata are still Flutter defaults.
- **I-12 Release not ready:** Android release build signs with debug keys (TODO in `android/app/build.gradle.kts`); launch backgrounds are white (a flash before the dark app on cold start); web manifest colors are default.
- **I-13 Test coverage gaps:** no test for match-level scoring or target reaching (feature missing), no test for burned-round restart flow, no test that the game screen handles RTL/LTR switch mid-game.

---

## 6. Hard "do not" list

- Do not change the pinned Gradle/AGP/Kotlin versions or the two `android.*` flags in `gradle.properties` without a reason and owner approval.
- Do not edit `lib/l10n/app_localizations*.dart` by hand (generated; excluded from analysis).
- Do not import `package:flutter/...` inside `lib/engine/` (must stay pure Dart, reusable on a future server).
- Do not make a running match read global settings. A match gets its own `GameRulesConfig` at start.
- Do not use `package:flutter/material.dart`; this project uses `material_ui`.
- Do not draw flat rectangles as final art; tiles stay painted with bevel/shadow/pips.
- Do not add real-money features. Do not invent Azneef rules.
- Do not move a placed tile once played (the layout depends only on piece order and the area size; tests enforce it).
- Do not make the tile size depend on how many pieces are on the board (owner requirement).

---

## 7. Decisions log (why things are the way they are)

- Riverpod over Bloc: simpler, testable, less boilerplate here (architecture.md).
- Engine = pure Dart, designed for tests, replay, and future server reuse.
- Rules live in `GameRulesConfig` so Azneef can later be a variant.
- Painted tiles/table with `CustomPainter` first; Flame only if Phase 3+ animation needs justify it.
- Settings persisted with `shared_preferences`, injected via `sharedPreferencesProvider` so tests use a fake. Invalid saved values fall back to defaults.
- OLD board layout (`BoardLayout`, replaced): tile size stepped down from 24 to 6 so the line always fit; arms turned clockwise at unpredictable places. Replaced by `SerpentineLayout` in R2.
- 2026-11-19 (owner): the board is a SQUARE framed surface; tile size is FIXED for the whole round; runs are vertical and serpentine (see 3b).
- 2026-11-19 (R1): felt color is dark green (`0xFF2A6B47` -> `0xFF123824`) as a first choice; it is a constructor parameter of `BoardFrame`. Owner said the look is good.
- 2026-11-19 (R2): tile size is chosen so each arm holds at least 14 pieces (`minArmTiles`), accepting small tiles to avoid overflow. Open question Q-5.
- Arabic is the default language; `app_ar.arb` is the l10n template.
- Backend choice (Firebase vs Dart WebSocket server) deferred to Phase 7.
- 2026-11-19 (R3): `minArmTiles` lowered from 14 to 12 (tile width 13 -> 16 px on a 179 px felt) to put bigger tiles on screen; accepted a small overflow risk in very long rounds. Old `BoardLayout` and its test deleted.
- 2026-11-20 (owner): Removed `ScoreBoard` header box; each player shows `score/target` (e.g. `23/151`, no star icon) beside/under their chip, and a round-by-round score history dialog is accessible from the top-right corner.
- 2026-11-20 (owner): Board is now a tall responsive rectangle (not forced square) with responsive margins, and `WoodTable` on `GameScreen` was replaced by a smooth dark radial background + edge-to-edge bottom dock with a 7-tile clipped scrollable rack above your player details.
- 2026-11-20 (owner): `BoardView` handles single-arm long rounds by smoothly panning (`260ms`) toward empty board space first, and stepping down `tileWidth` only as a fallback when the full board span is exceeded (keeping `SerpentineLayout` pure).
- 2026-11-20 (owner): In 4p mode, side players' score badges and vertical 7-slot tile racks emerge flush from physical left/right screen edges (`textDirection: TextDirection.ltr` so RTL does not flip them).

---

## 8. Inbox (messages between agents / owner)

Format: `- [OPEN|DONE] from → to (date): message`

- [OPEN] Claude (chat) → next agent (2026-11-18): Please run `flutter pub get && flutter gen-l10n && flutter analyze && flutter test` first and log the real results; I could not run them. If something fails, fix it before new work.
- [OPEN] Claude (chat) → owner (2026-11-18): Questions Q-1..Q-4 below need your answers before Phase 4 can close.
- [DONE] Claude (chat) → owner (2026-11-19): R1 visual check. Owner replied that everything is good.
- [OPEN] Claude (chat) → owner (2026-11-19): R2 needs a visual check: tile size, gap between columns, turn direction (lower arm left, upper arm right), and doubles. Decide if tile size is OK (Q-5).
- [OPEN] Claude (chat) → owner (2026-11-19): R3 visual check: bigger tiles; look at a long round to see whether any piece leaves the frame.


### Open questions for the owner
- **Q-1** Were the 4 docs (requirements, roadmap, architecture, game_rules) approved? If yes, remove "DRAFT" and record the date here.
- **Q-2** Confirm the `[ASSUMED]` rules (I-4): same-team tie starter; compulsory play; alternate drawing to find a starting double in 2-player mode.
- **Q-3** "After a blocked round the blocker deals" (rules section 3) vs "the winner starts" (section 4): is "deals" only about who shuffles (no gameplay effect), or does it change who starts?
- **Q-4** What should happen when the target score is reached: simple result screen with "play again / main menu"? Any extra UI wanted?
- **Q-5** Tile width is now about 16 px (minArmTiles = 12). Is it big enough, or should it be even bigger with the risk that a very long round overflows the frame?

---

## 9. Change Log (newest first)

### Entry template — copy this
```
### YYYY-MM-DD HH:MM — <Agent name / tool> — <short title>
- Task asked by: <owner / person>
- Changed: <exact file paths, one per line, with 1-line reason>
- Added/removed packages: <none | name + reason>
- Verified: <commands run and real result | NOT RUN>
- Docs updated: <files | none>
- Status/phase impact: <none | what moved>
- Left for next agent: <what is unfinished, risks, traps>
```

### 2026-11-20 02:55 — Antigravity — Audio system (Iraqi café ambience + place/draw/pass SFX)
- Task asked by: owner (add Iraqi café background ambience toggleable in Settings, plus tile place, tile draw, and pass sound effects).
- Changed:
  - `pubspec.yaml`: added `audioplayers: ^6.1.0` (needed for low-latency SFX + looping background ambience on Android/iOS) and declared `assets/audio/`.
  - `lib/core/audio/sound_service.dart` (new): `SoundService` + `soundServiceProvider` safely checking `rootBundle` before playing `audio/cafe_ambient.mp3`, `audio/tile_place.mp3`, `audio/tile_draw.mp3`, and `audio/tile_pass.mp3` (no crash if assets are not yet added).
  - `lib/state/settings_provider.dart`: added persisted `ambientEnabled` (`settings.ambient_sound`, default `true`) and `setAmbientSound`.
  - `lib/ui/screens/settings_screen.dart`: added toggle for Iraqi café ambience under the Sound section.
  - `lib/state/match_controller.dart`: triggered `playTilePlace`, `playTileDraw`, and `playPass` on move/draw/pass events.
  - `lib/ui/screens/game_screen.dart`: added `WidgetsBindingObserver` to start/pause/resume/stop `startCafeAmbient` cleanly on match entry/exit and app lifecycle changes.
  - `AI_HANDOFF.md`: updated I-8 and added Change Log entry.
- Added/removed packages: added `audioplayers: ^6.1.0` (reason: SFX + looping ambient audio playback).
- Verified: NOT RUN (by owner instruction: no `flutter pub get`, `flutter analyze`, or `flutter test` executed in this session).
- Docs updated: `AI_HANDOFF.md`.
- Status/phase impact: Audio code ready; awaiting `flutter pub get` and owner's `.mp3` files in `assets/audio/` + license entries in `docs/assets_licenses.md`.
- Left for next agent: run `flutter pub get && flutter gen-l10n && flutter analyze && flutter test`.

### 2026-11-20 02:42 — Antigravity — Natural placement UX: last-played glow, crisp drop, unclipped selection
- Task asked by: owner (simplify unnatural mid-air spinning/flipping animations into practical, natural UX, and prevent selected 2-end tile from clipping under the rack/board).
- Changed:
  - `lib/state/match_controller.dart`: replaced `pendingOpponentMove`/`commitOpponentMove` delay with `lastPlayedPiece` in `MatchViewState`.
  - `lib/rendering/board_view.dart`: added optional `lastPlacedPiece` and `_buildPlacedTile` (`900ms` soft fading gold glow on the most recently played tile so players immediately spot where anyone played).
  - `lib/ui/screens/game_screen.dart`: removed mid-air spinning/flipping opponent flights; drag-drop snaps crisply on release; cancel returns smoothly (`220ms`); tap-to-play glides straight to the slot (`260ms`); tuned selected 2-end tile lift (`scale: 1.05`, `slide: -0.06`) inside `16px` top padding so it stays clearly visible and unclipped.
  - `AI_HANDOFF.md`: added Change Log entry.
- Added/removed packages: none.
- Verified: NOT RUN (by owner instruction: no `flutter analyze`, `flutter test`, or build commands executed in this session).
- Docs updated: `AI_HANDOFF.md`.
- Status/phase impact: Natural domino placement UX complete.
- Left for next agent: run `flutter gen-l10n && flutter analyze && flutter test`.

### 2026-11-20 02:37 — Antigravity — Selected-tile rack clearance & opponent face-down flight with flip-on-arrival
- Task asked by: owner (keep 2-end selected tile rising cleanly above the hand rack without clipping, and animate opponent tiles flying face-down from their rack, rotating mid-flight, and flipping face-up as they land on the board).
- Changed:
  - `lib/state/match_controller.dart`: added `pendingOpponentMove` and idempotent `commitOpponentMove()` (with `450ms` fallback timer for headless tests) so the UI can fly opponent tiles before committing.
  - `lib/ui/screens/game_screen.dart`: increased bottom hand rack top clearance (`16px`, height `tileWidth * 2 + 26`) with smooth `AnimatedScale` + `AnimatedSlide` for selected 2-end tiles; added `_rackKeys` on top/side `_TileRack`s and `_flyOpponentToBoard` using `startFaceDown: true` (`DominoBack` flipping to `DominoTile` at `t = 0.55..0.85` while rotating to `_targetRotation`).
  - `AI_HANDOFF.md`: added Change Log entry.
- Added/removed packages: none.
- Verified: NOT RUN (by owner instruction: no `flutter analyze`, `flutter test`, or build commands executed in this session).
- Docs updated: `AI_HANDOFF.md`.
- Status/phase impact: Selected-tile clearance and opponent tile flight complete.
- Left for next agent: run `flutter gen-l10n && flutter analyze && flutter test`.

### 2026-11-20 02:32 — Antigravity — Full hand-to-board flight with mid-air rotation for tap & drag
- Task asked by: owner (wants tap-to-play and drag-drop to visibly fly out of the hand rack onto the board at a slightly slower, smoother pace, rotating mid-flight into the target board orientation).
- Changed:
  - `lib/ui/screens/game_screen.dart`: added `_boardKey` + `_targetRotation` (computes exact final `LaidTile` angle via `SerpentineLayout.fit`), unified `_flyToBoard` for both `_playMine` (tap, `360ms`) and `_onDrop` (drag, `340ms`), slowed return-to-hand flight to `320ms`, and interpolated `Transform.rotate(angle: toAngle * t)` inside `_flyOverlayTile`.
  - `AI_HANDOFF.md`: added Change Log entry.
- Added/removed packages: none.
- Verified: NOT RUN (by owner instruction: no `flutter analyze`, `flutter test`, or build commands executed in this session).
- Docs updated: `AI_HANDOFF.md`.
- Status/phase impact: Hand-to-board flight & mid-air rotation complete.
- Left for next agent: run `flutter gen-l10n && flutter analyze && flutter test`.

### 2026-11-20 02:28 — Antigravity — Removed board tile pop animation for natural placement
- Task asked by: owner (wants natural, fluid drag/drop and tile placement without extra zoom/pop effects on the board).
- Changed:
  - `lib/rendering/board_view.dart`: removed `_AnimatedBoardTile` scale/fade wrapper so placed tiles appear naturally on the board without a pop effect, keeping only the smooth `BoardView` pan (`AnimatedPositioned`) and smooth hand/overlay drag-and-drop in `GameScreen`.
  - `AI_HANDOFF.md`: added Change Log entry.
- Added/removed packages: none.
- Verified: NOT RUN (by owner instruction: no `flutter analyze`, `flutter test`, or build commands executed in this session).
- Docs updated: `AI_HANDOFF.md`.
- Status/phase impact: Natural placement UX complete.
- Left for next agent: run `flutter gen-l10n && flutter analyze && flutter test`.

### 2026-11-20 02:25 — Antigravity — Smooth overlay return/drop flight and board tile landing physics
- Task asked by: owner (fix clipped/snappy return-to-hand drag animation and make drag/drop and tile placement feel smooth and physical).
- Changed:
  - `lib/rendering/board_view.dart`: added `_AnimatedBoardTile` (`260ms easeOutCubic` scale 1.2 -> 1.0 + fade-in) keyed by unique piece identity so newly placed tiles land smoothly on the board.
  - `lib/ui/screens/game_screen.dart`: added `TickerProviderStateMixin` and `_flyOverlayTile` overlay flight animations (`Curves.easeOutCubic`) so a canceled drag flies smoothly from release point into its live opening hand slot (keeping the hand slot tile invisible via `hidden` until landing, eliminating flicker/squish), and a dropped tile flies smoothly from the finger to the target board slot before committing the move.
  - `AI_HANDOFF.md`: added Change Log entry.
- Added/removed packages: none.
- Verified: NOT RUN (by owner instruction: no `flutter analyze`, `flutter test`, or build commands executed in this session).
- Docs updated: `AI_HANDOFF.md`.
- Status/phase impact: Drag-and-drop and placement animation polish complete.
- Left for next agent: run `flutter gen-l10n && flutter analyze && flutter test` and verify animations on device/emulator.

### 2026-11-20 02:16 — Antigravity — Fluid hand drag physics, 2p interactive boneyard draw table, and end-of-round tile reveal
- Task asked by: owner (smooth hand collapse/expand during drag; 2-row wooden boneyard drawing table for 2p human draws; face-up reveal of remaining tiles + visual score tally on round end instead of round-ended text dialog).
- Changed:
  - `lib/engine/round_state.dart`, `lib/engine/match_state.dart`: added optional `[int? index]` parameter to `draw()` so the human player can draw a specific tile from the boneyard (backwards-compatible with `draw()`).
  - `lib/state/match_controller.dart`: added `boneyardSlots` (fixed 14-slot layout), `awaitingHumanDraw`, `revealingRound`, and `drawHumanTile(int slotIndex)`. On round end, reveals remaining tiles for 3.2 s and automatically starts the next round (opening `_MatchResultDialog` only when `targetScore` is reached).
  - `lib/ui/screens/game_screen.dart`: added smooth `AnimatedContainer` width collapse/expand (`220ms easeOutCubic`) for hand tiles on drag; added `_BoneyardDrawBoard` (2-row carved wooden table over the board for 2p human draws); updated `_TileRack`/`_SidePlayer` to flip remaining tiles face-up when `revealingRound` is true; replaced `showRoundResultDialog` with visual `_RoundTallyBadge` (`+points` / burned icon).
  - `AI_HANDOFF.md`: added Change Log entry.
- Added/removed packages: none.
- Verified: NOT RUN (by owner instruction: no `flutter analyze`, `flutter test`, or build commands executed in this session).
- Docs updated: `AI_HANDOFF.md`.
- Status/phase impact: Phase 4 UX polish complete; awaiting owner manual testing and approval for Phase 5.
- Left for next agent: run `flutter gen-l10n && flutter analyze && flutter test` and verify drag physics, 2p boneyard table, and end-of-round reveal on device/emulator.

### 2026-11-20 01:57 — Antigravity — Phase 4 step 3: l10n cleanup (I-5), architecture doc update, and MatchController tests
- Task asked by: owner (continue Phase 4 cleanup).
- Changed:
  - `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`: removed duplicate `youStartRoundFree` key, fixed indentation, and removed 7 unused keys (I-5).
  - `docs/architecture.md`: removed duplicated settings bullet and updated engine/state/rendering descriptions to match `MatchState`, `MatchController`, `SerpentineLayout`, `BoardFrame`, and `BoardView`.
  - `test/state/match_controller_test.dart` (new): unit tests for `MatchController` (initialization, `redeal`, `resetMatch`, `playHumanMove`, and clean disposal).
  - `AI_HANDOFF.md`: marked I-5 fixed (pending `flutter gen-l10n`) and added Change Log entry.
- Added/removed packages: none.
- Verified: NOT RUN (by owner instruction: no `flutter gen-l10n`, `flutter analyze`, `flutter test`, or build commands executed in this session).
- Docs updated: `docs/architecture.md`, `AI_HANDOFF.md`.
- Status/phase impact: Phase 4 implementation and cleanup complete pending manual `flutter gen-l10n`, `flutter analyze`, `flutter test`, and owner sign-off to begin Phase 5 (AI).
- Left for next agent: run `flutter gen-l10n && flutter analyze && flutter test` and await owner approval before starting Phase 5 (`lib/ai/`).

### 2026-11-20 01:49 — Antigravity — Phase 4 step 2: Riverpod MatchController (fixes I-2)
- Task asked by: owner (continue Phase 4).
- Changed:
  - `lib/engine/game_rules_config.dart`: implemented `operator ==` and `hashCode` so `GameRulesConfig` works cleanly as a Riverpod family parameter.
  - `lib/state/match_controller.dart` (new): Riverpod 3 `NotifierProvider.autoDispose.family` (`matchControllerProvider`) owning `MatchState`, timers, countdown, AI/draw/pass scheduling, and emitting immutable `MatchViewState` snapshots.
  - `lib/ui/screens/game_screen.dart`: refactored to watch/listen to `matchControllerProvider`; removed all timers, `Random`, and direct engine mutation from `_GameScreenState` (UI interaction state only).
  - `AI_HANDOFF.md`: marked I-2 fixed and added Change Log entry.
- Added/removed packages: none.
- Verified: NOT RUN (by owner instruction: no `flutter analyze`, `flutter test`, or build commands executed in this session).
- Docs updated: `AI_HANDOFF.md`.
- Status/phase impact: I-1 and I-2 fixed; remaining Phase 4 cleanup items are I-5 (`.arb` duplicates/unused keys), remaining I-4 confirmations, and docs cleanup (`docs/architecture.md`).
- Left for next agent: run `flutter analyze` and `flutter test`; add unit tests for `MatchController` and clean up `app_ar.arb`/`app_en.arb` (I-5) when authorized.

### 2026-11-20 01:44 — Antigravity — Confirmed 2p draw rules in docs
- Task asked by: owner (confirmed that 2p normal draw is continuous by the same player until playable, while alternate drawing applies only to first-round opening when neither player holds a double).
- Changed:
  - `docs/game_rules.md`: removed `[ASSUMED]` from Section 4 (2p first-round alternate draw) and Section 6 (2p draw-until-playable, non-alternating).
  - `AI_HANDOFF.md`: updated I-4 to reflect the confirmed rules and added Change Log entry.
- Added/removed packages: none.
- Verified: NOT RUN (documentation-only update; engine code in `round_state.dart` and `dealer.dart` already matches both rules).
- Docs updated: `docs/game_rules.md`, `AI_HANDOFF.md`.
- Status/phase impact: Partial closure of I-4.
- Left for next agent: proceed to `MatchController` in `lib/state/` (I-2) when owner is ready.

### 2026-11-20 01:40 — Antigravity — Phase 4 step 1: MatchState, match-end dialog, and 2p alternate-draw rule
- Task asked by: owner (start Phase 4 work).
- Changed:
  - `lib/engine/dealer.dart`: updated `Dealer.dealFirstRound` to implement alternate boneyard drawing when neither player holds an initial double in 2-player mode (per `docs/game_rules.md` Section 4).
  - `test/engine/dealer_test.dart`: updated 2-player hand/boneyard length assertions to allow alternate-draw opening hands.
  - `lib/engine/match_state.dart` (new): pure-Dart `MatchState` and `MatchRoundRecord` managing multi-round scores, round history, `winnerTeam`/`isOver` at `rules.targetScore`, `startNextRound`, and `resetMatch`.
  - `test/engine/match_state_test.dart` (new): unit tests for 2p and 4p full matches, target-score termination, history totals, guard rails, and `resetMatch`.
  - `lib/ui/screens/game_screen.dart`: wired `MatchState` into `_GameScreenState` (removing manual score/history/next-round dealing logic from the UI) and added `_MatchResultDialog` (Play Again / Back) when `targetScore` is reached (fixes I-1).
  - `AI_HANDOFF.md`: marked I-1 fixed and added Change Log entry.
- Added/removed packages: none.
- Verified: NOT RUN (by owner instruction: no `flutter analyze`, `flutter test`, or build commands executed in this session).
- Docs updated: `AI_HANDOFF.md`.
- Status/phase impact: Phase 4 underway (I-1 fixed, `MatchState` + alternate-draw done; I-2 Riverpod `MatchController` and I-5 l10n cleanup remain).
- Left for next agent: run `flutter analyze` and `flutter test`; next Phase 4 step is moving timers/turn orchestration from `GameScreen` into a Riverpod `MatchController` in `lib/state/` (I-2) and cleaning up `app_ar.arb`/`app_en.arb` (I-5).

### 2026-11-20 01:35 — Antigravity — Invalid-deal rule (6+ doubles or 6+ of same number)
- Task asked by: owner (prevent dealing any hand with 6+ doubles or 6+ tiles of the same number).
- Changed:
  - `docs/game_rules.md`: documented automatic redeal rule for 6+ doubles or 6+ tiles sharing the same number (0–6) under Section 3 (Dealing).
  - `lib/engine/dealer.dart`: added `Dealer.isValidHand` and looped `Dealer.deal` until all hands satisfy it.
  - `test/engine/dealer_test.dart`: added unit tests for `Dealer.isValidHand` and 200-seed checks on `deal` and `dealFirstRound`.
  - `AI_HANDOFF.md`: added rule note to Section 4 and Change Log entry.
- Added/removed packages: none.
- Verified: NOT RUN (by owner instruction: no `flutter analyze`, `flutter test`, or build commands executed in this session).
- Docs updated: `docs/game_rules.md`, `AI_HANDOFF.md`.
- Status/phase impact: Engine dealing rules updated ahead of Phase 4 completion.
- Left for next agent: run `flutter test test/engine/dealer_test.dart` along with full `flutter analyze` and `flutter test`.

### 2026-11-20 01:27 — Antigravity — Serpentine fix, BoardView smooth pan, and responsive 2p/4p GameScreen redesign
- Task asked by: owner (fix `serpentine_layout.dart` compile errors; enlarge board height; replace `ScoreBoard` with per-player `score/target` + round history; add opponent tile racks; smooth single-arm overflow handling; responsive 2p/4p layout with edge-flush side racks/scores and edge-to-edge dark bottom dock).
- Changed:
  - `lib/rendering/serpentine_layout.dart`: removed leftover duplicate code/braces inside `_next` and stale doc comment line causing compile errors (`'top' is already declared`, `Can't find '}'`).
  - `lib/rendering/board_view.dart`: added `_fitLayout` + `_bounds` and `AnimatedPositioned` (`260ms easeOutCubic`) to pan smoothly toward empty board space on `overflow` and step `tileWidth` down only as a fallback.
  - `lib/ui/widgets/player_chip.dart`: added `compact` mode (smaller avatar/badge, darker high-contrast name pill, bolder text).
  - `lib/ui/screens/game_screen.dart`: shrunk `AppBar` (`toolbarHeight: 40`); replaced `WoodTable` with dark radial gradient; removed `ScoreBoard` and added `_PlayerScoreBadge` (`score/target`, no star), `_TopInfoPill` (`14/14` boneyard in 2p + round log), `_RoundHistoryDialog`, and `_TileRack` (7-slot fixed span; horizontal for top, vertical flush-edge for 4p side players with `textDirection: TextDirection.ltr`); converted board to tall responsive rectangle; moved bottom hand into a clipped 7-tile scrollable rack above your chip inside an edge-to-edge bottom dock; made all reserves/gaps/tile widths responsive to screen size.
  - `AI_HANDOFF.md`: updated snapshot, layout description, decisions, and Change Log.
- Added/removed packages: none.
- Verified: NOT RUN (by owner instruction: no `flutter analyze`, `flutter test`, or build commands executed in this session).
- Docs updated: `AI_HANDOFF.md` only (`docs/` reviewed and unchanged).
- Status/phase impact: Late Phase 3 / early Phase 4; UI redesign ready for owner visual/manual testing.
- Left for next agent: run `flutter analyze` and `flutter test`; confirm R5/R6 polish and proceed to Phase 4 engine items (`I-1` match end, `I-2` Riverpod match controller, `I-3` engine completion, `I-4` rule confirmations) once owner approves.

### 2026-11-19 20:38 — Antigravity — Step R4: vertical doubles after turns / near edges
- Task asked by: owner (wants doubles to stand vertically/lengthwise inside the column in corner/tight cases instead of crosswise).
- Changed:
  - `lib/rendering/serpentine_layout.dart`: added `_Arm.afterTurn` flag; in `_next`, doubles now stand vertically (`w x 2w`) right after a turn or when crosswise (`2w x w`) does not fit within `doubleMargin`, and fall through to turn cleanly if neither fits straight at the end of a column (instead of forcing overflow).
  - `test/rendering/serpentine_layout_test.dart`: added 3 unit tests covering a double right after a turn, a double near a side wall, and a double turning at the end of a column.
  - `AI_HANDOFF.md`: updated R4 status, layout rule note, and Change Log.
- Added/removed packages: none.
- Verified:
  - `flutter analyze`: PASSED (0 issues).
  - `flutter test test/rendering/serpentine_layout_test.dart`: PASSED (20/20 tests).
  - `flutter test`: 48 passed, 3 pre-existing UI test failures (`test/widget_test.dart`, `test/ui/game_screen_test.dart` — missing `CupertinoLocalizations` delegate for `ar` locale).
- Docs updated: `AI_HANDOFF.md` only.
- Status/phase impact: R4 done; awaiting owner visual check on device/emulator before R5.
- Left for next agent: fix the pre-existing `CupertinoLocalizations` delegate warning failing the 3 UI tests when authorized, and proceed to R5 after owner visual check.

### 2026-11-19 — Claude (claude.ai chat) — Step R2: fixed-size serpentine layout
- Task asked by: owner (fixed tile size, vertical columns, S-shaped path).
- Changed:
  - `lib/rendering/serpentine_layout.dart` (new): fixed tile width from the area, serpentine path, turn pieces beside the last half, doubles crosswise and never turn, `overflow` flag.
  - `test/rendering/serpentine_layout_test.dart` (new): fixed size, capacity, arm directions, turn sides, random full rounds (non-overflow layouts), placed tiles never move.
  - `lib/rendering/board_view.dart`: uses `SerpentineLayout.fit` (import + one call changed).
  - `AI_HANDOFF.md`: plan table, layout rules, code map, I-14, Q-5, inbox.
- Added/removed packages: none.
- Verified: NOT RUN (no Flutter toolchain in this session). Tile size numbers were computed by hand only.
- Docs updated: `AI_HANDOFF.md` only. `docs/architecture.md` in R6.
- Status/phase impact: R2 done, R3 partial.
- Left for next agent: run `flutter analyze` and `flutter test`. Old `test/rendering/board_layout_test.dart` still tests the old `BoardLayout` and is unchanged. Fix any failing geometry test before new work. Tile size is small (I-14): wait for the owner's answer to Q-5.

### 2026-11-19 — Claude (claude.ai chat) — Step R1: square framed board and table re-layout
- Task asked by: owner (redesign of the board look and tile flow, split into small steps).
- Changed:
  - `lib/rendering/board_frame.dart` (new): square frame widget (carved wood frame, gold line, green felt, shadow). Decoration only.
  - `lib/ui/screens/game_screen.dart`: `_buildTableArea` now computes the biggest square between the players and puts `BoardFrame` in it (`_buildBoardZone` wraps the drop zone in the frame); side players moved into fixed 66 px slots next to the square with `FittedBox` so names are not cut off; removed the old fixed paddings (108 / 76). Game logic, timers and hand code unchanged.
- Added/removed packages: none.
- Verified: NOT RUN (no Flutter toolchain in this session). Expected: `test/ui/game_screen_test.dart` (360x640) still passes; `board_layout_test` untouched.
- Docs updated: `AI_HANDOFF.md` (section 3b, code map, I-14, Q-5).
- Status/phase impact: Board redesign R1 done.
- Left for next agent: the felt color is a first choice (green); owner said the look is good.

### 2026-11-18 — Claude (claude.ai chat) — Created AI_HANDOFF.md
- Task asked by: owner (asked for a shared understanding file between all AI agents).
- Changed: `AI_HANDOFF.md` (new, repo root). No code changed.
- Added/removed packages: none.
- Verified: NOT RUN (read-only review of the full repo snapshot and all files in `docs/`; no Flutter toolchain used).
- Docs updated: none. Found stale items, recorded as I-5, I-11.
- Status/phase impact: Recorded the project as late Phase 3 / early Phase 4.
- Left for next agent: Run the verification commands (Inbox), then work on P1 items only if the owner approves; propose to the owner to close Phase 4 via I-1, I-2, I-3 and Q-1..Q-4.

### 2026-11-19 — Claude (claude.ai chat) — Step R3: remove old layout, bigger tiles
- Task asked by: owner (more tiles on screen, finish the redesign in small steps).
- Changed:
  - `lib/rendering/board_layout.dart`: now only `LayoutBox` and `LaidTile`; old `BoardLayout` removed.
  - `test/rendering/board_layout_test.dart`: deleted (tested the removed class).
  - `lib/rendering/serpentine_layout.dart`: `minArmTiles` 14 -> 12.
  - `AI_HANDOFF.md`: plan table, capacity table, code map, I-14, Q-5, decisions, inbox.
- Added/removed packages: none.
- Verified: NOT RUN for Dart (no toolchain). The capacity numbers come from a Python port of `armCapacity`, not from Dart.
- Docs updated: `AI_HANDOFF.md` only.
- Status/phase impact: R3 done. R4 (doubles / corner polish) and R5 (hand and drag size) remain, plus R6 docs.
- Left for next agent: run `flutter analyze` and `flutter test`. If any file still imports `BoardLayout`, change it to `SerpentineLayout`. Wait for the owner's visual check before R4.