import 'dart:math';

/// Zobrist hashing for position lookup.
class Zobrist {
  static final List<int> _table = _generateTable();
  static final Random _rng = Random(42);

  static List<int> _generateTable() {
    // 14 piece types (7 red + 7 black) * 90 squares
    final table = List<int>.filled(14 * 90, 0);
    for (int i = 0; i < table.length; i++) {
      table[i] = _rng.nextInt(1 << 30) << 1;
    }
    return table;
  }

  static int hash(List<int> board) {
    int h = 0;
    for (int i = 0; i < board.length; i++) {
      final piece = board[i];
      if (piece == 0) continue;
      // Map piece to 0-13 (red 1-7 -> 0-6, black 11-17 -> 7-13)
      final pIdx = piece > 10 ? piece - 4 : piece - 1;
      h ^= _table[pIdx * 90 + i];
    }
    return h;
  }

  /// Incrementally update hash: remove old hash, add new.
  static int update(int hash, int piece, int fromIdx, int toIdx, int captured) {
    if (captured != 0) {
      final cpIdx = captured > 10 ? captured - 4 : captured - 1;
      hash ^= _table[cpIdx * 90 + toIdx];
    }
    final pIdx = piece > 10 ? piece - 4 : piece - 1;
    hash ^= _table[pIdx * 90 + fromIdx];
    hash ^= _table[pIdx * 90 + toIdx];
    return hash;
  }
}

/// Transposition table entry.
class TTEntry {
  final int hash;
  final int depth;
  final int score;
  final int flag; // 0=EXACT, 1=LOWER_BOUND, 2=UPPER_BOUND
  final int bestFrom;
  final int bestTo;

  const TTEntry({
    required this.hash,
    required this.depth,
    required this.score,
    required this.flag,
    this.bestFrom = -1,
    this.bestTo = -1,
  });
}

/// Simple transposition table with replacement scheme.
class TranspositionTable {
  static const int _size = 1 << 18; // 262k entries
  final List<TTEntry?> _entries = List.filled(_size, null);

  TTEntry? probe(int hash) {
    return _entries[hash & (_size - 1)];
  }

  void store(TTEntry entry) {
    _entries[entry.hash & (_size - 1)] = entry;
  }

  void clear() {
    for (int i = 0; i < _size; i++) {
      _entries[i] = null;
    }
  }
}
