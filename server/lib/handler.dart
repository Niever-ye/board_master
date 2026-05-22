import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'room.dart';
import 'room_manager.dart';
import 'validation/go_validator.dart';
import 'validation/chess_validator.dart';
import 'validation/gomoku_validator.dart';

void handleConnection(WebSocketChannel channel, RoomManager manager) {
  String? currentRoom;
  WebSocketSink? mySink;

  // Heartbeat timer
  Timer? heartbeatTimer;

  void send(Map<String, dynamic> msg) {
    mySink?.add(jsonEncode(msg));
  }

  // Start heartbeat - send pings every 15 seconds
  heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
    mySink?.add(jsonEncode({'type': 'pong'}));
  });

  channel.stream.listen(
    (data) {
      try {
        final msg = jsonDecode(data as String) as Map<String, dynamic>;
        final type = msg['type'] as String?;
        if (type == null) return;

        mySink ??= channel.sink;

        switch (type) {
          case 'ping':
            // Just update last ping time
            if (currentRoom != null && mySink != null) {
              manager.updatePing(currentRoom!, mySink!);
            }
            break;

          case 'create_room':
            _handleCreateRoom(msg, manager, channel.sink, (room, code) {
              currentRoom = code;
              mySink = channel.sink;
              send({'type': 'room_created', 'code': code, 'game': room.game,
                  'your_color': 'black', 'board_size': room.boardSize});
            });

          case 'join_room':
            _handleJoinRoom(msg, manager, channel.sink, (room, code) {
              currentRoom = code;
              mySink = channel.sink;
              send({'type': 'room_joined', 'code': code, 'game': room.game,
                  'your_color': 'white', 'board_size': room.boardSize});
              room.send(room.host, {'type': 'opponent_joined'});
              room.broadcast({'type': 'game_started'});
            });

          case 'move':
            _handleMove(msg, currentRoom, manager, mySink!);

          case 'pass':
            _handlePass(currentRoom, manager, mySink!);

          case 'resign':
            _handleResign(currentRoom, manager, mySink!);

          case 'undo_request':
            _handleUndoRequest(currentRoom, manager, mySink!);

          case 'undo_accept':
            _handleUndoAccept(currentRoom, manager);

          case 'undo_reject':
            _handleUndoReject(currentRoom, manager);

          case 'new_game_request':
            _handleNewGameRequest(currentRoom, manager, mySink!);

          case 'new_game_accept':
            _handleNewGameAccept(currentRoom, manager);

          case 'reconnect':
            _handleReconnect(msg, manager, channel.sink, (room, code, role) {
              currentRoom = code;
              mySink = channel.sink;
              manager.handleReconnect(code, channel.sink, role);
              send({'type': 'reconnected', 'code': code, 'game': room.game,
                  'your_color': role == 'host' ? 'black' : 'white',
                  'board_size': room.boardSize});
            });
        }
      } catch (e) {
        send({'type': 'error', 'message': 'Invalid message format'});
      }
    },
    onDone: () {
      heartbeatTimer?.cancel();
      if (currentRoom != null && mySink != null) {
        manager.handleDisconnect(currentRoom!, mySink!);
      }
    },
    onError: (error) {
      heartbeatTimer?.cancel();
      if (currentRoom != null && mySink != null) {
        manager.handleDisconnect(currentRoom!, mySink!);
      }
    },
  );
}

void _handleCreateRoom(Map<String, dynamic> msg, RoomManager manager,
    WebSocketSink sink, void Function(Room, String) onSuccess) {
  final game = msg['game'] as String?;
  if (game == null || !['go', 'chess', 'gomoku'].contains(game)) {
    sink.add(jsonEncode({'type': 'error', 'message': 'Invalid game type'}));
    return;
  }
  final boardSize = msg['board_size'] as int? ?? 19;
  if (boardSize < 5 || boardSize > 19) {
    sink.add(jsonEncode({'type': 'error', 'message': 'Invalid board size'}));
    return;
  }

  final room = manager.createRoom(game, sink, boardSize: boardSize);
  if (room == null) {
    sink.add(jsonEncode({'type': 'error', 'message': 'Server full, try again later'}));
    return;
  }

  onSuccess(room, room.code);
}

void _handleJoinRoom(Map<String, dynamic> msg, RoomManager manager,
    WebSocketSink sink, void Function(Room, String) onSuccess) {
  final code = (msg['code'] as String?)?.toUpperCase();
  if (code == null || code.isEmpty) {
    sink.add(jsonEncode({'type': 'error', 'message': 'Room code required'}));
    return;
  }

  final room = manager.joinRoom(code, sink);
  if (room == null) {
    sink.add(jsonEncode({'type': 'error', 'message': 'Room not found or full'}));
    return;
  }

  onSuccess(room, code);
}

