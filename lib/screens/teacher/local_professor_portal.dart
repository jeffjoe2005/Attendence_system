import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/moderator_data_provider.dart';

const _ink = Color(0xFF17172F);
const _purple = Color(0xFF5632CF);
const _line = Color(0xFFDDD9F2);
const _paper = Color(0xFFF8F7FF);

class LocalProfessorPortal extends StatefulWidget {
  const LocalProfessorPortal({super.key});
  @override
  State<LocalProfessorPortal> createState() => _LocalProfessorPortalState();
}

class _LocalProfessorPortalState extends State<LocalProfessorPortal> {
  String? previewEmail;
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final data = context.watch<ModeratorDataProvider>();
    final developer = auth.userRole == 'developer';
    final email = data.resolveLocalProfessor(developer
        ? (previewEmail ?? 'hackathon1379@gmail.com')
        : auth.userEmail);
    final name = email == null
        ? 'Faculty'
        : data.getProfessorNameByEmail(email) ?? 'Faculty';
    final courses = data.courses
        .where((c) =>
            email != null &&
            data.isCourseAssignedToProfessor(c['code']!, email))
        .toList();
    return Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            title: Text('Professor Portal · $name',
                style: const TextStyle(color: Colors.white, fontSize: 17)),
            actions: [
              IconButton(
                  tooltip: 'Logout',
                  onPressed: auth.signOut,
                  icon: const Icon(Icons.logout))
            ]),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          if (developer)
            DropdownButtonFormField<String>(
                initialValue: email,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Preview registered professor'),
                items: data.professors
                    .map((p) => DropdownMenuItem(
                        value: p['email'], child: Text(p['name'] ?? 'Faculty')))
                    .toList(),
                onChanged: (v) => setState(() => previewEmail = v)),
          const SizedBox(height: 20),
          Text('My Courses (${courses.length})',
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: _ink)),
          const Text('Courses assigned through the Moderator Portal.',
              style: TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 18),
          if (courses.isEmpty)
            const Text('No courses assigned to this faculty account.'),
          ...courses.map((c) => Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE2E8F0))),
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c['code']!,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, color: _purple)),
                        const SizedBox(height: 8),
                        Text(c['name']!,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700)),
                        Text(
                            '${c['branch']} · ${c['semester']} · ${c['type']}'),
                        const SizedBox(height: 16),
                        Wrap(spacing: 12, runSpacing: 8, children: [
                          FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A)),
                              icon: const Icon(Icons.fact_check_outlined),
                              label: const Text('Take Attendance'),
                              onPressed: () => open(c, email!, name, false)),
                          OutlinedButton.icon(
                              icon: const Icon(Icons.history),
                              label: const Text('Attendance History'),
                              onPressed: () => open(c, email!, name, true)),
                        ]),
                      ])))),
        ]));
  }

  void open(
      Map<String, String> course, String email, String name, bool history) {
    final data = context.read<ModeratorDataProvider>();
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
                value: data,
                child: LocalAttendancePage(
                    course: course,
                    email: email,
                    professor: name,
                    history: history))));
  }
}

class LocalAttendancePage extends StatefulWidget {
  final Map<String, String> course;
  final String email, professor;
  final bool history;
  const LocalAttendancePage(
      {super.key,
      required this.course,
      required this.email,
      required this.professor,
      this.history = false});
  @override
  State<LocalAttendancePage> createState() => _LocalAttendancePageState();
}

