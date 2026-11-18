# AI_HANDOFF.md — Shared Notebook for All AI Agents

> **READ THIS FILE FIRST. UPDATE IT LAST.**
> This is the single coordination file between every AI agent working on
> *Iraqi Domino* (Claude chat, Claude Code, Codex, Gemini, Copilot, anyone).
> The owner works with several agents on different days. No agent remembers
> the previous one. This file is the memory.

Last updated: 2026-11-18 by Claude (claude.ai chat). Created from a full read of the repo snapshot.

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

## 2. Where development is (as of 2026-11-18)

Roadmap source: `docs/roadmap.md`.

| Phase | Goal | Status (my assessment) |
|---|---|---|
| 0 | Discovery, rules, docs | Docs exist but all still say **DRAFT v0.1**. Owner approval is not recorded anywhere. See Q-1. |
| 1 | Flutter project, shell, fonts, theme | **Done.** |
| 2 | Assets & UI design (table, tiles, menus, settings) | **Done in code**: painted tiles, 3 tile skins, wood table, main menu, mode selection, settings with persistence, ar/en localization. Owner look-approval not recorded. |
| 3 | Playable prototype | **Essentially done**: 2-player and 4-player game screen, tap + drag/drop, turn timer, auto pass/draw, round result dialog, board layout that turns corners. Still random "AI". |
| 4 | Real engine + rules + unit tests | **Started, not finished.** Engine is pure Dart with tests, but is still labeled PROTOTYPE and match-level logic lives in the UI. See section 5. |
| 5 | AI (Easy/Medium/Hard/Expert) | Not started. `lib/ai/` does not exist. Computer plays a random legal move. |
| 6-11 | Local multiplayer, online, profiles, shop, tournaments, release | Not started. |

**One-line summary:** *Late Phase 3 / early Phase 4. The game is playable end-to-end per round, but there is no match end, no real AI, no sound, and the game logic still sits inside `game_screen.dart`.*

**Test status:** NOT RUN by the agent that created this file (no Flutter toolchain in that session). Test files exist (section 4). First action for any agent with a shell: run `flutter pub get`, `flutter gen-l10n`, `flutter analyze`, `flutter test` and record the real result in the Change Log.

---

## 3. Process gates

- Phase changes need explicit owner approval. Do not start Phase 5 work (AI) or Phase 6+ work "because it is next".
- Finishing Phase 4 means: tests match `docs/game_rules.md`, and the rules in code have no `[ASSUMED]` item left unconfirmed by the owner.
- Azneef mode: rules NOT provided by the owner yet. Do not invent them. The menu button is intentionally disabled ("Coming soon").

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
    board_layout.dart          pure-Dart layout: vertical start, arms turn clockwise, doubles crosswise and never turn, tile size shrinks (24 -> 6) until it fits
    board_view.dart            draws line + ghost slots (gold = target)
  state/settings_provider.dart SettingsState + NotifierProvider, saved in shared_preferences, invalid values fall back to defaults
  ui/
    screens/ main_menu, mode_selection, game_screen, settings, + DEV ONLY: tile_gallery, table_preview
    widgets/ game_button, player_chip (turn ring/timer), score_board, round_result_dialog
    localized_names.dart       tileSkinName()
  l10n/ app_ar.arb (TEMPLATE), app_en.arb, generated app_localizations*.dart (do not edit by hand)
test/
  engine/ board_test, dealer_test, round_state_test
  rendering/ board_layout_test (randomized full-round simulations, 100 seeds per config)
  state/ settings_provider_test
  ui/ game_screen_test (360x640 fit test, Arabic strings)
  widget_test.dart, helpers/test_app.dart
