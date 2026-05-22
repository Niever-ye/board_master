import 'package:flutter/foundation.dart';

enum ConnectionPhase { disconnected, connecting, connected, inRoom, inGame }

@immutable
class ConnectionState {
  final ConnectionPhase phase;
  final String? roomCode;
  final String? myColor;
  final String? game;
  final int? boardSize;
  final bool opponentConnected;
  final bool opponentDisconnected;
  final String? lastError;

  const ConnectionState({
    this.phase = ConnectionPhase.disconnected,
    this.roomCode,
    this.myColor,
    this.game,
    this.boardSize,
    this.opponentConnected = false,
    this.opponentDisconnected = false,
    this.lastError,
  });

  ConnectionState copyWith({
    ConnectionPhase? phase,
    String? roomCode,
    String? myColor,
    String? game,
    int? boardSize,
    bool? opponentConnected,
    bool? opponentDisconnected,
    String? lastError,
    bool clearError = false,
  }) {
    return ConnectionState(
      phase: phase ?? this.phase,
      roomCode: roomCode ?? this.roomCode,
      myColor: myColor ?? this.myColor,
      game: game ?? this.game,
      boardSize: boardSize ?? this.boardSize,
      opponentConnected: opponentConnected ?? this.opponentConnected,
      opponentDisconnected: opponentDisconnected ?? this.opponentDisconnected,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}
