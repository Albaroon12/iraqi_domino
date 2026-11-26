import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live internet availability snapshot for **المقهى** (`Al-Maqha`).
///
/// When [isOnline] is `false`, the app restricts visible navigation to Offline
/// modes only (**ضد الكمبيوتر** and **اللعب المحلي**). When `true`, the full
/// online Café experience (Auth, Leaderboard, Tournaments, Events, Shop, Online
/// Rooms & Matchmaking) unlocks.
class ConnectivityStatus {
  const ConnectivityStatus({
    this.isOnline = true,
    this.checking = false,
  });

  final bool isOnline;
  final bool checking;

  ConnectivityStatus copyWith({bool? isOnline, bool? checking}) =>
      ConnectivityStatus(
        isOnline: isOnline ?? this.isOnline,
        checking: checking ?? this.checking,
      );
}

class ConnectivityNotifier extends Notifier<ConnectivityStatus> {
  @override
  ConnectivityStatus build() {
    // Inside widget tests (`TestWidgetsFlutterBinding`), `HttpOverrides.current`
    // is non-null; keep `isOnline: true` without real DNS lookups unless a test
    // explicitly toggles offline mode via `setOnlineForTesting(false)`.
    if (HttpOverrides.current == null) {
      Future<void>.microtask(refreshConnectivity);
    }
    return const ConnectivityStatus(isOnline: true);
  }

  /// Checks actual internet reachability using fast DNS/socket probes (`dart:io`,
  /// zero third-party packages).
  Future<bool> refreshConnectivity() async {
    if (HttpOverrides.current != null) {
      return state.isOnline;
    }
    state = state.copyWith(checking: true);
    final reachable = await _probeInternet();
    state = ConnectivityStatus(isOnline: reachable, checking: false);
    return reachable;
  }

  /// Allows deterministic offline/online switching in automated tests.
  void setOnlineStatus(bool isOnline) {
    state = ConnectivityStatus(isOnline: isOnline, checking: false);
  }

  static Future<bool> _probeInternet() async {
    const hosts = ['dns.google', 'one.one.one.one', 'example.com'];
    for (final host in hosts) {
      try {
        final res = await InternetAddress.lookup(
          host,
        ).timeout(const Duration(milliseconds: 1200));
        if (res.isNotEmpty && res.first.rawAddress.isNotEmpty) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }
}

final connectivityProvider =
    NotifierProvider<ConnectivityNotifier, ConnectivityStatus>(
      ConnectivityNotifier.new,
    );
