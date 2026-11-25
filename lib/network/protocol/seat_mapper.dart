import '../../engine/round_state.dart';

/// Pure-Dart coordinate mapper between canonical host/server seats
/// (`0..playerCount-1`) and a specific player's rotated local view where local
/// seat `0` is ALWAYS that player at the bottom of the screen.
///
/// Preserves counter-clockwise play order:
/// - 4 players: local `0` = me, `1` = right opponent, `2` = partner (top),
///   `3` = left opponent.
/// - 2 players: local `0` = me, `1` = opponent (top).
class SeatMapper {
  const SeatMapper._();

  /// Converts a canonical host seat into the local screen seat seen by
  /// [viewerCanonicalSeat].
  static int toLocalSeat({
    required int canonicalSeat,
    required int viewerCanonicalSeat,
    required int playerCount,
  }) {
    return (canonicalSeat - viewerCanonicalSeat + playerCount) % playerCount;
  }

  /// Converts a local screen seat seen by [viewerCanonicalSeat] back into the
  /// canonical host seat.
  static int toCanonicalSeat({
    required int localSeat,
    required int viewerCanonicalSeat,
    required int playerCount,
  }) {
    return (localSeat + viewerCanonicalSeat) % playerCount;
  }

  /// Rotates a per-seat list `[s0, s1, ...]` from canonical order into local
  /// screen order for [viewerCanonicalSeat].
  static List<T> rotateSeats<T>(
    List<T> canonicalItems, {
    required int viewerCanonicalSeat,
  }) {
    final n = canonicalItems.length;
    if (n == 0 || viewerCanonicalSeat == 0) {
      return List<T>.unmodifiable(canonicalItems);
    }
    return List<T>.unmodifiable([
      for (var local = 0; local < n; local++)
        canonicalItems[(local + viewerCanonicalSeat) % n],
    ]);
  }

  /// Rotates canonical `[team0Score, team1Score]` so index `0` is ALWAYS the
  /// viewing player's team ("نحن / أنت") and index `1` is ALWAYS the opponents.
  static List<int> rotateTeamScores(
    List<int> canonicalScores, {
    required int viewerCanonicalSeat,
    required int playerCount,
  }) {
    final myTeam = RoundState.teamOf(viewerCanonicalSeat, playerCount);
    if (myTeam == 0) return List<int>.unmodifiable(canonicalScores);
    return List<int>.unmodifiable([canonicalScores[1], canonicalScores[0]]);
  }

  /// Maps canonical `winnerTeam` (`0`, `1`, or `null`) into the viewer's local
  /// team perspective (`0` = viewer's team won, `1` = opponents won).
  static int? rotateWinnerTeam(
    int? canonicalWinnerTeam, {
    required int viewerCanonicalSeat,
    required int playerCount,
  }) {
    if (canonicalWinnerTeam == null) return null;
    final myTeam = RoundState.teamOf(viewerCanonicalSeat, playerCount);
    return canonicalWinnerTeam == myTeam ? 0 : 1;
  }
}
