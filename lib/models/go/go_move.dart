import 'package:board_master/core/types.dart';

class GoMove {
  final Stone stone;
  final int? row;
  final int? col;
  final bool isPass;
  final bool isResign;
  final int moveNumber;

  const GoMove({
    required this.stone,
    this.row,
    this.col,
    this.isPass = false,
    this.isResign = false,
    required this.moveNumber,
  });

  bool get isPlacement => !isPass && !isResign && row != null && col != null;

  @override
  String toString() {
    if (isPass) return '${stone.name} passes';
    if (isResign) return '${stone.name} resigns';
    return '${stone.name} ($row,$col)';
  }
}
