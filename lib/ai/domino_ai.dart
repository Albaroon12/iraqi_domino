import 'dart:math' as math;

import '../engine/board.dart';
import '../engine/domino_piece.dart';
import '../engine/round_state.dart';
import 'ai_difficulty.dart';
import 'user_play_profile.dart';

/// Deterministic, inference-driven AI for Iraqi Domino across four difficulty
/// levels ([AiDifficulty.easy], [AiDifficulty.medium], [AiDifficulty.hard],
/// [AiDifficulty.expert]).
///
/// Pure Dart: reads only public information from [RoundState], the active
/// seat's own hand, and the learned [UserPlayProfile] (never peeks at other
/// players' hands or the boneyard).
class DominoAi {
  DominoAi._();

  /// Chooses the best legal move for the current turn of [round].
  /// Throws [StateError] if [round.legalMoves] is empty.
  static Move chooseMove(
    RoundState round, {
    AiDifficulty difficulty = AiDifficulty.medium,
    UserPlayProfile? userProfile,
  }) {
    final moves = round.legalMoves();
    if (moves.isEmpty) {
      throw StateError('DominoAi.chooseMove called with no legal moves');
    }
    if (moves.length == 1) return moves.single;

    final seat = round.turn;
    final hand = round.hands[seat];

    return switch (difficulty) {
      AiDifficulty.easy => _chooseEasy(moves),
      AiDifficulty.medium => _chooseScored(
        round,
        seat,
        hand,
        moves,
        difficulty: AiDifficulty.medium,
        userProfile: userProfile,
      ),
      AiDifficulty.hard => _chooseScored(
        round,
        seat,
        hand,
        moves,
        difficulty: AiDifficulty.hard,
        userProfile: userProfile,
      ),
      AiDifficulty.expert => _chooseScored(
        round,
        seat,
        hand,
        moves,
        difficulty: AiDifficulty.expert,
        userProfile: userProfile,
      ),
    };
  }

  /// Easy: plays the lightest-pip legal move first (simple, predictable,
  /// leaves high-pip tiles and doubles in hand longer).
  static Move _chooseEasy(List<Move> moves) {
    var best = moves.first;
    var bestScore = _easyScore(best);
    for (var i = 1; i < moves.length; i++) {
      final score = _easyScore(moves[i]);
      if (score > bestScore) {
        bestScore = score;
        best = moves[i];
      }
    }
    return best;
  }

  static double _easyScore(Move move) {
    final p = move.piece;
    final endBias = move.end == BoardEnd.right ? 0.01 : 0.0;
    final doublePenalty = p.isDouble ? -4.0 : 0.0;
    return (12 - p.pips).toDouble() +
        doublePenalty -
        p.high * 0.05 -
        p.low * 0.005 +
        endBias;
  }

