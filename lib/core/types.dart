enum GameType { go, chess }

enum Stone { empty, black, white }

enum ChessColor { red, black }

enum PieceType {
  general,   // 将/帅
  advisor,   // 士/仕
  elephant,  // 象/相
  horse,     // 马
  chariot,   // 车
  cannon,    // 炮
  soldier,   // 兵/卒
}

enum Difficulty { easy, medium, hard }

enum GoGameStatus { playing, blackWins, whiteWins, draw }

enum ChessGameStatus { playing, redWins, blackWins, draw }
