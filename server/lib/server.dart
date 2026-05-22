import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';

import 'handler.dart';
import 'room_manager.dart';

Future<void> start(int port) async {
  final manager = RoomManager();

  final app = Router()
    ..get('/health', (req) => Response.ok('ok'))
    ..get('/ws', webSocketHandler((webSocket, _) {
        handleConnection(webSocket, manager);
      }));

  final handler = Pipeline()
      .addMiddleware(_cors())
      .addHandler(app.call);

  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('Server listening on http://localhost:${server.port}');

  // Cleanup expired rooms every 30 seconds
  Timer.periodic(const Duration(seconds: 30), (_) {
    manager.removeExpiredRooms();
  });
}

Middleware _cors() {
  return (Handler handler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }
      final response = await handler(request);
      return response.change(headers: _corsHeaders);
    };
  };
}

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};
