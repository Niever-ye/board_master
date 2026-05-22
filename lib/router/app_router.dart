import 'package:go_router/go_router.dart';
import 'package:board_master/ui/home/home_screen.dart';
import 'package:board_master/ui/go/go_board_screen.dart';
import 'package:board_master/ui/chess/chess_board_screen.dart';
import 'package:board_master/ui/gomoku/gomoku_board_screen.dart';
import 'package:board_master/ui/records/record_browser_screen.dart';
import 'package:board_master/ui/settings/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/go',
      builder: (context, state) => const GoBoardScreen(),
    ),
    GoRoute(
      path: '/chess',
      builder: (context, state) => const ChessBoardScreen(),
    ),
    GoRoute(
      path: '/gomoku',
      builder: (context, state) => const GomokuBoardScreen(),
    ),
    GoRoute(
      path: '/records',
      builder: (context, state) => const RecordBrowserScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
