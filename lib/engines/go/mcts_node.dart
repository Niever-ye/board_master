import 'dart:math' as math;

class MctsNode {
  final int moveIndex;
  final int stonePlayed; // 1=black, 2=white
  int visits;
  double wins; // from the perspective of the player who made the move here

  MctsNode? parent;
  List<MctsNode> children;
  List<int> unexploredMoves;

  MctsNode({
    required this.moveIndex,
    required this.stonePlayed,
    this.visits = 0,
    this.wins = 0.0,
    this.parent,
    List<MctsNode>? children,
    List<int>? unexploredMoves,
  })  : children = children ?? [],
        unexploredMoves = unexploredMoves ?? [];

  bool get isLeaf => children.isEmpty;
  bool get isFullyExpanded => unexploredMoves.isEmpty;

  double uctValue(int parentVisits, double c) {
    if (visits == 0) return double.infinity;
    return wins / visits + c * math.sqrt(math.log(parentVisits) / visits);
  }

  MctsNode bestChild(double c) {
    MctsNode best = children.first;
    double bestValue = double.negativeInfinity;
    for (final child in children) {
      final val = child.uctValue(visits, c);
      if (val > bestValue) {
        bestValue = val;
        best = child;
      }
    }
    return best;
  }

  MctsNode mostVisitedChild() {
    MctsNode best = children.first;
    for (final child in children) {
      if (child.visits > best.visits) {
        best = child;
      }
    }
    return best;
  }
}
