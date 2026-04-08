import 'package:flutter_test/flutter_test.dart';

import 'package:everytick/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EveryTickApp());

    expect(find.byType(EveryTickApp), findsOneWidget);
  });
}
