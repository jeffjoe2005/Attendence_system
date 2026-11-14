import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/portal_provider.dart';
import '../providers/moderator_data_provider.dart';
import '../services/api_service.dart';
import 'student/server_student_dashboard.dart';
import '../widgets/server_course_table.dart';

typedef Json = Map<String, dynamic>;

String dayString(DateTime day) => day.toIso8601String().split('T').first;

Future<bool> confirm(BuildContext context, String message) async =>
    await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Confirm change'),
                content: Text(message),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Confirm')),
                ])) ??
    false;

Future<bool> perform(
    BuildContext context, Future<dynamic> Function() action) async {
  try {
    await action();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved to the server')));
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()), duration: const Duration(seconds: 7)));
    }
    return false;
  }
}

class PortalHome extends StatefulWidget {
  const PortalHome({super.key, this.professorOnly = false});
  final bool professorOnly;
  @override
  State<PortalHome> createState() => _PortalHomeState();
}

class _PortalHomeState extends State<PortalHome> {
  bool studentView = true;
  String search = '';
  @override
  Widget build(BuildContext context) {
    final p = context.watch<PortalProvider>();
    final data = p.snapshot;
    if (data == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('NIT Goa Attendance'), actions: [
            IconButton(
                onPressed: () => context.read<AuthProvider>().signOut(),
                icon: const Icon(Icons.logout)),
          ]),
          body: Center(
              child: p.loading
                  ? const CircularProgressIndicator()
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(p.error ?? 'No data available')),
                      FilledButton(
                          onPressed: p.refresh, child: const Text('Retry')),
                    ])));
    }
    final role = widget.professorOnly ? 'professor' : p.role;
    final isStudent = role == 'student' || (role == 'cr' && studentView);
    final managed = List<String>.from(data['managed_ids']);
    final courses = p
        .rows('courses')
        .where((c) =>
            ((p.isAdmin && !widget.professorOnly) || managed.contains(c['id']) || role == 'cr') &&
            '${c['code']} ${c['name']} ${c['branch']} ${c['semester']} ${c['professor_name']}'
                .toLowerCase()
                .contains(search))
        .toList();
    return Scaffold(
      appBar: isStudent
          ? null
          : AppBar(
              title: Text(
                  '${(p.isAdmin && !widget.professorOnly) ? 'Moderator' : role == 'cr' ? 'CR Attendance' : 'Professor'} Portal'),
              actions: [
                  IconButton(
                      tooltip: 'Refresh',
                      onPressed: p.refresh,
                      icon: const Icon(Icons.refresh)),
                  IconButton(
                      tooltip: 'Logout',
                      onPressed: () => context.read<AuthProvider>().signOut(),
                      icon: const Icon(Icons.logout)),
                ]),
      bottomNavigationBar: role == 'cr'
          ? NavigationBar(
              selectedIndex: studentView ? 0 : 1,
              onDestinationSelected: (i) =>
                  setState(() => studentView = i == 0),
              destinations: const [
                  NavigationDestination(
                      icon: Icon(Icons.school), label: 'My attendance'),
                  NavigationDestination(
                      icon: Icon(Icons.fact_check), label: 'CR attendance'),
                ])
          : null,
      body: Column(children: [
        if (p.loading || p.saving) const LinearProgressIndicator(),
        if (p.error != null)
          MaterialBanner(
              content: Text(
                  'Could not refresh: ${p.error}. Displayed information may be outdated.'),
              actions: [
                TextButton(onPressed: p.refresh, child: const Text('Retry'))
              ]),
        Expanded(
            child: isStudent
                ? ServerStudentDashboard(serverData: data)
                : RefreshIndicator(
                    onRefresh: p.refresh,
                    child:
                        ListView(padding: const EdgeInsets.all(16), children: [
                      if ((p.isAdmin && !widget.professorOnly))
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          FilledButton.icon(
                              onPressed: () => personDialog(context, p),
                              icon: const Icon(Icons.person_add),
                              label: const Text('Add person')),
                          FilledButton.icon(
                              onPressed: () => courseDialog(context, p),
                              icon: const Icon(Icons.add),
                              label: const Text('Add course')),
                          OutlinedButton(
                              onPressed: () => importDialog(context, p),
                              child: const Text('Import Excel / CSV')),
                          OutlinedButton(
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(
                                    text: const JsonEncoder.withIndent('  ')
                                        .convert(data)));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Portal snapshot copied. Use a database backup for full history.')));
                                }
                              },
                              child: const Text('Export snapshot')),
                        ]),
                      const SizedBox(height: 12),
                      TextField(
                          decoration: const InputDecoration(
                              labelText: 'Search courses, branches or faculty',
                              prefixIcon: Icon(Icons.search)),
                          onChanged: (v) =>
                              setState(() => search = v.toLowerCase())),
                      const SizedBox(height: 12),
                      if (courses.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                                'No courses available. Your moderator can assign courses and your professor can enroll students.')),
                      if ((p.isAdmin && !widget.professorOnly))
                        ExpansionTile(
                          title: const Text(
                              'Course table · filters & bulk editing'),
                          children: [
                            ServerCourseTable(
                                portal: p,
                                onEdit: (c) => courseDialog(context, p, c),
                                onOpen: (c) => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            ChangeNotifierProvider.value(
                                                value: p,
                                                child: CourseWorkspace(
                                                    course: c))))),
                          ],
                        ),
                      ...courses.map((c) => Card(
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${c['code']} · ${c['name']}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    Text(
                                        '${c['branch']} · ${c['semester']} · Section ${c['section'].toString().isEmpty ? 'All' : c['section']}'),
                                    Text(
                                        '${c['student_count']} students · ${c['professor_name'].toString().isEmpty ? 'Unassigned' : c['professor_name']}'),
                                    const SizedBox(height: 8),
                                    Wrap(spacing: 8, runSpacing: 8, children: [
                                      FilledButton(
                                          onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      ChangeNotifierProvider
                                                          .value(
                                                              value: p,
                                                              child:
                                                                  CourseWorkspace(
                                                                      course:
                                                                          c)))),
                                          child: Text(role == 'cr'
                                              ? 'View permissions & attendance'
                                              : 'Roster & attendance')),
                                      if ((p.isAdmin && !widget.professorOnly))
                                        OutlinedButton(
                                            onPressed: () =>
                                                courseDialog(context, p, c),
                                            child: const Text('Edit / assign')),
                                      if ((p.isAdmin && !widget.professorOnly))
                                        TextButton(
                                            onPressed: () async {
                                              if (await confirm(context,
                                                      'Archive ${c['code']}? Active enrollments will end; attendance history is retained.') &&
                                                  context.mounted) {
                                                await perform(
                                                    context,
                                                    () => p.mutate('DELETE',
                                                        '/courses/${c['id']}'));
                                              }
                                            },
                                            child: const Text('Archive')),
                                    ]),
                                  ])))),
                      if ((p.isAdmin && !widget.professorOnly))
                        ExpansionTile(
                            title:
                                const Text('People · edit or disable accounts'),
                            children: p
                                .rows('users')
                                .map((u) => ListTile(
                                      title:
                                          Text('${u['name']} · ${u['role']}'),
                                      subtitle: Text(
                                          '${u['email']} ${u['active'] == false ? '(disabled)' : ''}'),
                                      trailing: Wrap(children: [
                                        IconButton(
                                            tooltip: 'Edit person',
                                            icon: const Icon(Icons.edit),
                                            onPressed: () =>
                                                personDialog(context, p, u)),
                                        IconButton(
                                            tooltip: 'Disable account',
                                            icon: const Icon(Icons.person_off),
                                            onPressed: u['active'] == false
                                                ? null
                                                : () async {
                                                    if (await confirm(context,
                                                            'Disable this account and end its active assignments and enrollments? History will be retained.') &&
                                                        context.mounted) {
                                                      await perform(
                                                          context,
                                                          () => p.mutate(
                                                              'DELETE',
                                                              '/users/${u['id']}'));
                                                    }
                                                  }),
                                      ]),
                                    ))
                                .toList()),
                    ]))),
      ]),
    );
  }
}

