import 'dart:io';

import 'package:board_master_server/server.dart' as server;

void main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  print('Starting Board Master server on port $port...');
  await server.start(port);
}
