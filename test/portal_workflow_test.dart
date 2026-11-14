import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:attendance_system/providers/portal_provider.dart';
import 'package:attendance_system/screens/portal_home.dart';
import 'package:attendance_system/services/api_service.dart';
import 'package:attendance_system/widgets/server_course_table.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late http.Client original;
  setUp(() async {
    original = ApiService.client;
    FlutterSecureStorage.setMockInitialValues({});
    await ApiService.setAuthToken('fixture');
  });
  tearDown(() {
    ApiService.client.close();
    ApiService.client = original;
  });

  final course = <String, dynamic>{
    'id': 'c',
    'code': 'EC101',
    'name': 'Signals',
    'branch': 'ECE',
    'semester': 'VI Sem',
    'section': 'A',
    'type': 'Theory',
    'professor_ids': ['p'],
    'professor_name': 'Professor',
    'student_count': 2
  };
  final students = [
    {'id': 's1', 'name': 'First Student', 'roll_number': '23EC1032'},
    {'id': 's2', 'name': 'Second Student', 'roll_number': '23EC1040'},
  ];
  Map<String, dynamic> snapshot() => {
        'user': {'id': 'p', 'role': 'professor'},
        'courses': [course],
        'managed_ids': ['c'],
        'enrolled_ids': [],
        'sessions': [],
        'permissions': [],
        'users': [],
        'stats': {}
      };

  test('A save waits for an older poll and publishes the post-save snapshot',
      () async {
    final started = Completer<void>(), release = Completer<http.Response>();
    final calls = <String>[];
    ApiService.client = MockClient((request) async {
      calls.add(request.method);
      if (calls.length == 1) {
        started.complete();
        return release.future;
      }
      return http.Response(jsonEncode({'revision': 2}), 200);
    });
    final portal = PortalProvider(start: false);
    final refresh = portal.refresh();
    await started.future;
    final save = portal.mutate('POST', '/courses', {});
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['GET']);
    release.complete(http.Response('{"revision":1}', 200));
    await Future.wait([refresh, save]);
    expect(calls, ['GET', 'POST', 'GET']);
    expect(portal.snapshot?['revision'], 2);
    portal.dispose();
  });

  testWidgets(
      'Phone attendance marks all, submits once and corrects same session',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = snapshot();
    final writes = <String>[];
    ApiService.client = MockClient((request) async {
      if (request.url.path.endsWith('/roster')) {
        return http.Response(jsonEncode(students), 200);
      }
      if (request.method != 'GET') {
        writes.add(request.method);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.method == 'PUT') {
          expect(body['version'], 1);
        }
        data['sessions'] = [
          {
            'id': 'meeting',
            'course_id': 'c',
            'date': body['date'],
            'lecture_number': 1,
            'version': writes.length,
            'students': students,
            'entries': body['entries'],
            'submitted_by': 'Professor'
          }
        ];
        return http.Response(jsonEncode((data['sessions'] as List).first), 200);
      }
      return http.Response(jsonEncode(data), 200);
    });
    final portal = PortalProvider(start: false)..snapshot = data;
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: portal,
        child: MaterialApp(home: CourseWorkspace(course: course))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Submit attendance'), 200);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Submit attendance'))
            .onPressed,
        isNull);
    await tester.ensureVisible(find.text('Mark all present'));
    await tester.tap(find.text('Mark all present'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Submit attendance'));
    await tester.tap(find.text('Submit attendance'));
    await tester.pumpAndSettle();
    expect(writes, ['POST']);
    expect(find.text('Save correction'), findsOneWidget);
    await tester.ensureVisible(find.text('Absent').first);
    await tester.tap(find.text('Absent').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save correction'));
    await tester.tap(find.text('Save correction'));
    await tester.pumpAndSettle();
    expect(writes, ['POST', 'PUT']);
    expect((data['sessions'] as List).single['entries']['s1'], 'absent');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    portal.dispose();
  });

  testWidgets(
      'Server course table retains zoom, selection and fullscreen on phone',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final portal = PortalProvider(start: false)..snapshot = snapshot();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ListView(children: [
      ServerCourseTable(portal: portal, onOpen: (_) {}, onEdit: (_) {}),
    ]))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();
    expect(find.text('115%'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();
    expect(find.text('Bulk assign'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Fullscreen table'));
    await tester.tap(find.byTooltip('Fullscreen table'));
    await tester.pumpAndSettle();
    expect(find.text('Course table'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    portal.dispose();
  });
}