Future<void> personDialog(BuildContext context, PortalProvider p,
    [Json? person]) async {
  final fields = {
    for (final key in [
      'name',
      'email',
      'roll_number',
      'branch',
      'semester',
      'section'
    ])
      key: TextEditingController(
          text: person?[key]?.toString() ?? (key == 'semester' ? '0' : ''))
  };
  String role = person?['role'] ?? 'professor';
  final roles =
      {'student', 'cr', 'professor', 'moderator', 'admin', role}.toList();
  bool busy = false;
  await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, change) => AlertDialog(
                  title: Text(person == null ? 'Add person' : 'Edit person'),
                  content: SizedBox(
                      width: 460,
                      child: SingleChildScrollView(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        DropdownButtonFormField<String>(
                            initialValue: role,
                            items: roles
                                .map((r) =>
                                    DropdownMenuItem(value: r, child: Text(r)))
                                .toList(),
                            onChanged: (v) => change(() => role = v!),
                            decoration: const InputDecoration(
                                labelText: 'Assigned role')),
                        ...fields.entries.map((e) => Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: TextField(
                                controller: e.value,
                                decoration: InputDecoration(
                                    labelText: e.key.replaceAll('_', ' ')),
                                keyboardType: e.key == 'semester'
                                    ? TextInputType.number
                                    : TextInputType.text))),
                        const Text(
                            'Roles are assigned explicitly. Student and CR accounts require a unique roll number.'),
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: busy ? null : () => Navigator.pop(ctx),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: busy
                            ? null
                            : () async {
                                change(() => busy = true);
                                final body = <String, dynamic>{
                                  for (final e in fields.entries)
                                    e.key: e.value.text.trim(),
                                  'role': role
                                };
                                body['semester'] =
                                    int.tryParse(fields['semester']!.text) ?? 0;
                                final ok = await perform(
                                    ctx,
                                    () => p.mutate(
                                        person == null ? 'POST' : 'PUT',
                                        person == null
                                            ? '/users'
                                            : '/users/${person['id']}',
                                        body));
                                if (ctx.mounted) {
                                  if (ok) {
                                    Navigator.pop(ctx);
                                  } else {
                                    change(() => busy = false);
                                  }
                                }
                              },
                        child: const Text('Save')),
                  ])));
  for (final c in fields.values) {
    c.dispose();
  }
}