  static Move _chooseScored(
    RoundState round,
    int seat,
    List<DominoPiece> hand,
    List<Move> moves, {
    required AiDifficulty difficulty,
    UserPlayProfile? userProfile,
  }) {
    final inference = _TableInference.analyze(
      round: round,
      mySeat: seat,
      myHand: hand,
      userProfile: userProfile,
    );

    var best = moves.first;
    var bestScore = _evaluateMove(
      round: round,
      seat: seat,
      hand: hand,
      move: best,
      difficulty: difficulty,
      inference: inference,
    );

    for (var i = 1; i < moves.length; i++) {
      final candidate = moves[i];
      final score = _evaluateMove(
        round: round,
        seat: seat,
        hand: hand,
        move: candidate,
        difficulty: difficulty,
        inference: inference,
      );
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    return best;
  }

  static double _evaluateMove({
    required RoundState round,
    required int seat,
    required List<DominoPiece> hand,
    required Move move,
    required AiDifficulty difficulty,
    required _TableInference inference,
  }) {
    final piece = move.piece;
    final remainingHand = [
      for (final p in hand)
        if (p != piece) p,
    ];

    // If this move wins the round immediately (domino!), take it.
    if (remainingHand.isEmpty) return 10000.0;

    final newLeft = _leftEndAfterMove(round.board, move);
    final newRight = _rightEndAfterMove(round.board, move);
    var score = 0.0;

    // -----------------------------------------------------------------
    // 1. Hand structure & Medium heuristics: unload high pips, manage
    //    doubles, keep multi-end coverage, and avoid stranding doubles.
    // -----------------------------------------------------------------
    score += piece.pips * 2.2;

    if (piece.isDouble) {
      score += 11.0;
      final support = remainingHand
          .where((p) => p.hasSide(piece.low))
          .length;
      score += support * 3.5;
    }

    // Suit control: how many tiles in our remaining hand match the new ends?
    final matchLeft = remainingHand.where((p) => p.hasSide(newLeft)).length;
    final matchRight = newRight == newLeft
        ? matchLeft
        : remainingHand.where((p) => p.hasSide(newRight)).length;

    score += (matchLeft + matchRight) * 3.8;
    if (matchLeft == 0 && matchRight == 0) {
      score -= 10.0;
    } else if (matchLeft > 0 && matchRight > 0) {
      score += 6.5;
    }

    // Hand connectivity: reward keeping a diverse set of connected suits in hand
    // rather than stripping our only bridge tile to a heavy suit.
    for (final rem in remainingHand) {
      if (rem.isDouble) {
        final d = rem.low;
        final supportLeft = remainingHand
            .where((p) => p != rem && p.hasSide(d))
            .length;
        final dIsOpen = newLeft == d || newRight == d;
        if (supportLeft == 0 && !dIsOpen && piece.hasSide(d)) {
          score -= difficulty == AiDifficulty.expert ? 20.0 : 12.0;
        }
      } else if (rem.pips >= 8) {
        // Don't orphan a heavy non-double tile if we just burned its only suit link.
        final links = remainingHand
            .where(
              (p) =>
                  p != rem &&
                  (p.hasSide(rem.low) || p.hasSide(rem.high)),
            )
            .length;
        final openMatch =
            rem.hasSide(newLeft) || rem.hasSide(newRight);
        if (links == 0 && !openMatch) {
          score -= 3.5;
        }
      }
    }

    if (difficulty == AiDifficulty.medium) {
      return score + _tieBreaker(move);
    }

    // -----------------------------------------------------------------
    // 2. Hard heuristics: pass & draw memory, opponent hand prediction,
    //    and 4-player team coordination with partner.
    // -----------------------------------------------------------------
    final playerCount = round.playerCount;
    final nextOpponent = (seat + 1) % playerCount;
    final nextOppMissing = inference.hardMissing[nextOpponent];

    final unseenLeft = inference.unseenCountFor(newLeft);
    final unseenRight = inference.unseenCountFor(newRight);

    final nextLacksLeft = nextOppMissing.contains(newLeft) || unseenLeft == 0;
    final nextLacksRight =
        nextOppMissing.contains(newRight) || unseenRight == 0;

    if (nextLacksLeft) score += 13.0;
    if (nextLacksRight) score += 13.0;
    if (nextLacksLeft && nextLacksRight) {
      // Forces the next opponent to pass (4p) or draw from boneyard (2p)!
      score += 22.0;
    }

    // Soft inference: even if the next opponent hasn't formally passed on
    // newLeft/newRight yet, use their predicted probability of holding those
    // numbers from move history & user profile.
    final nextProbLeft = inference.probSeatHoldsSuit(nextOpponent, newLeft);
    final nextProbRight = inference.probSeatHoldsSuit(nextOpponent, newRight);
    score += (1.0 - nextProbLeft) * 5.5;
    score += (1.0 - nextProbRight) * 5.5;

    if (playerCount == 4) {
      final partner = (seat + 2) % 4;
      final secondOpponent = (seat + 3) % 4;
      final partnerMissing = inference.hardMissing[partner];
      final secondOppMissing = inference.hardMissing[secondOpponent];
      final myHandCount = remainingHand.length;
      final partnerHandCount = round.hands[partner].length;

      // Avoid leaving ends that our partner is known to lack.
      final partnerLacksLeft =
          partnerMissing.contains(newLeft) || unseenLeft == 0;
      final partnerLacksRight =
          partnerMissing.contains(newRight) || unseenRight == 0;
      if (partnerLacksLeft) score -= 5.0;
      if (partnerLacksRight) score -= 5.0;
      if (partnerLacksLeft && partnerLacksRight) score -= 6.0;

      // Also reward blocking the second opponent (seat + 3).
      if (secondOppMissing.contains(newLeft)) score += 7.5;
      if (secondOppMissing.contains(newRight)) score += 7.5;

      final secondProbLeft = inference.probSeatHoldsSuit(
        secondOpponent,
        newLeft,
      );
      final secondProbRight = inference.probSeatHoldsSuit(
        secondOpponent,
        newRight,
      );
      score += (1.0 - secondProbLeft) * 3.0;
      score += (1.0 - secondProbRight) * 3.0;

      // Partner move analysis:
      // 1. Respect the last number our partner deliberately opened.
      final partnerOpenEnd = inference.lastOpenedBySeat[partner];
      if (partnerOpenEnd != null && !partnerMissing.contains(partnerOpenEnd)) {
        final keptPartnerNumber =
            newLeft == partnerOpenEnd || newRight == partnerOpenEnd;
        if (keptPartnerNumber) {
          // Higher bonus if partner is close to finishing their hand!
          final supportWeight = partnerHandCount <= 2 ? 15.0 : 9.0;
          score += supportWeight;
        } else {
          // We covered our partner's signal! Penalize unless we locked out
          // the immediate opponent.
          if (!(nextLacksLeft && nextLacksRight)) {
            score -= partnerHandCount <= 2 ? 11.0 : 5.5;
          }
        }
      }

      // 2. Partner's broader signaled suit affinity across the round (plus
      //    user profile when partner is the human at seat 0!).
      final partnerProbLeft = inference.probSeatHoldsSuit(partner, newLeft);
      final partnerProbRight = inference.probSeatHoldsSuit(partner, newRight);
      final partnerRoleMultiplier = partnerHandCount < myHandCount ? 1.45 : 1.0;
      score += (partnerProbLeft + partnerProbRight) * 4.5 * partnerRoleMultiplier;

      // 3. If partner is down to 1–2 tiles ("شريكك على وشك الدومينو"),
      //    feed the number partner signaled even if we had to sacrifice our own
      //    suit coverage!
      if (partnerHandCount <= 2) {
        final bestPartnerSuit = inference.strongestSignaledSuit(partner);
        if (bestPartnerSuit != null &&
            (newLeft == bestPartnerSuit || newRight == bestPartnerSuit)) {
          score += 11.0;
        }
      }
    }

    if (difficulty == AiDifficulty.hard) {
      return score + _tieBreaker(move);
    }

    // -----------------------------------------------------------------
    // 3. Expert heuristics: suit monopoly, user-profile counter-play,
    //    expected pip comparison on board lock, and 2-ply lookahead.
    // -----------------------------------------------------------------
    // Suit monopoly: reward exposing ends where we hold more tiles of that
    // number than all unseen tiles combined.
    if (matchLeft > unseenLeft) score += 9.5;
    if (newRight != newLeft && matchRight > unseenRight) score += 9.5;

    final oppCanPlayLeft = inference.anyOpponentCanHold(newLeft);
    final oppCanPlayRight = inference.anyOpponentCanHold(newRight);

    if (!oppCanPlayLeft) score += 12.0;
    if (!oppCanPlayRight) score += 12.0;

    // Countering / assisting the human user's learned habits (Seat 0):
    if (seat != 0 && inference.userProfile != null) {
      final profile = inference.userProfile!;
      if (profile.confidence > 0.05) {
        final humanIsPartner =
            playerCount == 4 &&
            RoundState.teamOf(0, playerCount) ==
                RoundState.teamOf(seat, playerCount);
        final humanFavLeft = profile.numberOpenAffinity[newLeft];
        final humanFavRight = profile.numberOpenAffinity[newRight];
        final humanSuitSignal = inference.lastOpenedBySeat[0];

        if (humanIsPartner) {
          // Seat 2 (human's partner): support the human's favorite & signaled
          // numbers, especially when the human typically keeps self-suits!
          score +=
              (humanFavLeft + humanFavRight - 1.0) *
              8.0 *
              profile.confidence;
          if (humanSuitSignal != null &&
              (newLeft == humanSuitSignal || newRight == humanSuitSignal)) {
            score +=
                10.0 * profile.selfSuitKeepPreference * profile.confidence;
          }
        } else {
          // Opponent of the human: cut the number the human just opened if the
          // human has high selfSuitKeepPreference, and avoid feeding their
          // favorite open numbers.
          score -=
              (humanFavLeft + humanFavRight - 1.0) *
              7.0 *
              profile.confidence;
          if (humanSuitSignal != null &&
              newLeft != humanSuitSignal &&
              newRight != humanSuitSignal) {
            score +=
                9.5 * profile.selfSuitKeepPreference * profile.confidence;
          }
        }
      }
    }

    // Tactical lock & expected pip comparison:
    final boardWillLock =
        unseenLeft == 0 &&
        unseenRight == 0 &&
        matchLeft == 0 &&
        matchRight == 0;
    final opponentsLockedOut = !oppCanPlayLeft && !oppCanPlayRight;

    if (boardWillLock || opponentsLockedOut) {
      final myRemainingPips = remainingHand.fold<int>(
        0,
        (sum, p) => sum + p.pips,
      );
      final expectedMinOppPips = inference.estimatedLowestOpponentPips();
      if (myRemainingPips < expectedMinOppPips - 2 || myRemainingPips <= 8) {
        score += 44.0;
      } else if (myRemainingPips <= expectedMinOppPips) {
        score += 16.0;
      } else {
        // Locking when we hold MORE pips than the opponent's estimated hand
        // would lose a blocked round!
        score -= 30.0;
      }
    }

    // Single-number lock ("القفلة على رقم واحد") when we control that number
    // or opponents cannot play on it.
    if (newLeft == newRight) {
      if (matchLeft >= 2 || !oppCanPlayLeft) {
        score += 14.0;
      } else if (matchLeft == 0) {
        score -= 10.0;
      }
    }

    // 2-ply lookahead resilience: if the next opponent plays one of the
    // unseen tiles matching (newLeft, newRight), how likely is it that our
    // remainingHand still has a follow-up move (or that we reach a checkmate
    // with 1 tile left)?
    score += _evaluateTwoPlyResilience(
      remainingHand: remainingHand,
      newLeft: newLeft,
      newRight: newRight,
      nextOpponent: nextOpponent,
      inference: inference,
    );

    return score + _tieBreaker(move);
  }

  /// Evaluates 1-step opponent response + our follow-up resilience.
  static double _evaluateTwoPlyResilience({
    required List<DominoPiece> remainingHand,
    required int newLeft,
    required int newRight,
    required int nextOpponent,
    required _TableInference inference,
  }) {
    final replies = inference.unseenPieces
        .where((p) => p.hasSide(newLeft) || p.hasSide(newRight))
        .toList();
    if (replies.isEmpty) return 8.0;

    var totalWeight = 0.0;
    var coveredReplyWeight = 0.0;
    var checkmateBonus = 0.0;

    // If we have only 1 tile left, check if it matches BOTH newLeft and newRight
    // (guaranteed Domino next turn unless both ends are changed simultaneously,
    // which is impossible in 2p!).
    if (remainingHand.length == 1) {
      final lastTile = remainingHand.single;
      if (lastTile.hasSide(newLeft) && lastTile.hasSide(newRight)) {
        checkmateBonus += 25.0;
      }
    }

    for (final oppTile in replies) {
      final prob = inference.probSeatHoldsPiece(nextOpponent, oppTile);
      if (prob <= 0.0) continue;

      // Opponent can play oppTile on newLeft and/or newRight.
      if (oppTile.hasSide(newLeft)) {
        final afterLeft = oppTile.low == newLeft ? oppTile.high : oppTile.low;
        final afterRight = newRight;
        totalWeight += prob;
        final weCanReply = remainingHand.any(
          (myP) => myP.hasSide(afterLeft) || myP.hasSide(afterRight),
        );
        if (weCanReply) coveredReplyWeight += prob;
      }
      if (newRight != newLeft && oppTile.hasSide(newRight)) {
        final afterLeft = newLeft;
        final afterRight =
            oppTile.low == newRight ? oppTile.high : oppTile.low;
        totalWeight += prob;
        final weCanReply = remainingHand.any(
          (myP) => myP.hasSide(afterLeft) || myP.hasSide(afterRight),
        );
        if (weCanReply) coveredReplyWeight += prob;
      }
    }

    if (totalWeight <= 0.0) {
      // Next opponent has zero probability of holding any matching unseen tile!
      return 10.0 + checkmateBonus;
    }

    final coverageRatio = coveredReplyWeight / totalWeight;
    return (coverageRatio * 9.0) + checkmateBonus;
  }

  static int _leftEndAfterMove(Board board, Move move) {
    final p = move.piece;
    if (board.isEmpty) return p.low;
    final left = board.leftEnd!;
    if (move.end == BoardEnd.left) {
      return p.low == left ? p.high : p.low;
    }
    return left;
  }

  static int _rightEndAfterMove(Board board, Move move) {
    final p = move.piece;
    if (board.isEmpty) return p.high;
    final right = board.rightEnd!;
    if (move.end == BoardEnd.right) {
      return p.low == right ? p.high : p.low;
    }
    return right;
  }

  static double _tieBreaker(Move move) {
    final p = move.piece;
    final endBias = move.end == BoardEnd.right ? 0.001 : 0.0;
    return p.high * 0.01 + p.low * 0.002 + endBias;
  }
}

/// Internal Bayesian table & hand inference engine built from public history.
class _TableInference {
  _TableInference({
    required this.round,
    required this.mySeat,
    required this.unseenPieces,
    required this.hardMissing,
    required this.suitAffinity,
    required this.lastOpenedBySeat,
    required this.userProfile,
  });

