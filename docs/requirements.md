# Requirements — المقهى (`Al-Maqha`)
Status: v1.0 Release Ready

## Product
**المقهى (`Al-Maqha`)** is an Arabic-first heritage Café multi-game mobile application in Flutter (Android + iOS, portrait only), launching with **Iraqi Domino** (`2 Players` and `4 Players` partnership) and architected for future Café games (`Backgammon`, `Card Games`, `Azneef`).

## Functional Summary
1. **Smart Internet Connectivity Gate (`ConnectivityNotifier`)**:
   - **Offline Mode**: When no internet is available, skips online login and exposes **Play vs AI** and **Local Play** (`Offline Wi-Fi`, `Bluetooth`, `Local Wi-Fi`) only.
   - **Full Online Mode**: Unlocks the 5-tab Café hub (`Games`, `Tournaments & Events`, `Home + Leaderboard`, `Shop`, `Profile & Settings`), Online Friends Rooms, and Online Random Matchmaking.
2. **Accounts & Moderation**:
   - Sign-In / Register via **Email & Password**, **Google Account (`Gmail`)**, **Phone Number** (UI placeholder marked disabled for future SMS rollout), or **1-tap Guest** with automatic stats/Dinar linking.
   - Self-service permanent account deletion inside Settings (App Store & Google Play compliant).
   - Full Arabic Web Admin Control Panel (`GET /admin`) for managing accounts, temporary bans, account cancellations, live rooms, tournaments, and events.
3. **Progression & Economy**:
   - **Level 1..50** (`2,000 XP/day` cap from online matches; `0` match XP vs offline AI; VIP `4,000 XP/day` & `2x XP`; badge & event XP uncapped).
   - **Rank-Based Café Titles**: `شيخ المقهى`, `كبير المقهى`, `أستاذ المجلس`, `حريف المقهى`, `صاحب مجلس`, `روّاد المقهى`, `زبون جديد`.
   - **Single Scarcity Currency (`دينار المقهى`)**: `0` Dinars from regular matches; earned strictly via Tournaments (Daily Free Cup + Staked Cups with **10% Café rake**) and Events (Fixed Recurring `daily`/`weekly`/`monthly`, Seasonal `Ramadan`/`Eid`, and Custom **Sponsored Image Ad Events**).
   - **100% Virtual Economy**: Strictly virtual entertainment currency with zero cash-out or real-money gambling.
