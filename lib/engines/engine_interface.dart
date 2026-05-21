import 'package:board_master/core/types.dart';

class EngineResult {
  final int? row;    // Go: destination row; Chess: fromIdx
  final int? col;    // Go: destination col; Chess: toIdx
  final bool isPass;

  const EngineResult({this.row, this.col, this.isPass = false});
}

abstract class EngineInterface {
  Future<EngineResult> findBestMove(
    List<int> board,
    int size,
    int currentColor,
    int koPoint,
    Difficulty difficulty,
  );
}