  final RoundState round;
  final int mySeat;
  final List<DominoPiece> unseenPieces;

  /// Hard-deduced missing numbers per seat from passes and 2p boneyard draws.
  final List<Set<int>> hardMissing;

  /// Soft log-affinity score per seat and number (0..6) inferred from the
  /// player's moves (what they opened, what they avoided) and [userProfile].
  final List<List<double>> suitAffinity;

  /// The most recent outward number deliberately exposed by each seat.
  final List<int?> lastOpenedBySeat;

  final UserPlayProfile? userProfile;

  static _TableInference analyze({
    required RoundState round,
    required int mySeat,
    required List<DominoPiece> myHand,
    required UserPlayProfile? userProfile,
  }) {
    final playerCount = round.playerCount;
    final played = {for (final placed in round.board.line) placed.piece};
    final mine = myHand.toSet();
    final unseen = [
      for (final p in DominoPiece.fullSet())
        if (!played.contains(p) && !mine.contains(p)) p,
    ];

    final hardMissing = List<Set<int>>.generate(playerCount, (_) => <int>{});
    final suitAffinity = List<List<double>>.generate(
      playerCount,
      (_) => List<double>.filled(7, 0.0),
    );
    final lastOpenedBySeat = List<int?>.filled(playerCount, null);

    // 1. Replay drawHistory (2-player mode) and playHistory in chronological
    //    order:
    //    - When seat s draws on (L, R), they lacked both L and R prior to the
    //      draw. Even after drawing until playable, they STILL lack whichever
    //      end they do not play on!
    for (final d in round.drawHistory) {
      hardMissing[d.seat].add(d.leftEnd);
      hardMissing[d.seat].add(d.rightEnd);
    }

    // 2. Analyze every played move's tactical intent.
    for (var i = 0; i < round.playHistory.length; i++) {
      final entry = round.playHistory[i];
      final s = entry.seat;
      final piece = entry.move.piece;
      final prevLeft = entry.prevLeft;
      final prevRight = entry.prevRight;
      final opened = entry.openedEnd;
      final covered = entry.coveredEnd;

      // If this was the forced opening double of round 1, it wasn't a free choice.
      final isForcedOpening = i == 0 && round.openingPiece != null;
      if (!isForcedOpening) {
        lastOpenedBySeat[s] = opened;

        // Choosing to expose `opened` when changing an end signals holding
        // follow-up support in `opened`.
        if (covered != null && opened != covered) {
          suitAffinity[s][opened] += 0.65;
        } else if (prevLeft == null) {
          // Free lead in round 2+: strong signal for both sides of the lead tile!
          suitAffinity[s][piece.low] += 0.75;
          if (!piece.isDouble) {
            suitAffinity[s][piece.high] += 0.75;
          }
        }

        // If two distinct numbers were open on the board (prevLeft != prevRight)
        // and the player chose to cover `covered`, they left the other end
        // untouched. If they repeatedly ignore a high number on the other end,
        // slightly lower their affinity for that other end.
        if (prevLeft != null &&
            prevRight != null &&
            prevLeft != prevRight &&
            covered != null) {
          final untouched = covered == prevLeft ? prevRight : prevLeft;
          if (!piece.hasSide(untouched)) {
            suitAffinity[s][untouched] -= 0.18;
          }
        }
      }

      // In 2-player mode, if seat s drew tiles earlier and then played a drawn
      // tile matching `covered`, we shouldn't mark `opened` as missing anymore
      // because the drawn tile(s) may contain `opened` or other numbers;
      // however, any number they drew on that was NOT covered by their play
      // remains 100% missing!
      if (playerCount == 2 && covered != null) {
        // Keep hard-missing for numbers they never matched; if they just
        // exposed `opened`, they might hold another tile or might not, so
        // keep hard-missing only for numbers != opened.
        hardMissing[s].remove(opened);
      }
    }

    // 3. Apply passHistory (a pass always proves the player holds neither end,
    //    and in 2p a pass only occurs when the boneyard is empty so no future
    //    draws can ever invalidate it).
    for (final p in round.passHistory) {
      hardMissing[p.seat].add(p.leftEnd);
      hardMissing[p.seat].add(p.rightEnd);
    }

    // 4. Blend learned UserPlayProfile into seat 0's suit affinities.
    if (userProfile != null && userProfile.confidence > 0.05) {
      final conf = userProfile.confidence;
      for (var num = 0; num <= 6; num++) {
        final centered = userProfile.numberOpenAffinity[num] - 0.5;
        suitAffinity[0][num] += centered * 1.4 * conf;
      }
      final userLastOpen = lastOpenedBySeat[0];
      if (userLastOpen != null) {
        suitAffinity[0][userLastOpen] +=
            (userProfile.selfSuitKeepPreference - 0.4) * 1.2 * conf;
      }
    }

    return _TableInference(
      round: round,
      mySeat: mySeat,
      unseenPieces: unseen,
      hardMissing: hardMissing,
      suitAffinity: suitAffinity,
      lastOpenedBySeat: lastOpenedBySeat,
      userProfile: userProfile,
    );
  }

