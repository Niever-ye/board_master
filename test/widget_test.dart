import 'package:flutter_test/flutter_test.dart';
import 'package:board_master/app.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const BoardMasterApp());
    expect(find.text('Board Master'), findsOneWidget);
    expect(find.text('围棋'), findsOneWidget);
    expect(find.text('中国象棋'), findsOneWidget);
  });
}