Future<void> courseDialog(BuildContext context, PortalProvider p,
    [Json? course]) async {
  final fields = {
    for (final key in ['code', 'name', 'branch', 'semester', 'section', 'type'])
      key: TextEditingController(
          text: course?[key]?.toString() ?? (key == 'type' ? 'Theory' : ''))
  };
  final selected = Set<String>.from(course?['professor_ids'] ?? []);
  bool busy = false;
  await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, change) => AlertDialog(
                  title: Text(course == null
                      ? 'Add course offering'
                      : 'Edit course / faculty'),
                  content: SizedBox(
                      width: 480,
                      child: SingleChildScrollView(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        ...fields.entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: TextField(
                                controller: e.value,
                                decoration: InputDecoration(
                                    labelText: e.key,
                                    hintText: e.key == 'semester'
                                        ? 'e.g. VI Sem'
                                        : null)))),
                        const Text(
                            'Assigned professors (multiple faculty supported for this section)'),
                        ...p
                            .rows('users')
                            .where((u) =>
                                u['role'] == 'professor' && u['active'] == true)
                            .map((u) => CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(u['name']),
                                subtitle: Text(u['email']),
                                value: selected.contains(u['id']),
                                onChanged: (v) => change(() {
                                      if (v == true) {
                                        selected.add(u['id']);
                                      } else {
                                        selected.remove(u['id']);
                                      }
                                    }))),
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: busy ? null : () => Navigator.pop(ctx),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: busy
                            ? null
                            : () async {
                                change(() => busy = true);
                                final ok = await perform(
                                    ctx,
                                    () => p.mutate(
                                            course == null ? 'POST' : 'PUT',
                                            course == null
                                                ? '/courses'
                                                : '/courses/${course['id']}',
                                            {
                                              for (final e in fields.entries)
                                                e.key: e.value.text.trim(),
                                              'professor_ids': selected.toList()
                                            }));
                                if (ctx.mounted) {
                                  if (ok) {
                                    Navigator.pop(ctx);
                                  } else {
                                    change(() => busy = false);
                                  }
                                }
                              },
                        child: const Text('Save')),
                  ])));
  for (final c in fields.values) {
    c.dispose();
  }
}