class _LocalAttendancePageState extends State<LocalAttendancePage> {
  DateTime day = DateTime.now();
  late bool history = widget.history;
  String search = '';
  Map<String, String> marks = {};
  bool dirty = false, busy = false;
  final horizontal = ScrollController();
  String get code => widget.course['code']!;
  String get date => DateFormat('yyyy-MM-dd').format(day);
  String get draftKey => 'draft:$code:$date';
  String get permissionKey => 'cr:$code:$date';
  ModeratorDataProvider get data => context.read<ModeratorDataProvider>();
  List<Map<String, String>> get roster => data.getStudentsForCourse(code);
  List<Map<String, dynamic>> get sessions => data.getSessionsForCourse(code);
  Map<String, dynamic>? get submitted {
    final found =
        sessions.where((s) => s['date'] == date && s['lectureNumber'] == 1);
    return found.isEmpty ? null : found.first;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      data.ensureLocalDemoRoster(widget.course);
      load();
    });
  }

  @override
  void dispose() {
    horizontal.dispose();
    super.dispose();
  }

  void load() {
    final saved = submitted;
    final draft = data.localAttendanceTools[draftKey];
    setState(() {
      marks = draft is Map
          ? Map<String, String>.from(draft)
          : {
              for (final r in (saved?['presentRolls'] as List? ?? []))
                '$r': 'present',
              for (final r in (saved?['absentRolls'] as List? ?? []))
                '$r': 'absent',
            };
      dirty = draft is Map && draft.isNotEmpty;
    });
  }

  Future<void> save({bool draft = false}) async {
    setState(() => busy = true);
    if (!draft) {
      data.recordAttendance(
          courseCode: code,
          date: date,
          lectureNumber: 1,
          markedBy: widget.email,
          markedByName: widget.professor,
          presentRolls: marks.keys.where((r) => marks[r] == 'present').toList(),
          absentRolls: marks.keys.where((r) => marks[r] == 'absent').toList());
    }
    final ok = await data.saveLocalTool(
        draftKey, draft ? Map<String, String>.from(marks) : null);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (ok) dirty = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? draft
                ? 'Draft saved on this device'
                : 'Attendance saved. Student percentages updated.'
            : 'Could not save to local storage. Please retry.')));
  }

  Future<void> chooseDate() async {
    if (dirty) {
      await save(draft: true);
      if (!mounted) return;
    }
    final selected = await showDatePicker(
        context: context,
        initialDate: day,
        firstDate: DateTime(2020),
        lastDate: DateTime.now());
    if (selected != null && mounted) {
      day = selected;
      load();
    }
  }

  Widget panel(Widget child) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
          boxShadow: const [
            BoxShadow(
                color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 3))
          ]),
      child: child);
  Widget pill(String text, Color color, Color bg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
      child: Text(text,
          style: TextStyle(color: color, fontWeight: FontWeight.w700)));
  @override
  Widget build(BuildContext context) {
    context.watch<ModeratorDataProvider>();
    final wide = MediaQuery.sizeOf(context).width >= 1050;
    final present = marks.values.where((v) => v == 'present').length;
    final absent = marks.values.where((v) => v == 'absent').length;
    return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: _purple)
              .copyWith(primary: _purple, surface: Colors.white),
          inputDecorationTheme: InputDecorationTheme(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: _line))),
        ),
        child: PopScope(
            canPop: !dirty,
            onPopInvokedWithResult: (popped, _) async {
              if (!popped) {
                await save(draft: true);
                if (context.mounted && !dirty) Navigator.pop(context);
              }
            },
            child: Scaffold(
                backgroundColor: _paper,
                appBar: AppBar(
                    backgroundColor: Colors.white,
                    foregroundColor: _ink,
                    title: const Text('NIT Goa · Attendance Management System',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    actions: [
                      if (wide)
                        Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(widget.professor))
                    ]),
                body: Row(children: [
                  if (wide)
                    Container(
                        width: 215,
                        color: const Color(0xFF2C2D50),
                        child: Column(children: [
                          const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('Professor Portal',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700))),
                          ListTile(
                              leading: const Icon(Icons.school_outlined,
                                  color: Colors.white),
                              title: const Text('My Courses',
                                  style: TextStyle(color: Colors.white)),
                              onTap: () => Navigator.maybePop(context)),
                          ListTile(
                              selected: history,
                              selectedTileColor: const Color(0xFF50468A),
                              leading: const Icon(Icons.history,
                                  color: Colors.white),
                              title: const Text('Attendance History',
                                  style: TextStyle(color: Colors.white)),
                              onTap: () => setState(() => history = true)),
                        ])),
                  Expanded(
                      child: Column(children: [
                    if (!wide)
                      Container(
                          color: const Color(0xFF33315C),
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          child: const Text('Professor Portal',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700))),
                    Expanded(
                        child: ListView(
                            padding: EdgeInsets.all(wide ? 24 : 12),
                            children: [
                          if (history)
                            const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: Text('Attendance History',
                                    style: TextStyle(
                                        fontSize: 27,
                                        fontWeight: FontWeight.w800,
                                        color: _ink))),
                          panel(Wrap(
                              spacing: 20,
                              runSpacing: 16,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Icon(Icons.memory,
                                    size: 42, color: _purple),
                                Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                          width: wide
                                              ? 460
                                              : MediaQuery.sizeOf(context)
                                                      .width -
                                                  100,
                                          child: Text(
                                              '$code – ${widget.course['name']}',
                                              style: const TextStyle(
                                                  fontSize: 21,
                                                  fontWeight:
                                                      FontWeight.w800))),
                                      Text(
                                          '${widget.course['branch']} · ${widget.course['semester']}'),
                                    ]),
                                OutlinedButton.icon(
                                    onPressed: chooseDate,
                                    icon: const Icon(Icons.calendar_month),
                                    label: Text(DateFormat(history
                                            ? 'MMMM yyyy'
                                            : 'EEE, MMM d, yyyy')
                                        .format(day))),
                                if (!history)
                                  pill(
                                      submitted == null
                                          ? 'Not Submitted'
                                          : 'Submitted',
                                      const Color(0xFF166534),
                                      const Color(0xFFE8F8ED)),
                              ])),
                          const SizedBox(height: 12),
                          Wrap(spacing: 12, children: [
                            TextButton.icon(
                                onPressed: () =>
                                    setState(() => history = false),
                                icon: const Icon(Icons.fact_check_outlined),
                                label: const Text('Take Attendance')),
                            TextButton.icon(
                                key: const ValueKey('local-history-tab'),
                                onPressed: () => setState(() => history = true),
                                icon: const Icon(Icons.history),
                                label: const Text('Attendance History')),
                          ]),
                          const Divider(color: _line),
                          if (history)
                            historyPanel()
                          else ...[
                            Wrap(spacing: 10, runSpacing: 10, children: [
                              stat('${roster.length}', 'Total Students',
                                  const Color(0xFFEDE9FE)),
                              stat('$present', 'Present',
                                  const Color(0xFFDCFCE7)),
                              stat(
                                  '$absent', 'Absent', const Color(0xFFFEE2E2)),
                              stat('${roster.length - marks.length}',
                                  'Unmarked', const Color(0xFFF0EFF5)),
                            ]),
                            const SizedBox(height: 16),
                            if (wide)
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 3, child: markingPanel()),
                                    const SizedBox(width: 18),
                                    Expanded(
                                        child: Column(children: [
                                      crPanel(),
                                      const SizedBox(height: 16),
                                      recentPanel()
                                    ])),
                                  ])
                            else ...[
                              markingPanel(),
                              const SizedBox(height: 16),
                              crPanel()
                            ],
                          ],
                        ])),
                    if (!history)
                      Container(
                          padding: const EdgeInsets.all(16),
                          color: Colors.white,
                          child: Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                    marks.length == roster.length &&
                                            roster.isNotEmpty
                                        ? '✓ Ready to Submit'
                                        : 'Mark every student to submit',
                                    style: const TextStyle(
                                        color: Color(0xFF166534),
                                        fontWeight: FontWeight.w700)),
                                OutlinedButton.icon(
                                    onPressed:
                                        busy ? null : () => save(draft: true),
                                    icon: const Icon(Icons.save_outlined),
                                    label: const Text('Save Draft')),
                                FilledButton.icon(
                                    onPressed: busy ||
                                            roster.isEmpty ||
                                            marks.length != roster.length
                                        ? null
                                        : () => save(),
                                    icon: const Icon(Icons.send_outlined),
                                    label: Text(submitted == null
                                        ? 'Submit Attendance'
                                        : 'Save Correction')),
                              ])),
                  ])),
                ]))));
  }

  Widget stat(String count, String label, Color bg) => Container(
      width: MediaQuery.sizeOf(context).width < 600 ? 145 : 170,
      padding: const EdgeInsets.all(14),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(count,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
        Text(label)
      ]));
  Widget markingPanel() {
    final filtered = roster
        .where(
            (s) => '${s['roll']} ${s['name']}'.toLowerCase().contains(search))
        .toList();
    return panel(Column(children: [
      TextField(
          decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search by roll number or name...'),
          onChanged: (v) => setState(() => search = v.toLowerCase())),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: [
        for (final v in ['present', 'absent', 'clear'])
          OutlinedButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                        marks = v == 'clear'
                            ? {}
                            : {for (final s in roster) s['roll']!: v};
                        dirty = true;
                      }),
              child: Text(v == 'clear'
                  ? 'Clear All'
                  : 'All ${v == 'present' ? 'Present' : 'Absent'}')),
      ]),
      const SizedBox(height: 12),
      ...filtered.asMap().entries.map((entry) {
        final s = entry.value;
        return Container(
            color: entry.key.isEven ? const Color(0xFFF4F2FC) : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: LayoutBuilder(builder: (_, bounds) {
              final identity = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s['name']!,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(s['roll']!,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B)))
                  ]);
              final choices = Wrap(spacing: 6, children: [
                for (final v in ['present', 'absent'])
                  ChoiceChip(
                      label: Text(v == 'present' ? 'Present' : 'Absent'),
                      selected: marks[s['roll']] == v,
                      selectedColor: v == 'present'
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEE2E2),
                      onSelected: busy
                          ? null
                          : (_) => setState(() {
                                marks[s['roll']!] = v;
                                dirty = true;
                              }))
              ]);
              return bounds.maxWidth < 450
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [identity, choices])
                  : Row(children: [Expanded(child: identity), choices]);
            }));
      }),
      if (filtered.isEmpty)
        const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No students match this search.')),
    ]));
  }

  Widget crPanel() {
    final crs = data.crs
        .where((c) =>
            c['branch'] == widget.course['branch'] &&
            c['semester'] == widget.course['semester'])
        .toList();
    final grant = Map<String, dynamic>.from(
        data.localAttendanceTools[permissionKey] as Map? ?? {});
    final selected = crs.any((c) => c['email'] == grant['email'])
        ? grant['email'] as String
        : crs.firstOrNull?['email'];
    return panel(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('CR Attendance Access',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
      Text('Access for $date · $code only.'),
      if (crs.isEmpty)
        const Text(
            'Register a CR for this branch and semester in the Moderator Portal.'),
      if (crs.isNotEmpty)
        DropdownButton<String>(
            isExpanded: true,
            value: selected,
            items: crs
                .map((c) => DropdownMenuItem(
                    value: c['email'],
                    child: Text(c['name']!, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => data
                .saveLocalTool(permissionKey, {'email': v, 'active': false})),
      SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Grant attendance access'),
          value: grant['active'] == true && selected != null,
          onChanged: selected == null
              ? null
              : (v) => data.saveLocalTool(
                  permissionKey, {'email': selected, 'active': v})),
    ]));
  }

  Widget recentPanel() =>
      panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Recent Attendance',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        if (sessions.isEmpty) const Text('No submitted sessions yet.'),
        ...sessions.take(4).map((s) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s['date']),
            subtitle: Text(
                'P: ${(s['presentRolls'] as List).length}  A: ${(s['absentRolls'] as List).length}'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () async {
              if (dirty) await save(draft: true);
              if (!mounted) return;
              day = DateTime.parse(s['date']);
              load();
            })),
      ]));
  Widget historyPanel() {
    final meetings = sessions
        .where((s) =>
            s['date'].toString().startsWith(DateFormat('yyyy-MM').format(day)))
        .toList()
      ..sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));
    final students = roster
        .where(
            (s) => '${s['roll']} ${s['name']}'.toLowerCase().contains(search))
        .toList();
    String cell(Map<String, dynamic> s, String roll) =>
        (s['presentRolls'] as List).contains(roll)
            ? 'P'
            : (s['absentRolls'] as List).contains(roll)
                ? 'A'
                : '—';
    String percent(String roll) {
      final values =
          meetings.map((s) => cell(s, roll)).where((v) => v != '—').toList();
      return values.isEmpty
          ? '—'
          : '${(values.where((v) => v == 'P').length / values.length * 100).round()}%';
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 12, runSpacing: 8, children: [
        stat(
            '${meetings.length}', 'Classes Conducted', const Color(0xFFEDE9FE)),
        pill('P = Present', const Color(0xFF166534), const Color(0xFFDCFCE7)),
        pill('A = Absent', const Color(0xFF991B1B), const Color(0xFFFEE2E2))
      ]),
      const SizedBox(height: 16),
      TextField(
          decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search by roll number or student name...'),
          onChanged: (v) => setState(() => search = v.toLowerCase())),
      Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Copy CSV'),
              onPressed: () async {
                String csv(String v) => '"${v.replaceAll('"', '""')}"';
                final rows = [
                  [
                    'Roll Number',
                    'Student Name',
                    ...meetings.map((s) => s['date'].toString()),
                    'Attendance %'
                  ],
                  ...students.map((s) => [
                        s['roll']!,
                        s['name']!,
                        ...meetings.map((m) => cell(m, s['roll']!)),
                        percent(s['roll']!)
                      ])
                ];
                await Clipboard.setData(ClipboardData(
                    text: rows.map((r) => r.map(csv).join(',')).join('\n')));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Attendance CSV copied')));
                }
              })),
      panel(Scrollbar(
          controller: horizontal,
          thumbVisibility: true,
          child: SingleChildScrollView(
              controller: horizontal,
              scrollDirection: Axis.horizontal,
              child: DataTable(
                  headingRowColor:
                      const WidgetStatePropertyAll(Color(0xFFEDE9FE)),
                  columnSpacing: 16,
                  columns: [
                    const DataColumn(label: Text('Roll No.')),
                    const DataColumn(label: Text('Student Name')),
                    ...meetings.map((s) => DataColumn(
                        label: Text(DateFormat('MMM d')
                            .format(DateTime.parse(s['date']))))),
                    const DataColumn(label: Text('%'))
                  ],
                  rows: students
                      .map((s) => DataRow(cells: [
                            DataCell(Text(s['roll']!)),
                            DataCell(Text(s['name']!)),
                            ...meetings.map((m) {
                              final v = cell(m, s['roll']!);
                              return DataCell(pill(
                                  v,
                                  v == 'A'
                                      ? const Color(0xFF991B1B)
                                      : const Color(0xFF166534),
                                  v == 'A'
                                      ? const Color(0xFFFEE2E2)
                                      : const Color(0xFFDCFCE7)));
                            }),
                            DataCell(Text(percent(s['roll']!))),
                          ]))
                      .toList())))),
      const Padding(
          padding: EdgeInsets.all(16),
          child: Text('↔ Scroll horizontally to view more dates')),
      if (meetings.isEmpty)
        const Text(
            'No submitted attendance for this month. Mark today’s attendance to begin.'),
    ]);
  }
}