  /// Count of unseen tiles (in other hands or boneyard) that contain [number].
  int unseenCountFor(int number) =>
      unseenPieces.where((p) => p.hasSide(number)).length;

  /// Returns the strongest positively signaled suit (0..6) for [seat] that
  /// [seat] is not known to lack, or null if none.
  int? strongestSignaledSuit(int seat) {
    final missing = hardMissing[seat];
    int? bestSuit;
    var bestVal = 0.15;
    for (var num = 0; num <= 6; num++) {
      if (missing.contains(num)) continue;
      if (unseenCountFor(num) == 0) continue;
      final val = suitAffinity[seat][num];
      if (val > bestVal) {
        bestVal = val;
        bestSuit = num;
      }
    }
    return bestSuit ?? lastOpenedBySeat[seat];
  }

  /// Relative weight that [seat] holds a specific unseen [piece].
  double _seatWeightForPiece(int seat, DominoPiece piece) {
    if (seat == mySeat) return 0.0;
    final handSize = round.hands[seat].length;
    if (handSize == 0) return 0.0;
    final missing = hardMissing[seat];
    if (missing.contains(piece.low) || missing.contains(piece.high)) {
      return 0.0;
    }

    var logScore =
        (suitAffinity[seat][piece.low] + suitAffinity[seat][piece.high]) * 0.5;

    // Incorporate user-profile pip & double habits for seat 0:
    if (seat == 0 && userProfile != null && userProfile!.confidence > 0.05) {
      final conf = userProfile!.confidence;
      // If user sheds heavy tiles early and several turns have passed, heavy
      // unseen tiles are slightly less likely to still be sitting in seat 0's hand.
      if (round.playHistory.length >= 6 && piece.pips >= 9) {
        logScore -= (userProfile!.heavyPipPreference - 0.5) * 0.6 * conf;
      }
      if (piece.isDouble && round.board.line.any((pl) => pl.piece.hasSide(piece.low))) {
        logScore -= (userProfile!.doubleShedPreference - 0.5) * 0.7 * conf;
      }
    }

    final clamped = logScore.clamp(-2.5, 2.5);
    return handSize * math.exp(clamped);
  }

