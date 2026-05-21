class GoConstants {
  static const int defaultBoardSize = 19;
  static const List<int> availableSizes = [9, 13, 19];
  static const double defaultKomi = 6.5;

  // Star points for 19x19
  static const List<(int, int)> starPoints19 = [
    (3, 3), (3, 9), (3, 15),
    (9, 3), (9, 9), (9, 15),
    (15, 3), (15, 9), (15, 15),
  ];

  // Star points for 13x13
  static const List<(int, int)> starPoints13 = [
    (3, 3), (3, 9),
    (6, 6),
    (9, 3), (9, 9),
  ];

  // Star points for 9x9
  static const List<(int, int)> starPoints9 = [
    (2, 2), (2, 6),
    (4, 4),
    (6, 2), (6, 6),
  ];
}

class ChessConstants {
  static const int rows = 10;
  static const int cols = 9;

  static const Map<String, int> pieceValues = {
    'general': 10000,
    'chariot': 900,
    'cannon': 450,
    'horse': 400,
    'elephant': 200,
    'advisor': 200,
    'soldier': 100,
  };
}

class AiConstants {
  // Go MCTS
  static const int easyIterations = 1000;
  static const int mediumIterations = 10000;
  static const int hardIterations = 30000;

  // Chess search depth
  static const int easyDepth = 2;
  static const int mediumDepth = 6;
  static const int hardDepth = 20;

  // Time limits in seconds
  static const double easyTimeLimit = 0.3;
  static const double mediumTimeLimit = 1.0;
  static const double hardTimeLimit = 5.0;
}