void _handleMove(Map<String, dynamic> msg, String? currentRoom,
    RoomManager manager, WebSocketSink sink) {
  if (currentRoom == null) return;
  final room = manager.getRoom(currentRoom);
  if (room == null || room.status != RoomStatus.playing) return;

  // Check it's this player's turn
  final expectedColor = room.playerLabel(sink);
  if ((expectedColor == 'black' && room.currentPlayer != 1) ||
      (expectedColor == 'white' && room.currentPlayer != 2)) {
    sink.add(jsonEncode({'type': 'error', 'message': 'Not your turn'}));
    return;
  }

  final row = msg['row'] as int?;
  final col = msg['col'] as int?;
  if (row == null || col == null) return;

  final index = row * room.boardSize + col;

  // Validate move
  final valid = _validateMove(room.game, room.board, room.boardSize, index, expectedColor == 'black' ? 1 : 2);
  if (!valid) {
    sink.add(jsonEncode({'type': 'error', 'message': 'Illegal move'}));
    return;
  }

  // Apply move to server state
  room.applyMove(index, expectedColor == 'black' ? 1 : 2);
  room.currentPlayer = room.currentPlayer == 1 ? 2 : 1;

  // Relay to opponent
  room.sendToOpponent(sink, {'type': 'move', 'row': row, 'col': col});

  // Check for game over
  final result = _checkGameOver(room.game, room.board, room.boardSize, row, col,
      expectedColor == 'black' ? 1 : 2);
  if (result != null) {
    room.broadcast({'type': 'game_over', 'reason': 'normal', 'winner': result});
    room.status = RoomStatus.finished;
  }
}

void _handlePass(String? currentRoom, RoomManager manager, WebSocketSink sink) {
  if (currentRoom == null) return;
  final room = manager.getRoom(currentRoom);
  if (room == null || room.status != RoomStatus.playing) return;
  if (room.game != 'go') return;

  room.currentPlayer = room.currentPlayer == 1 ? 2 : 1;
  room.sendToOpponent(sink, {'type': 'pass'});
}

void _handleResign(String? currentRoom, RoomManager manager, WebSocketSink sink) {
  if (currentRoom == null) return;
  final room = manager.getRoom(currentRoom);
  if (room == null || room.status != RoomStatus.playing) return;

  final winner = room.isHost(sink) ? 'white' : 'black';
  room.broadcast({'type': 'game_over', 'reason': 'resign', 'winner': winner});
  room.status = RoomStatus.finished;
}

void _handleUndoRequest(String? currentRoom, RoomManager manager, WebSocketSink sink) {
  if (currentRoom == null) return;
  final room = manager.getRoom(currentRoom);
  if (room == null || room.status != RoomStatus.playing) return;
  if (room.undoRequested) return;

  room.undoRequested = true;
  room.undoRequestedBy = room.playerLabel(sink);
  room.sendToOpponent(sink, {'type': 'undo_request'});
}

void _handleUndoAccept(String? currentRoom, RoomManager manager) {
  if (currentRoom == null) return;
  final room = manager.getRoom(currentRoom);
  if (room == null || !room.undoRequested) return;

  room.undoMoves(2);
  room.currentPlayer = room.currentPlayer == 1 ? 2 : 1;
  room.undoRequested = false;
  room.undoRequestedBy = null;
  room.broadcast({'type': 'undo_accepted', 'count': 2});
}

void _handleUndoReject(String? currentRoom, RoomManager manager) {
  if (currentRoom == null) return;
  final room = manager.getRoom(currentRoom);
  if (room == null) return;

  room.undoRequested = false;
  room.undoRequestedBy = null;
  room.broadcast({'type': 'undo_rejected'});
}

void _handleNewGameRequest(String? currentRoom, RoomManager manager, WebSocketSink sink) {
  if (currentRoom == null) return;
  final room = manager.getRoom(currentRoom);
  if (room == null || room.status != RoomStatus.finished) return;
  if (room.newGameRequested) return;

  room.newGameRequested = true;
  room.newGameRequestedBy = room.playerLabel(sink);
  room.sendToOpponent(sink, {'type': 'new_game_request'});
}

void _handleNewGameAccept(String? currentRoom, RoomManager manager) {
  if (currentRoom == null) return;
  final room = manager.getRoom(currentRoom);
  if (room == null || !room.newGameRequested) return;

  final wasHost = room.newGameRequestedBy == 'black';
  room.resetForNewGame();
  room.broadcast({
    'type': 'new_game_started',
    'your_color': wasHost ? 'white' : 'black',
  });
}

void _handleReconnect(Map<String, dynamic> msg, RoomManager manager,
    WebSocketSink sink, void Function(Room, String, String) onSuccess) {
  final code = (msg['code'] as String?)?.toUpperCase();
  final role = msg['role'] as String?;
  if (code == null || role == null) return;

  final room = manager.getRoom(code);
  if (room == null) return;

  onSuccess(room, code, role);
}

bool _validateMove(String game, List<int> board, int size, int index, int color) {
  if (index < 0 || index >= board.length) return false;
  if (board[index] != 0) return false;

  switch (game) {
    case 'go':
      return GoValidator.isLegal(board, size, index, color);
    case 'chess':
      return ChessValidator.isLegal(board, index, color);
    case 'gomoku':
      return GomokuValidator.isLegal(board, index);
    default:
      return false;
  }
}

String? _checkGameOver(String game, List<int> board, int size, int lastRow, int lastCol, int color) {
  switch (game) {
    case 'gomoku':
      return GomokuValidator.checkWin(board, size, lastRow, lastCol, color);
    default:
      return null;
  }
}