Future<void> importDialog(BuildContext context, PortalProvider p) async {
  final text = TextEditingController();
  bool busy = false;
  List<int>? bytes;
  String? fileName;
  await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, change) => AlertDialog(
                title: const Text('Import course list'),
                content: SizedBox(
                    width: 500,
                    child: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      OutlinedButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  final selected = await FilePicker.pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: ['xlsx', 'csv', 'tsv'],
                                      withData: true);
                                  if (selected != null && ctx.mounted) {
                                    change(() {
                                      bytes = selected.files.single.bytes;
                                      fileName = selected.files.single.name;
                                    });
                                  }
                                },
                          child: Text(fileName ?? 'Choose Excel / CSV file')),
                      TextField(
                          controller: text,
                          maxLines: 8,
                          decoration: const InputDecoration(
                              hintText:
                                  'Or paste CSV / TSV with Course Code, Course Name, Branch, Semester columns. Assign verified faculty after import.')),
                    ]))),
                actions: [
                  TextButton(
                      onPressed: busy ? null : () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              change(() => busy = true);
                              final parser = ModeratorDataProvider(
                                  seedDefaults: false,
                                  loadFromStorageOnStart: false,
                                  persistLocal: false);
                              if (bytes != null &&
                                  fileName!.toLowerCase().endsWith('.xlsx')) {
                                parser.importExcelBytes(bytes!,
                                    fileName: fileName);
                              } else {
                                parser.importCsvData(bytes == null
                                    ? text.text
                                    : utf8.decode(bytes!));
                              }
                              final courses = parser.courses;
                              final ok = await perform(ctx, () async {
                                if (courses.isEmpty) {
                                  throw Exception(
                                      'No courses found in the supplied text');
                                }
                                await p.mutate(
                                    'POST',
                                    '/courses/import',
                                    courses
                                        .map((c) => {
                                              'code': c['code'],
                                              'name': c['name'],
                                              'branch': c['branch'],
                                              'semester': c['semester'],
                                              'type': c['type'],
                                              'professor_ids': <String>[]
                                            })
                                        .toList());
                              });
                              parser.dispose();
                              if (ctx.mounted) {
                                if (ok) {
                                  Navigator.pop(ctx);
                                } else {
                                  change(() => busy = false);
                                }
                              }
                            },
                      child: const Text('Import'))
                ],
              )));
  text.dispose();
}

class CourseWorkspace extends StatefulWidget {
  const CourseWorkspace({super.key, required this.course});
  final Json course;
  @override
  State<CourseWorkspace> createState() => _CourseWorkspaceState();
}

class _CourseWorkspaceState extends State<CourseWorkspace> {
  DateTime day = DateTime.now();
  int lecture = 1;
  List<Json> roster = [];
  Map<String, String> entries = {};
  Json? loadedSession;
  String? error;
  bool loading = false, dirty = false, saving = false;
  int _request = 0;
  static const _draftStorage = FlutterSecureStorage();
  Future<void> _draftWrites = Future.value();
  String get _draftKey =>
      'attendance_draft_${context.read<PortalProvider>().snapshot?['user']?['id']}_${id}_${dayString(day)}_$lecture';
  void rememberDraft() {
    final key = _draftKey;
    final value =
        jsonEncode({'version': loadedSession?['version'], 'entries': entries});
    _draftWrites = _draftWrites
        .then((_) => _draftStorage.write(key: key, value: value))
        .catchError((_) {});
  }

  Future<void> clearDraft() async {
    final key = _draftKey;
    await _draftWrites;
    try {
      await _draftStorage.delete(key: key);
    } catch (_) {}
  }

  String get id => widget.course['id'];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Json? currentSession(PortalProvider p) {
    final matches = p.rows('sessions').where((s) =>
        s['course_id'] == id &&
        s['date'] == dayString(day) &&
        s['lecture_number'] == lecture);
    return matches.isEmpty ? null : matches.first;
  }

  bool manager(PortalProvider p) =>
      List<String>.from(p.snapshot?['managed_ids'] ?? []).contains(id);
  Json? grant(PortalProvider p) {
    final matches = p.rows('permissions').where((g) =>
        g['course_id'] == id &&
        g['cr_id'] == p.snapshot?['user']?['id'] &&
        g['active'] == true &&
        g['date'] == dayString(day) &&
        g['lecture_number'] == lecture);
    return matches.isEmpty ? null : matches.first;
  }

