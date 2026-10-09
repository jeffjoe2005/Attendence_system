import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_system/providers/auth_provider.dart';
import 'package:attendance_system/providers/moderator_data_provider.dart';
import 'package:attendance_system/screens/moderator/moderator_dashboard.dart';
import 'package:attendance_system/screens/cr/cr_dashboard.dart';

void main() {
  testWidgets('Test Add CR flow in ModeratorDashboard', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final modData = ModeratorDataProvider();
    final auth = AuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: modData),
          ChangeNotifierProvider.value(value: auth),
        ],
        child: const MaterialApp(
          home: ModeratorDashboard(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Click '3. Add CR'
    final addCrTab = find.textContaining('3. Add CR');
    expect(addCrTab, findsOneWidget);
    await tester.tap(addCrTab);
    await tester.pumpAndSettle();

    // 2. Find the CR email field
    final emailField = find.widgetWithText(TextField, 'CR Email');
    expect(emailField, findsOneWidget);

    // 3. Type into CR Email field
    await tester.enterText(emailField, 'new.cr@nitgoa.ac.in');
    await tester.pumpAndSettle();

    // 4. Tap 'Add CR' button
    final addBtn = find.text('Add CR');
    expect(addBtn, findsOneWidget);
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    // Verify CR was added
    expect(modData.crs.any((c) => c['email'] == 'new.cr@nitgoa.ac.in'), isTrue);
  });

  testWidgets('Test CRDashboard with added CR', (tester) async {
    final modData = ModeratorDataProvider();
    final auth = AuthProvider();
    modData.addCR('new.cr@nitgoa.ac.in', branch: 'ECE', semester: 'VI Sem');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: modData),
          ChangeNotifierProvider.value(value: auth),
        ],
        child: const MaterialApp(
          home: CRDashboard(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Rahul Patil'), findsWidgets);
  });
}
