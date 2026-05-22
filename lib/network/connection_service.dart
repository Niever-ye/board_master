import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'connection_state.dart';

/// Manages the WebSocket connection to the Board Master relay server.
class GameConnectionService {
  // Configurable server URL
  static const defaultServerUrl = 'wss://boardmaster-production-4b5a.up.railway.app/ws';

  final String serverUrl;
  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  bool _disposed = false;

  // Connection state
  final _stateNotifier = ValueNotifier<ConnectionState>(const ConnectionState());
  ValueListenable<ConnectionState> get state => _stateNotifier;

  ConnectionState get currentState => _stateNotifier.value;

  // Callbacks for game notifiers
  void Function(int row, int col)? onOpponentMove;
  void Function()? onOpponentPass;
  void Function()? onOpponentResign;
  void Function()? onGameOver;
  void Function()? onUndoRequested;
  void Function()? onUndoAccepted;
  void Function()? onUndoRejected;
  void Function()? onNewGameRequested;
  void Function(String yourColor)? onNewGameStarted;
  void Function()? onOpponentDisconnected;
  void Function()? onOpponentReconnected;

  GameConnectionService({this.serverUrl = defaultServerUrl});

  /// Connect and create a new room.
  Future<String> createRoom(String game, {int boardSize = 19}) async {
    _ensureConnected();
    _send({'type': 'create_room', 'game': game, 'board_size': boardSize});

    final code = await _waitForMessage((msg) {
      if (msg['type'] == 'room_created') {
        _updateState(ConnectionState(
          phase: ConnectionPhase.inRoom,
          roomCode: msg['code'] as String,
          myColor: msg['your_color'] as String,
          game: game,
          boardSize: boardSize,
        ));
        _startHeartbeat();
        return msg['code'] as String;
      }
      if (msg['type'] == 'error') {
        throw Exception(msg['message'] as String);
      }
      return null;
    });

    return code;
  }

  /// Connect and join an existing room.
  Future<void> joinRoom(String code) async {
    _ensureConnected();
    _send({'type': 'join_room', 'code': code.toUpperCase()});

    await _waitForMessage((msg) {
      if (msg['type'] == 'room_joined') {
        _updateState(ConnectionState(
          phase: ConnectionPhase.inRoom,
          roomCode: code,
          myColor: msg['your_color'] as String,
          game: msg['game'] as String,
          boardSize: msg['board_size'] as int,
        ));
        _startHeartbeat();
        return true;
      }
      if (msg['type'] == 'error') {
        throw Exception(msg['message'] as String);
      }
      return null;
    });
  }

  void sendMove(int row, int col) {
    _send({'type': 'move', 'row': row, 'col': col});
  }

  void sendPass() {
    _send({'type': 'pass'});
  }

  void sendResign() {
    _send({'type': 'resign'});
  }

  void requestUndo() {
    _send({'type': 'undo_request'});
  }

  void acceptUndo() {
    _send({'type': 'undo_accept'});
  }

  void rejectUndo() {
    _send({'type': 'undo_reject'});
  }

  void requestNewGame() {
    _send({'type': 'new_game_request'});
  }

  void acceptNewGame() {
    _send({'type': 'new_game_accept'});
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _updateState(const ConnectionState());
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _stateNotifier.dispose();
  }

  void _ensureConnected() {
    if (_channel != null) return;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
      _updateState(ConnectionState(phase: ConnectionPhase.connecting));

      _channel!.stream.listen(
        (data) {
          final msg = jsonDecode(data as String) as Map<String, dynamic>;
          _handleMessage(msg);
        },
        onDone: () {
          _handleDisconnect();
        },
        onError: (error) {
          _handleDisconnect();
        },
      );
    } catch (e) {
      _updateState(ConnectionState(
        phase: ConnectionPhase.disconnected,
        lastError: 'Failed to connect: $e',
      ));
      rethrow;
    }
  }

  void _handleMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'opponent_joined':
        _updateState(currentState.copyWith(opponentConnected: true));
        break;

      case 'game_started':
        _updateState(ConnectionState(
          phase: ConnectionPhase.inGame,
          roomCode: currentState.roomCode,
          myColor: currentState.myColor,
          game: currentState.game,
          boardSize: currentState.boardSize,
          opponentConnected: true,
        ));
        break;

      case 'move':
        final row = msg['row'] as int?;
        final col = msg['col'] as int?;
        if (row != null && col != null) {
          onOpponentMove?.call(row, col);
        }
        break;

      case 'pass':
        onOpponentPass?.call();
        break;

      case 'game_over':
        onGameOver?.call();
        break;

      case 'undo_request':
        onUndoRequested?.call();
        break;

      case 'undo_accepted':
        onUndoAccepted?.call();
        break;

      case 'undo_rejected':
        onUndoRejected?.call();
        break;

      case 'new_game_request':
        onNewGameRequested?.call();
        break;

      case 'new_game_started':
        final color = msg['your_color'] as String?;
        // swap colors for the player who was host in previous game
        _updateState(currentState.copyWith(myColor: color));
        onNewGameStarted?.call(color ?? 'black');
        break;

      case 'opponent_disconnected':
        _updateState(currentState.copyWith(opponentDisconnected: true));
        onOpponentDisconnected?.call();
        break;

      case 'opponent_reconnected':
        _updateState(currentState.copyWith(opponentDisconnected: false));
        onOpponentReconnected?.call();
        break;

      case 'error':
        _updateState(currentState.copyWith(lastError: msg['message'] as String));
        break;
    }
  }

  void _handleDisconnect() {
    _heartbeatTimer?.cancel();
    _channel = null;
    _updateState(const ConnectionState(phase: ConnectionPhase.disconnected));
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _send({'type': 'ping'});
    });
  }

  void _send(Map<String, dynamic> msg) {
    if (_channel == null) return;
    try {
      _channel!.sink.add(jsonEncode(msg));
    } catch (_) {}
  }

  Future<T> _waitForMessage<T>(T? Function(Map<String, dynamic>) matcher) {
    final completer = Completer<T>();
    late StreamSubscription sub;
    sub = _channel!.stream.listen(
      (data) {
        try {
          final msg = jsonDecode(data as String) as Map<String, dynamic>;
          final result = matcher(msg);
          if (result != null) {
            sub.cancel();
            completer.complete(result);
          }
        } catch (e) {
          sub.cancel();
          completer.completeError(e);
        }
      },
      onError: (e) {
        sub.cancel();
        completer.completeError(e);
      },
    );
    return completer.future;
  }

  void _updateState(ConnectionState newState) {
    if (_disposed) return;
    _stateNotifier.value = newState;
  }
}
