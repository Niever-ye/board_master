import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:board_master/engines/chess/chess_engine.dart';
import 'package:board_master/engines/go/go_engine.dart';
import 'package:board_master/engines/gomoku/gomoku_engine.dart';
import 'package:board_master/network/connection_service.dart';
import 'package:board_master/state/chess_game_notifier.dart';
import 'package:board_master/state/go_game_notifier.dart';
import 'package:board_master/state/gomoku_game_notifier.dart';
import 'package:board_master/state/record_browser_notifier.dart';
import 'package:board_master/storage/record_dao.dart';

final goEngineProvider = Provider<GoEngine>((ref) => GoEngine());
final chessEngineProvider = Provider<ChessEngine>((ref) => ChessEngine());
final gomokuEngineProvider = Provider<GomokuEngine>((ref) => GomokuEngine());
final recordDaoProvider = Provider<RecordDao>((ref) => RecordDao());

final connectionServiceProvider = Provider<GameConnectionService>((ref) {
  return GameConnectionService();
});

final goGameProvider =
    StateNotifierProvider<GoGameNotifier, GoGameState>((ref) {
  return GoGameNotifier(ref.read(goEngineProvider));
});

final chessGameProvider =
    StateNotifierProvider<ChessGameNotifier, ChessGameState>((ref) {
  return ChessGameNotifier(ref.read(chessEngineProvider));
});

final gomokuGameProvider =
    StateNotifierProvider<GomokuGameNotifier, GomokuGameState>((ref) {
  return GomokuGameNotifier(ref.read(gomokuEngineProvider));
});

final recordBrowserProvider =
    StateNotifierProvider<RecordBrowserNotifier, RecordBrowserState>((ref) {
  return RecordBrowserNotifier(ref.read(recordDaoProvider));
});
