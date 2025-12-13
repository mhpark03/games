import 'package:flutter_test/flutter_test.dart';

import 'package:game_center_app/main.dart';

void main() {
  testWidgets('Game Center app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GameCenterApp());

    expect(find.text('GAME CENTER'), findsOneWidget);
    expect(find.text('TETRIS'), findsOneWidget);
    expect(find.text('OMOK'), findsOneWidget);
  });
}
