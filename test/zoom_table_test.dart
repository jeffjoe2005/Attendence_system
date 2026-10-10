import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_system/providers/auth_provider.dart';
import 'package:attendance_system/providers/moderator_data_provider.dart';
import 'package:attendance_system/screens/moderator/moderator_dashboard.dart';

void main() {
  testWidgets('Test Table Zoom Controls and Fullscreen Zoom View', (tester) async {
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

    // 1. Check for initial 100% zoom chip and toolbar controls
    expect(find.text('100%'), findsWidgets);
    expect(find.byTooltip('Zoom In Table'), findsOneWidget);
    expect(find.byTooltip('Zoom Out Table'), findsOneWidget);
    expect(find.text('Zoom View'), findsOneWidget);

    // 2. Tap Zoom In Table button
    await tester.tap(find.byTooltip('Zoom In Table'));
    await tester.pumpAndSettle();
    expect(find.text('115%'), findsWidgets);

    // 3. Tap Zoom In Table again
    await tester.tap(find.byTooltip('Zoom In Table'));
    await tester.pumpAndSettle();
    expect(find.text('130%'), findsWidgets);

    // 4. Tap the percentage chip to reset back to 100%
    await tester.tap(find.text('130%').first);
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsWidgets);

    // 5. Tap Zoom Out Table
    await tester.tap(find.byTooltip('Zoom Out Table'));
    await tester.pumpAndSettle();
    expect(find.text('85%'), findsWidgets);

    // Reset back to 100%
    await tester.tap(find.text('85%').first);
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsWidgets);

    // 6. Tap 'Zoom View' to open FullscreenTableZoomViewer
    await tester.tap(find.text('Zoom View'));
    await tester.pumpAndSettle();

    // Verify Fullscreen Zoom Viewer is active
    expect(find.byType(FullscreenTableZoomViewer), findsOneWidget);
    expect(find.text('Course Table (Zoom Mode)'), findsOneWidget);
    expect(find.text('Exit Zoom'), findsWidgets);

    // 7. Tap 'Exit Zoom' button to return to dashboard
    await tester.tap(find.text('Exit Zoom').first);
    await tester.pumpAndSettle();

    // Verify back to ModeratorDashboard
    expect(find.byType(FullscreenTableZoomViewer), findsNothing);
    expect(find.byType(ModeratorDashboard), findsOneWidget);
  });
}
