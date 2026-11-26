import 'package:flutter_test/flutter_test.dart';
import 'package:iraqi_domino/ui/screens/app_shell_screen.dart';
import 'package:iraqi_domino/ui/screens/auth_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('First launch opens AuthScreen after SplashScreen and allows Guest entry', (tester) async {
    await tester.pumpWidget(
      await buildTestApp({'data_center.initial_entry_done': false}),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('تسجيل الدخول باستخدام Google'), findsOneWidget);
    expect(find.text('الدخول عن طريق رقم الهاتف'), findsOneWidget);
    expect(find.text('غير مفعل'), findsOneWidget);
    expect(find.text('المتابعة كضيف'), findsOneWidget);

    await tester.ensureVisible(find.text('المتابعة كضيف'));
    await tester.tap(find.text('المتابعة كضيف'));
    await tester.pumpAndSettle();

    expect(find.byType(AppShellScreen), findsOneWidget);
  });

  testWidgets('AuthScreen creates and links an account from Guest mode', (tester) async {
    await tester.pumpWidget(
      await buildTestApp({'data_center.initial_entry_done': false}),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('إنشاء حساب جديد'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));

    await tester.enterText(fields.at(0), 'حيدر البغدادي');
    await tester.enterText(fields.at(1), 'haider@baghdad.iq');
    await tester.enterText(fields.at(2), 'secret123');

    await tester.ensureVisible(find.text('إنشاء وربط الحساب'));
    await tester.tap(find.text('إنشاء وربط الحساب'));
    await tester.pumpAndSettle();

    expect(find.byType(AppShellScreen), findsOneWidget);
  });
}
