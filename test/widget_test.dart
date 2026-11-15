import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iraqi_domino/app.dart';

void main() {
  testWidgets('App shell shows the Arabic title', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: IraqiDominoApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('الدومينو العراقي'), findsWidgets);
  });
}