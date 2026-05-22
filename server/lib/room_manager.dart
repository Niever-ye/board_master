import 'dart:async';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'room.dart';

class RoomManager {
  final Map<String, Room> _rooms = {};
  int _counter = 0;

  static const maxRooms = 200;
  static const roomTTL = Duration(minutes: 30);
  static const waitingTTL = Duration(minutes: 5);

  Room? createRoom(String game, WebSocketSink hostSink, {int boardSize = 19}) {
    _cleanupIfNeeded();

    if (_rooms.length >= maxRooms) return null;

    String code;
    int attempts = 0;
    do {
      code = generateRoomCode(rng: Random(_counter++));
      attempts++;
      if (attempts > 20) return null;
    } while (_rooms.containsKey(code));

    final room = Room(code: code, game: game, boardSize: boardSize);
    room.host = hostSink;
    room.status = RoomStatus.created;
    room.expireTimer = Timer(waitingTTL, () {
      if (room.status == RoomStatus.created) {
        _removeRoom(code);
      }
    });

    _rooms[code] = room;
    return room;
  }

  Room? joinRoom(String code, WebSocketSink joinerSink) {
    final room = _rooms[code];
    if (room == null) return null;
    if (room.status != RoomStatus.created) return null;
    if (room.joiner != null) return null;

    room.joiner = joinerSink;
    room.status = RoomStatus.playing;
    room.expireTimer?.cancel();

    return room;
  }

  Room? getRoom(String code) => _rooms[code];

  void handleDisconnect(String code, WebSocketSink sink) {
    final room = _rooms[code];
    if (room == null) return;

    if (room.status != RoomStatus.playing && room.status != RoomStatus.finished) {
      _removeRoom(code);
      return;
    }

    final other = room.isHost(sink) ? room.joiner : room.host;
    if (room.status == RoomStatus.finished) {
      _removeRoom(code);
      return;
    }

    room.send(other, {'type': 'opponent_disconnected'});

    room.disconnectTimer?.cancel();
    room.disconnectTimer = Timer(const Duration(seconds: 30), () {
      room.send(other, {
        'type': 'game_over',
        'reason': 'disconnect',
        'winner': room.isHost(sink) ? 'white' : 'black',
      });
      room.status = RoomStatus.finished;
    });
  }

  void handleReconnect(String code, WebSocketSink newSink, String role) {
    final room = _rooms[code];
    if (room == null) return;

    room.disconnectTimer?.cancel();
    room.disconnectTimer = null;

    if (role == 'host') {
      room.host = newSink;
    } else {
      room.joiner = newSink;
    }

    room.send(newSink, {'type': 'opponent_reconnected'});
    room.sendToOpponent(newSink, {'type': 'opponent_reconnected'});
  }

  void updatePing(String code, WebSocketSink sink) {
    final room = _rooms[code];
    if (room == null) return;

    if (room.isHost(sink)) {
      room.hostLastPing = DateTime.now();
    } else if (room.isJoiner(sink)) {
      room.joinerLastPing = DateTime.now();
    }
  }

  void removeExpiredRooms() {
    final now = DateTime.now();
    _rooms.removeWhere((code, room) {
      if (now.difference(room.createdAt) > roomTTL) return true;
      if (room.status == RoomStatus.created &&
          now.difference(room.createdAt) > waitingTTL) return true;
      if (room.status == RoomStatus.finished) {
        room.expireTimer?.cancel();
        room.disconnectTimer?.cancel();
        return true;
      }
      return false;
    });
  }

  void _removeRoom(String code) {
    final room = _rooms[code];
    if (room != null) {
      room.expireTimer?.cancel();
      room.disconnectTimer?.cancel();
      room.send(room.host, {'type': 'room_closed'});
      room.send(room.joiner, {'type': 'room_closed'});
    }
    _rooms.remove(code);
  }

  void _cleanupIfNeeded() {
    if (_rooms.length >= maxRooms) {
      removeExpiredRooms();
    }
  }
}

