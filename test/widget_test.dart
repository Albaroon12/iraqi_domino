import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('App shows the Arabic title by default', (tester) async {
    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('الدومينو العراقي'), findsWidgets);
  });

  testWidgets('App starts in the saved language', (tester) async {
    await tester.pumpWidget(
      await buildTestApp({'settings.language': 'en'}),
    );
    await tester.pumpAndSettle();

    expect(find.text('Iraqi Domino'), findsWidgets);
  });
}