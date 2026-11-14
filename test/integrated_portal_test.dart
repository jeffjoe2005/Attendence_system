import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_system/providers/auth_provider.dart';
import 'package:attendance_system/providers/moderator_data_provider.dart';
import 'package:attendance_system/providers/portal_provider.dart';
import 'package:attendance_system/screens/portal_home.dart';

void main() {
  for (final role in ['student', 'cr', 'professor', 'moderator']) {
    testWidgets('$role portal uses authoritative data at phone width',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final portal = PortalProvider(start: false);
      portal.snapshot = {
        'user': {
          'id': 'user',
          'name': 'Test Student',
          'role': role,
          'email': '23EC1032@nitgoa.ac.in',
          'roll_number': '23EC1032',
          'branch': 'ECE',
          'semester': 6
        },
        'courses': [
          {
            'id': 'c',
            'code': 'EC101',
            'name': 'Signals',
            'branch': 'ECE',
            'semester': 'VI Sem',
            'section': 'A',
            'type': 'Theory',
            'professor_name': 'Dr Smith',
            'professor_ids': ['p'],
            'student_count': 1
          }
        ],
        'managed_ids': role == 'professor' || role == 'moderator' ? ['c'] : [],
        'enrolled_ids': ['c'],
        'permissions': [],
        'sessions': [],
        'users': [],
        'stats': {
          'c': {'total': 5, 'attended': 4, 'percentage': 80.0}
        },
      };
      await tester.pumpWidget(MultiProvider(providers: [
        ChangeNotifierProvider.value(value: portal),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
            create: (_) => ModeratorDataProvider(
                seedDefaults: false,
                loadFromStorageOnStart: false,
                persistLocal: false)),
      ], child: const MaterialApp(home: PortalHome())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (role == 'student' || role == 'cr') {
        expect(find.text('80.0%'), findsOneWidget);
        expect(find.text('Registered Courses'), findsOneWidget);
      }
      if (role == 'cr') {
        await tester.tap(find.text('CR attendance'));
        await tester.pumpAndSettle();
        expect(find.text('View permissions & attendance'), findsOneWidget);
        expect(find.text('Add course'), findsNothing);
      }
      if (role == 'professor') {
        expect(find.text('Roster & attendance'), findsOneWidget);
        expect(find.text('Add person'), findsNothing);
      }
      if (role == 'moderator') {
        await tester.tap(find.text('Add person'));
        await tester.pumpAndSettle();
        expect(find.text('Assigned role'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      portal.dispose();
    });
  }
}
