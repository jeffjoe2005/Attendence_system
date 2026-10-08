import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_system/providers/auth_provider.dart';
import 'package:attendance_system/config/theme.dart';

void main() {
  testWidgets('App shows splash then login', (WidgetTester tester) async {
    // Build app with provider, same as main.dart
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider()..initialize(),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              final auth = context.watch<AuthProvider>();
              if (!auth.isInitialized || auth.isLoading) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return const Scaffold(
                body: Center(child: Text('Login Screen')),
              );
            },
          ),
        ),
      ),
    );

    // Initially shows loading spinner (initializing)
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Pump past the initialize() delay (300ms)
    await tester.pump(const Duration(milliseconds: 500));

    // Now shows login text
    expect(find.text('Login Screen'), findsOneWidget);
  });
}