  /// Estimated probability (0..1) that [seat] holds the specific unseen [piece].
  double probSeatHoldsPiece(int seat, DominoPiece piece) {
    final wSeat = _seatWeightForPiece(seat, piece);
    if (wSeat <= 0.0) return 0.0;

    var totalWeight = 0.0;
    for (var s = 0; s < round.playerCount; s++) {
      totalWeight += _seatWeightForPiece(s, piece);
    }
    // In 2-player mode, unseen tiles can also be in the boneyard.
    totalWeight += round.boneyard.length.toDouble();
    if (totalWeight <= 0.0) return 0.0;
    return (wSeat / totalWeight).clamp(0.0, 1.0);
  }

  /// Estimated probability (0..1) that [seat] holds AT LEAST ONE tile matching
  /// [number].
  double probSeatHoldsSuit(int seat, int number) {
    if (hardMissing[seat].contains(number) || round.hands[seat].isEmpty) {
      return 0.0;
    }
    final candidates = unseenPieces.where((p) => p.hasSide(number));
    if (candidates.isEmpty) return 0.0;

    var probNone = 1.0;
    for (final tile in candidates) {
      final p = probSeatHoldsPiece(seat, tile);
      probNone *= (1.0 - p);
    }
    return (1.0 - probNone).clamp(0.0, 1.0);
  }