docs/ requirements.md, roadmap.md, architecture.md, game_rules.md, assets_licenses.md
```

**Seat numbering:** counter-clockwise from bottom. 4 players: 0 = you, 1 = right opponent, 2 = partner (top), 3 = left opponent. 2 players: 0 = you, 1 = opponent (top). Teams with 4 players: `seat % 2`.

**Directions on screen are physical, never language-dependent:** side players use physical left/right alignment on purpose; board layout uses physical coordinates. Do not "fix" this with `AlignmentDirectional`.

**Rules as currently implemented (matches `docs/game_rules.md` unless noted):**
- 7 tiles each, dealt 2-2-3. 2 players: 14-tile boneyard. 4 players: none.
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
- **I-1 No match end.** `game_screen.dart` accumulates `_scores` and shows the target, but never checks if a side reached `targetScore`. The game just keeps dealing new rounds forever. Needs: match-over detection, a "match result" dialog/screen, and a way back to the menu.
- **I-2 Game logic lives in the UI.** `_GameScreenState` owns the round, scores, timers, AI choice and next-round dealing. `docs/architecture.md` says there should be one Riverpod controller per match in `lib/state/`. Move match flow into an engine-level `MatchState` (pure Dart, tested) + a controller. Keep screens receiving plain data.
- **I-3 Engine is still a prototype.** `RoundState` is mutable and `Dealer.dealFirstRound` just re-deals when a 2-player deal has no double, instead of the agreed rule (players draw alternately from the boneyard until a double shows; `[ASSUMED]` who starts drawing). `GameRulesConfig` only has `targetScore`. The "blocker deals" rule from `game_rules.md` section 3 is not modeled (the code only models who *starts*).
- **I-4 Two `[ASSUMED]` rules in `docs/game_rules.md` need owner confirmation** (same-team tie starter; compulsory play / draw-until-playable; alternate-draw start rule).

**P2**
- **I-5 Localization file problems.** `lib/l10n/app_ar.arb` and `app_en.arb` both contain the key `youStartRoundFree` **twice**; JSON keeps the last value (ar: "تبدأ الجولة", en: "You start the round"), so the first, more descriptive text ("...with any piece") is silently dropped. Remove the duplicate and decide the intended wording. Also `app_en.arb` has odd indentation. Unused keys exist: `phaseOneReady`, `gameScreenComingSoon`, `passButton`, `drawButton`, `tilesLeft`, `featureComingSoon`, `previewRoundResult`. After editing .arb files run `flutter gen-l10n`.
- **I-6 `cupertino_ui: any` in pubspec** has no stated reason and no import in the shown code. Project rule: no package without a reason. Either document the reason or remove it (verify nothing imports it first).
- **I-7 iOS orientation mismatch.** `ios/Runner/Info.plist` still lists landscape orientations for iPhone; requirements say portrait only. `main.dart` locks portrait at runtime, but the plist should match. Android has no `screenOrientation` in the manifest (same situation).
- **I-8 Sound.** The "Sound" setting exists and persists, but there is no audio code and no sound assets. Needs a package decision (state the reason) and a license entry in `docs/assets_licenses.md`.
- **I-9 AI.** Computer players pick a random legal move (`_aiPlay`, `_autoPlayForMe`). Phase 5 replaces this. Keep the call sites small so a strategy interface can be dropped in.

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
- Do not move a placed tile once played (layout replays `Board.history`; tests enforce it at a fixed tile size).

---

## 7. Decisions log (why things are the way they are)

- Riverpod over Bloc: simpler, testable, less boilerplate here (architecture.md).
- Engine = pure Dart, designed for tests, replay, and future server reuse.
- Rules live in `GameRulesConfig` so Azneef can later be a variant.
- Painted tiles/table with `CustomPainter` first; Flame only if Phase 3+ animation needs justify it.
- Settings persisted with `shared_preferences`, injected via `sharedPreferencesProvider` so tests use a fake. Invalid saved values fall back to defaults.
- Board layout: line starts vertical in the center; the right-end arm goes down, left-end arm goes up; arms turn 90° when they hit the safe zone; doubles are crosswise and never turn; tile size steps down from 24 to 6 so the line plus one more piece per end always fits.
- Arabic is the default language; `app_ar.arb` is the l10n template.
- Backend choice (Firebase vs Dart WebSocket server) deferred to Phase 7.

---

## 8. Inbox (messages between agents / owner)

Format: `- [OPEN|DONE] from → to (date): message`

- [OPEN] Claude (chat) → next agent (2026-11-18): Please run `flutter pub get && flutter gen-l10n && flutter analyze && flutter test` first and log the real results; I could not run them. If something fails, fix it before new work.
- [OPEN] Claude (chat) → owner (2026-11-18): Questions Q-1..Q-4 below need your answers before Phase 4 can close.

### Open questions for the owner
- **Q-1** Were the 4 docs (requirements, roadmap, architecture, game_rules) approved? If yes, remove "DRAFT" and record the date here.
- **Q-2** Confirm the `[ASSUMED]` rules (I-4): same-team tie starter; compulsory play; alternate drawing to find a starting double in 2-player mode.
- **Q-3** "After a blocked round the blocker deals" (rules section 3) vs "the winner starts" (section 4): is "deals" only about who shuffles (no gameplay effect), or does it change who starts?
- **Q-4** What should happen when the target score is reached: simple result screen with "play again / main menu"? Any extra UI wanted?

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

### 2026-11-18 — Claude (claude.ai chat) — Created AI_HANDOFF.md
- Task asked by: owner (asked for a shared understanding file between all AI agents).
- Changed: `AI_HANDOFF.md` (new, repo root). No code changed.
- Added/removed packages: none.
- Verified: NOT RUN (read-only review of the full repo snapshot and all files in `docs/`; no Flutter toolchain used).
- Docs updated: none. Found stale items, recorded as I-5, I-11.
- Status/phase impact: Recorded the project as late Phase 3 / early Phase 4.
- Left for next agent: Run the verification commands (Inbox), then work on P1 items only if the owner approves; propose to the owner to close Phase 4 via I-1, I-2, I-3 and Q-1..Q-4.
