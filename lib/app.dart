import 'package:flutter/material.dart';
import 'package:board_master/router/app_router.dart';
import 'package:board_master/ui/theme.dart';

class BoardMasterApp extends StatelessWidget {
  const BoardMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Board Master',
      theme: AppTheme.theme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