  /// True if at least one opposing seat can plausibly hold a tile matching
  /// [number] given hard pass/draw constraints and remaining unseen tiles.
  bool anyOpponentCanHold(int number) {
    final myTeam = RoundState.teamOf(mySeat, round.playerCount);
    final candidates = unseenPieces.where((p) => p.hasSide(number)).toList();
    if (candidates.isEmpty) return false;

    for (var s = 0; s < round.playerCount; s++) {
      if (RoundState.teamOf(s, round.playerCount) == myTeam) continue;
      if (round.hands[s].isEmpty) continue;
      final missing = hardMissing[s];
      if (missing.contains(number)) continue;
      final canHoldAny = candidates.any(
        (tile) => !missing.contains(tile.low) && !missing.contains(tile.high),
      );
      if (canHoldAny) return true;
    }
    return false;
  }

  /// Estimates the lowest pip total among opposing seats based on their known
  /// hand sizes and the posterior probabilities of unseen tiles.
  double estimatedLowestOpponentPips() {
    if (unseenPieces.isEmpty) return 0.0;
    final avgUnseenPips =
        unseenPieces.fold<int>(0, (sum, p) => sum + p.pips) /
        unseenPieces.length;

    final myTeam = RoundState.teamOf(mySeat, round.playerCount);
    var lowest = double.infinity;

    for (var s = 0; s < round.playerCount; s++) {
      if (RoundState.teamOf(s, round.playerCount) == myTeam) continue;
      final count = round.hands[s].length;
      var weightedPipSum = 0.0;
      var weightSum = 0.0;
      for (final tile in unseenPieces) {
        final w = _seatWeightForPiece(s, tile);
        if (w > 0) {
          weightedPipSum += w * tile.pips;
          weightSum += w;
        }
      }
      final expectedPerTile = weightSum > 0
          ? (weightedPipSum / weightSum)
          : avgUnseenPips;
      final estHandPips = count * expectedPerTile;
      if (estHandPips < lowest) lowest = estHandPips;
    }

    return lowest.isFinite ? lowest : avgUnseenPips * 2;
  }
}
