import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

enum RoomStatus { created, waiting, playing, finished }

class Room {
  final String code;
  final String game;
  final int boardSize;
  final DateTime createdAt;

  RoomStatus status = RoomStatus.created;
  WebSocketSink? host;
  WebSocketSink? joiner;
  DateTime hostLastPing = DateTime.now();
  DateTime joinerLastPing = DateTime.now();
  Timer? disconnectTimer;
  Timer? expireTimer;

  // Game state for validation
  List<int> board = [];
  int currentPlayer = 1; // 1 = black, 2 = white
  int moveCount = 0;
  final List<_HistoryEntry> history = [];

  // Undo tracking
  bool undoRequested = false;
  String? undoRequestedBy;

  // New game tracking
  bool newGameRequested = false;
  String? newGameRequestedBy;

  Room({required this.code, required this.game, required this.boardSize})
      : createdAt = DateTime.now() {
    final total = boardSize * boardSize;
    board = List.filled(total, 0);
  }

  bool isHost(WebSocketSink sink) => host == sink;
  bool isJoiner(WebSocketSink sink) => joiner == sink;
  bool get isFull => host != null && joiner != null;

  String playerLabel(WebSocketSink sink) {
    if (sink == host) return 'black';
    if (sink == joiner) return 'white';
    return 'unknown';
  }

  String opponentLabel(WebSocketSink sink) {
    if (sink == host) return 'white';
    if (sink == joiner) return 'black';
    return 'unknown';
  }

  void send(WebSocketSink? sink, Map<String, dynamic> msg) {
    sink?.add(jsonEncode(msg));
  }

  void broadcast(Map<String, dynamic> msg) {
    final encoded = jsonEncode(msg);
    host?.add(encoded);
    joiner?.add(encoded);
  }

  void sendToOpponent(WebSocketSink player, Map<String, dynamic> msg) {
    if (player == host) {
      send(joiner, msg);
    } else if (player == joiner) {
      send(host, msg);
    }
  }

  /// Apply a move to the server-side board for validation.
  void applyMove(int index, int color) {
    history.add(_HistoryEntry(index: index, oldValue: board[index]));
    board[index] = color;
    moveCount++;
  }

  /// Undo the last N moves (2 = one full turn).
  void undoMoves(int count) {
    for (int i = 0; i < count && history.isNotEmpty; i++) {
      final entry = history.removeLast();
      board[entry.index] = entry.oldValue;
      if (moveCount > 0) moveCount--;
    }
  }

  void resetForNewGame() {
    board = List.filled(boardSize * boardSize, 0);
    currentPlayer = 1;
    moveCount = 0;
    history.clear();
    undoRequested = false;
    undoRequestedBy = null;
    newGameRequested = false;
    newGameRequestedBy = null;
    status = RoomStatus.playing;
  }
}

class _HistoryEntry {
  final int index;
  final int oldValue;
  _HistoryEntry({required this.index, required this.oldValue});
}

/// Generate a readable 4-letter room code (no I/O to avoid confusion).
String generateRoomCode({Random? rng}) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  final r = rng ?? Random();
  return String.fromCharCodes(
    List.generate(4, (_) => chars.codeUnitAt(r.nextInt(chars.length))),
  );
}
