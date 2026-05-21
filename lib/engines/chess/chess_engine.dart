import 'package:board_master/core/constants.dart';
import 'package:board_master/core/types.dart';
import 'package:board_master/engines/engine_interface.dart';
import 'package:board_master/engines/chess/searcher.dart';
import 'package:board_master/engines/chess/transposition_table.dart';

/// Chinese Chess engine using alpha-beta search with iterative deepening.
/// Runs on the main isolate (web-compatible).
class ChessEngine implements EngineInterface {

  @override
  Future<EngineResult> findBestMove(
    List<int> board,
    int size,
    int currentColor,
    int koPoint,
    Difficulty difficulty,
  ) async {
    final aiColor = currentColor == 1 ? ChessColor.red : ChessColor.black;

    int maxDepth;
    double timeLimit;

    switch (difficulty) {
      case Difficulty.easy:
        maxDepth = AiConstants.easyDepth;
        timeLimit = AiConstants.easyTimeLimit;
        break;
      case Difficulty.medium:
        maxDepth = AiConstants.mediumDepth;
        timeLimit = AiConstants.mediumTimeLimit;
        break;
      case Difficulty.hard:
        maxDepth = AiConstants.hardDepth;
        timeLimit = AiConstants.hardTimeLimit;
        break;
    }

    final params = _EngineParams(
      board: List<int>.from(board),
      aiColor: aiColor,
      maxDepth: maxDepth,
      timeLimitSec: timeLimit,
    );

    // Run search synchronously (no Isolate — Flutter Web doesn't support isolates)
    final result = _runSearch(params);

    if (result.$1 < 0) return const EngineResult(isPass: true);

    // row = fromIdx, col = toIdx (for chess)
    return EngineResult(row: result.$1, col: result.$2);
  }
}

class _EngineParams {
  final List<int> board;
  final ChessColor aiColor;
  final int maxDepth;
  final double timeLimitSec;

  _EngineParams({
    required this.board,
    required this.aiColor,
    required this.maxDepth,
    required this.timeLimitSec,
  });
}

(int, int) _runSearch(_EngineParams params) {
  final tt = TranspositionTable();
  final searchParams = SearchParams(
    board: params.board,
    aiColor: params.aiColor,
    maxDepth: params.maxDepth,
    timeLimitSec: params.timeLimitSec,
    tt: tt,
  );

  final result = search(searchParams);
  return (result.bestFrom, result.bestTo);
}