  Future<void> load() async {
    final ticket = ++_request;
    setState(() {
      loading = true;
      error = null;
    });
    final p = context.read<PortalProvider>();
    await p.refresh();
    try {
      final session = currentSession(p);
      final data = session != null
          ? List<Json>.from(session['students'])
          : List<Json>.from(await ApiService.instance.get(
              '/api/workspace/courses/$id/roster',
              queryParams: {'day': dayString(day), 'lecture': '$lecture'}));
      if (!mounted || ticket != _request) return;
      setState(() {
        roster = data;
        loadedSession = session;
        entries =
            session == null ? {} : Map<String, String>.from(session['entries']);
        dirty = false;
      });
      try {
        await _draftWrites;
        final saved = await _draftStorage.read(key: _draftKey);
        if (saved != null && mounted && ticket == _request) {
          final draft = jsonDecode(saved) as Map<String, dynamic>;
          if (draft['version'] == session?['version']) {
            final restored = Map<String, String>.from(draft['entries']);
            restored.removeWhere(
                (key, value) => !roster.any((s) => s['id'] == key));
            if (restored.isNotEmpty) {
              setState(() {
                entries = restored;
                dirty = true;
              });
            }
          }
        }
      } catch (_) {}
    } catch (e) {
      if (mounted && ticket == _request) {
        setState(() {
          error = e.toString();
          roster = [];
          entries = {};
          loadedSession = null;
        });
      }
    } finally {
      if (mounted && ticket == _request) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    final p = context.read<PortalProvider>();
    setState(() => saving = true);
    final ok = await perform(
        context,
        () => p.mutate(loadedSession == null ? 'POST' : 'PUT',
                '/courses/$id/attendance', {
              'date': dayString(day),
              'lecture_number': lecture,
              'entries': entries,
              if (loadedSession != null) 'version': loadedSession!['version'],
            }));
    if (!mounted) return;
    setState(() => saving = false);
    if (ok) {
      await clearDraft();
      await load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PortalProvider>();
    final session = currentSession(p);
    final isManager = manager(p);
    final permission = grant(p);
    final allowed = isManager ||
        (permission != null &&
            (session == null || permission['can_edit'] == true));
    final stale = session?['version'] != loadedSession?['version'];
    return PopScope(
        canPop: !dirty,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop &&
              await confirm(context, 'Discard unsaved attendance changes?') &&
              mounted) {
            await clearDraft();
            if (!mounted) return;
            setState(() => dirty = false);
            if (context.mounted) Navigator.pop(context);
          }
        },
        child: Scaffold(
            appBar: AppBar(
                title: Text(
                    '${widget.course['code']} · Section ${widget.course['section']}'),
                actions: [
                  IconButton(
                      tooltip: 'Reload',
                      onPressed: () async {
                        if (!dirty ||
                            await confirm(
                                context, 'Discard unsaved marks and reload?')) {
                          await clearDraft();
                          await load();
                        }
                      },
                      icon: const Icon(Icons.refresh))
                ]),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              Text(widget.course['name'],
                  style: Theme.of(context).textTheme.titleLarge),
              Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                if (dirty &&
                                    !await confirm(context,
                                        'Discard unsaved marks to select another date?')) {
                                  return;
                                }
                                await clearDraft();
                                if (!context.mounted) return;
                                final selected = await showDatePicker(
                                    context: context,
                                    initialDate: day,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 365)));
                                if (selected != null) {
                                  setState(() => day = selected);
                                  await load();
                                }
                              },
                        icon: const Icon(Icons.calendar_month),
                        label: Text(dayString(day))),
                    DropdownButton<int>(
                        value: lecture,
                        items: List.generate(
                            20,
                            (i) => DropdownMenuItem(
                                value: i + 1, child: Text('Lecture ${i + 1}'))),
                        onChanged: saving
                            ? null
                            : (v) async {
                                if (dirty &&
                                    !await confirm(
                                        context, 'Discard unsaved marks?')) {
                                  return;
                                }
                                await clearDraft();
                                setState(() => lecture = v!);
                                await load();
                              }),
                    if (isManager)
                      OutlinedButton(
                          onPressed: () => addStudent(p),
                          child: const Text('Add student')),
                    if (isManager)
                      OutlinedButton(
                          onPressed: () => permissionDialog(p),
                          child: const Text('CR permissions')),
                  ]),
              const SizedBox(height: 12),
              if (session != null)
                Text(
                    'Submitted by ${session['submitted_by']} · version ${session['version']}'),
              if (session == null)
                const Text('Not submitted. Mark every student before saving.'),
              if (!allowed)
                const Text(
                    'Attendance access is disabled. Your professor must grant permission for this date and lecture; corrections need edit permission.'),
              if (stale)
                MaterialBanner(
                    content: const Text(
                        'This session changed on the server. Reload before continuing.'),
                    actions: [
                      TextButton(onPressed: load, child: const Text('Reload'))
                    ]),
              if (error != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(error!,
                        style: const TextStyle(color: Colors.red))),
              if (loading) const LinearProgressIndicator(),
              if (roster.isEmpty && !loading)
                const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                        'No eligible students to display. Add registered students to this course before taking attendance.')),
              if (allowed && roster.isNotEmpty)
                Wrap(spacing: 8, children: [
                  TextButton(
                      onPressed: saving || stale
                          ? null
                          : () => setState(() {
                                entries = {
                                  for (final s in roster) s['id']: 'present'
                                };
                                dirty = true;
                                rememberDraft();
                              }),
                      child: const Text('Mark all present')),
                  TextButton(
                      onPressed: saving || stale
                          ? null
                          : () => setState(() {
                                entries = {
                                  for (final s in roster) s['id']: 'absent'
                                };
                                dirty = true;
                                rememberDraft();
                              }),
                      child: const Text('Mark all absent')),
                  Text(
                      '${entries.values.where((v) => v == 'present').length} present · ${entries.values.where((v) => v == 'absent').length} absent · ${roster.length - entries.length} unmarked'),
                ]),
              ...roster.map((s) => Card(
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${s['name']} · ${s['roll_number']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  ChoiceChip(
                                      label: const Text('Present'),
                                      selected: entries[s['id']] == 'present',
                                      selectedColor: Colors.green.shade100,
                                      onSelected: !allowed || saving || stale
                                          ? null
                                          : (_) => setState(() {
                                                entries[s['id']] = 'present';
                                                dirty = true;
                                                rememberDraft();
                                              })),
                                  ChoiceChip(
                                      label: const Text('Absent'),
                                      selected: entries[s['id']] == 'absent',
                                      selectedColor: Colors.red.shade100,
                                      onSelected: !allowed || saving || stale
                                          ? null
                                          : (_) => setState(() {
                                                entries[s['id']] = 'absent';
                                                dirty = true;
                                                rememberDraft();
                                              })),
                                  if (isManager)
                                    TextButton(
                                        onPressed: () async {
                                          if (await confirm(context,
                                                  'Remove ${s['name']} from future attendance? Existing records are retained.') &&
                                              context.mounted) {
                                            if (await perform(
                                                context,
                                                () => p.mutate('DELETE',
                                                    '/courses/$id/enrollments/${s['id']}'))) {
                                              await load();
                                            }
                                          }
                                        },
                                        child: const Text('Remove enrollment')),
                                ]),
                          ])))),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: !allowed ||
                          saving ||
                          loading ||
                          stale ||
                          roster.isEmpty ||
                          entries.length != roster.length
                      ? null
                      : save,
                  child: Text(saving
                      ? 'Saving…'
                      : loadedSession == null
                          ? 'Submit attendance'
                          : 'Save correction')),
              if (loadedSession != null && isManager)
                TextButton(
                    onPressed: () async {
                      await perform(context, () async {
                        final audit = await ApiService.instance.get(
                            '/api/workspace/courses/$id/audit/${loadedSession!['id']}');
                        if (!context.mounted) return;
                        await showDialog(
                            context: context,
                            builder: (ctx) =>
                                AlertDialog(
                                    title:
                                        const Text('Attendance audit history'),
                                    content: SingleChildScrollView(
                                        child: SelectableText(
                                            const JsonEncoder.withIndent('  ')
                                                .convert(audit))),
                                    actions: [
                                      TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Close'))
                                    ]));
                      });
                    },
                    child: const Text('View correction history')),
              const SizedBox(height: 24),
              const Text('Delegated sessions',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              if (p
                  .rows('permissions')
                  .where((g) => g['course_id'] == id && g['active'] == true)
                  .isEmpty)
                const Text(
                    'No active CR permissions. Access is disabled by default.'),
              ...p
                  .rows('permissions')
                  .where((g) => g['course_id'] == id && g['active'] == true)
                  .map((g) => ListTile(
                        title: Text(
                            '${g['date']} · Lecture ${g['lecture_number']}'),
                        subtitle: Text(g['can_edit'] == true
                            ? 'Submission and corrections allowed'
                            : 'Initial submission only'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          if (dirty &&
                              !await confirm(
                                  context, 'Discard unsaved marks?')) {
                            return;
                          }
                          await clearDraft();
                          setState(() {
                            day = DateTime.parse(g['date']);
                            lecture = g['lecture_number'];
                          });
                          await load();
                        },
                      )),
              const SizedBox(height: 16),
              const Text('Submitted sessions',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...p.rows('sessions').where((s) => s['course_id'] == id).map(
                  (s) => ListTile(
                      title:
                          Text('${s['date']} · Lecture ${s['lecture_number']}'),
                      subtitle: Text('Submitted by ${s['submitted_by']}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        if (dirty &&
                            !await confirm(context, 'Discard unsaved marks?')) {
                          return;
                        }
                        await clearDraft();
                        setState(() {
                          day = DateTime.parse(s['date']);
                          lecture = s['lecture_number'];
                        });
                        await load();
                      })),
            ])));
  }

  Future<void> addStudent(PortalProvider p) async {
    final email = TextEditingController();
    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Enroll existing student'),
                content: TextField(
                    controller: email,
                    decoration: const InputDecoration(
                        labelText: 'Institutional email')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () async {
                        if (await perform(
                                ctx,
                                () => p.mutate(
                                    'POST',
                                    '/courses/$id/enrollments',
                                    {'email': email.text.trim()})) &&
                            ctx.mounted) {
                          Navigator.pop(ctx);
                          await load();
                        }
                      },
                      child: const Text('Add'))
                ]));
    email.dispose();
  }

  Future<void> permissionDialog(PortalProvider p) async {
    // Fetch today's active roster, independently of any historical attendance being edited.
    List<Json> students;
    try {
      students = List<Json>.from(await ApiService.instance.get(
          '/api/workspace/courses/$id/roster',
          queryParams: {'day': dayString(DateTime.now())}));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return;
    }
    final crs = students.where((u) => u['role'] == 'cr').toList();
    if (!mounted) return;
    if (crs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enroll a registered CR in this course first.')));
      return;
    }
    String cr = crs.first['id'];
    bool canEdit = false, busy = false;
    await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, change) => AlertDialog(
                    title: const Text('Delegate attendance'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                          '${widget.course['code']} · ${dayString(day)} · Lecture $lecture'),
                      DropdownButton<String>(
                          isExpanded: true,
                          value: cr,
                          items: crs
                              .map((u) => DropdownMenuItem<String>(
                                  value: u['id'], child: Text(u['name'])))
                              .toList(),
                          onChanged: (v) => change(() => cr = v!)),
                      CheckboxListTile(
                          title: const Text('Also allow corrections'),
                          value: canEdit,
                          onChanged: (v) => change(() => canEdit = v!)),
                    ]),
                    actions: [
                      TextButton(
                          onPressed: busy ? null : () => Navigator.pop(ctx),
                          child: const Text('Cancel')),
                      ...[false, true].map((active) => TextButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  change(() => busy = true);
                                  final ok = await perform(
                                      ctx,
                                      () => p.mutate('PUT',
                                              '/courses/$id/permission', {
                                            'cr_id': cr,
                                            'date': dayString(day),
                                            'lecture_number': lecture,
                                            'can_edit': canEdit,
                                            'active': active
                                          }));
                                  if (ctx.mounted) {
                                    if (ok) {
                                      Navigator.pop(ctx);
                                    } else {
                                      change(() => busy = false);
                                    }
                                  }
                                },
                          child: Text(active ? 'Grant' : 'Revoke'))),
                    ])));
  }
}
