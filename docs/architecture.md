# Architecture — المقهى (`Al-Maqha`)
Status: v1.0 Release Ready

## Layers
1. `lib/engine/` (**Pure Dart**, zero Flutter imports): `DominoPiece`, `Dealer` (2-2-3 deal, invalid-deal prevention, 2p alternate opening draw), `Board`, `RoundState`, `RoundResult`, `GameRulesConfig`, `SeatOccupant`, `MatchState`, `MatchViewState`.
2. `lib/ai/` (**Pure Dart**): `AiDifficulty` (`easy`..`expert`), `DominoAi` (Bayesian unseen-tile inference, pass/draw deduction, 4p partner coordination, 2-ply lookahead), `UserPlayProfile`, and 10 `AiPersona` characters.
3. `lib/data/` (**Pure Dart** models + Riverpod `GameDataCenter`): `PlayerAccount`, `CafeProgression`, `CafeShopCatalog` (3d / 7d rentals & permanent ownership across 6 categories), and `CafeEventDefinition` / `CafeTournamentTier`.
4. `lib/network/` & `lib/server/` (**Pure Dart** authoritative multiplayer & backend):
   - `AuthoritativeRoomHost`, `RoomClientSession`, anti-cheat `MaskedMatchPayload`.
   - Local transports: `lan_socket_transport.dart` (`localWifi`, `wifiOffline`) and native Kotlin/Swift `NearbyP2pBridge` (`bluetooth`, Wi-Fi Direct).
   - Online backend (`DominoOnlineServer`, `bin/server.dart`, `Dockerfile`): REST Auth (`/api/auth/*`, `/api/account/delete-self`), LiveOps (`/api/live-ops`), WebSocket rooms & matchmaking (`/ws`), and 4-tab Arabic Web Admin Dashboard (`/admin`, `/api/admin/*`).
5. `lib/rendering/` & `lib/ui/`:
   - `package:material_ui/material_ui.dart` & `package:cupertino_ui/cupertino_ui.dart` (never `package:flutter/material.dart`).
   - Custom-painted `DominoTile` (7 `TileSkin`s), `BoardFrame` + `BoardTheme` (16 cloths/carpets/mosaics/marbles & country flags), `SerpentineLayout`, `CafeAvatarFrame`, `CafePropWidget`, and `AiPersonaAvatar`.
   - `ConnectivityNotifier` (`lib/core/network/connectivity_provider.dart`) gating Offline-Only play vs Full Online Café.
