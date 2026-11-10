import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/moderator_data_provider.dart';

// ─────────────────────────────────────────────────────────────
//  Branch colour palette
// ─────────────────────────────────────────────────────────────
Color _branchColor(String branch) {
  switch (branch.toUpperCase()) {
    case 'CSE':  return const Color(0xFF7C3AED);
    case 'ECE':  return const Color(0xFF2563EB);
    case 'EEE':  return const Color(0xFFD97706);
    case 'MCE':
    case 'ME':   return const Color(0xFF059669);
    case 'CVE':
    case 'CE':   return const Color(0xFFEA580C);
    default:     return const Color(0xFF475569);
  }
}

Color _branchBg(String branch) {
  switch (branch.toUpperCase()) {
    case 'CSE':  return const Color(0xFFF5F3FF);
    case 'ECE':  return const Color(0xFFEFF6FF);
    case 'EEE':  return const Color(0xFFFEF3C7);
    case 'MCE':
    case 'ME':   return const Color(0xFFECFDF5);
    case 'CVE':
    case 'CE':   return const Color(0xFFFFF7ED);
    default:     return const Color(0xFFF1F5F9);
  }
}

// ─────────────────────────────────────────────────────────────
//  Attendance colour helpers (class average)
// ─────────────────────────────────────────────────────────────
Color _attColor(double pct) {
  if (pct < 75) return const Color(0xFFEF4444);
  if (pct <= 80) return const Color(0xFFF59E0B);
  return const Color(0xFF22C55E);
}

Color _attBg(double pct) {
  if (pct < 75) return const Color(0xFFFEF2F2);
  if (pct <= 80) return const Color(0xFFFFFBEB);
  return const Color(0xFFF0FDF4);
}

String _attLabel(double pct) {
  if (pct < 75) return 'Below 75%';
  if (pct <= 80) return 'Borderline';
  return 'Healthy';
}

// ─────────────────────────────────────────────────────────────
//  Professor Dashboard
// ─────────────────────────────────────────────────────────────
class ProfessorDashboard extends StatefulWidget {
  const ProfessorDashboard({super.key});

  @override
  State<ProfessorDashboard> createState() => _ProfessorDashboardState();
}

class _ProfessorDashboardState extends State<ProfessorDashboard>
    with SingleTickerProviderStateMixin {
  String? _selectedProfEmail;
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _switchProf(String email) {
    setState(() => _selectedProfEmail = email);
    _animCtrl
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
    final modData = context.watch<ModeratorDataProvider>();

    // Resolve active professor
    if (_selectedProfEmail == null ||
        !modData.professors.any((p) => p['email'] == _selectedProfEmail)) {
      if (auth.userEmail.isNotEmpty &&
          modData.isProfessorEmail(auth.userEmail)) {
        _selectedProfEmail = auth.userEmail;
      } else if (modData.professors.isNotEmpty) {
        _selectedProfEmail = modData.professors.first['email'];
      }
    }

    final activeEmail = _selectedProfEmail ?? '';
    final profName = modData.getProfessorNameByEmail(activeEmail) ??
        (activeEmail.isNotEmpty
            ? ModeratorDataProvider.extractNameFromEmail(activeEmail)
            : 'Faculty');

    final profData = modData.professors.firstWhere(
      (p) => p['email'] == activeEmail,
      orElse: () => {'email': activeEmail, 'name': profName, 'department': ''},
    );
    final dept = profData['department'] ?? '';

    // Courses assigned to this professor
    final myCourses = modData.courses.where((c) {
      return modData.isCourseAssignedToProfessor(
          c['code'] ?? '', activeEmail);
    }).toList();

    // Aggregate stats
    int totalLectures = 0;
    for (final c in myCourses) {
      totalLectures += modData.getSessionsForCourse(c['code'] ?? '').length;
    }

    // Class-average attendance across all sessions this prof has taken
    double overallClassAvg = 0;
    int sessionCount = 0;
    for (final c in myCourses) {
      for (final s in modData.getSessionsForCourse(c['code'] ?? '')) {
        final presents = List<String>.from(s['presentRolls'] as Iterable? ?? []);
        final absents  = List<String>.from(s['absentRolls']  as Iterable? ?? []);
        final total    = presents.length + absents.length;
        if (total > 0) {
          overallClassAvg += (presents.length / total) * 100;
          sessionCount++;
        }
      }
    }
    if (sessionCount > 0) overallClassAvg /= sessionCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // ── Dark header ──────────────────────────────────
            _ProfHeader(
              profName    : profName,
              activeEmail : activeEmail,
              dept        : dept,
              professors  : modData.professors,
              selectedEmail: _selectedProfEmail,
              onSwitch    : _switchProf,
              onSignOut   : () => context.read<AuthProvider>().signOut(),
            ),

            // ── Body ─────────────────────────────────────────
            Expanded(
              child: AnimatedBuilder(
                animation: _animCtrl,
                builder: (context, child) => FadeTransition(
                  opacity: CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
                  child: child,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    // ── Stats row ──────────────────────────
                    _StatsRow(
                      courseCount   : myCourses.length,
                      lectureCount  : totalLectures,
                      classAvg      : sessionCount > 0 ? overallClassAvg : null,
                    ),

                    const SizedBox(height: 20),

                    // ── Section heading ───────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'My Assigned Courses',
                          style: TextStyle(
                            fontSize    : 15,
                            fontWeight  : FontWeight.w800,
                            color       : Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color       : const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${myCourses.length} active',
                            style: const TextStyle(
                              fontSize  : 11,
                              fontWeight: FontWeight.w700,
                              color     : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Course cards ──────────────────────
                    if (myCourses.isEmpty)
                      _EmptyCard(profName: profName)
                    else
                      ...myCourses.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final c   = entry.value;
                        final delay = (idx * 0.08).clamp(0.0, 0.7);
                        final curve = Interval(delay, (delay + 0.4).clamp(0.0, 1.0),
                            curve: Curves.easeOut);
                        final slideAnim = Tween<Offset>(
                          begin: const Offset(0, 0.2),
                          end  : Offset.zero,
                        ).animate(CurvedAnimation(parent: _animCtrl, curve: curve));

                        return SlideTransition(
                          position: slideAnim,
                          child: _CourseCard(
                            course  : c,
                            modData : modData,
                            profName: profName,
                            profEmail: activeEmail,
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Dark header
// ─────────────────────────────────────────────────────────────
class _ProfHeader extends StatelessWidget {
  const _ProfHeader({
    required this.profName,
    required this.activeEmail,
    required this.dept,
    required this.professors,
    required this.selectedEmail,
    required this.onSwitch,
    required this.onSignOut,
  });

  final String                     profName;
  final String                     activeEmail;
  final String                     dept;
  final List<Map<String, dynamic>> professors;
  final String?                    selectedEmail;
  final ValueChanged<String>       onSwitch;
  final VoidCallback               onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      color  : const Color(0xFF0F172A),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width : 44,
                height: 44,
                decoration: BoxDecoration(
                  shape : BoxShape.circle,
                  color : const Color(0xFF1E293B),
                  border: Border.all(color: const Color(0xFF334155), width: 2),
                ),
                child: Center(
                  child: Text(
                    profName.isNotEmpty ? profName[0].toUpperCase() : 'P',
                    style: const TextStyle(
                      fontSize  : 18,
                      fontWeight: FontWeight.w800,
                      color     : Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profName,
                      style: const TextStyle(
                        fontSize  : 17,
                        fontWeight: FontWeight.w800,
                        color     : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _Chip(label: 'Faculty Portal'),
                        if (dept.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _Chip(label: dept, dimmed: true),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Sign-out
              GestureDetector(
                onTap: onSignOut,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color       : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Faculty switcher
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color       : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
              border      : Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                const Text(
                  'Viewing As:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value          : professors.any((p) => p['email'] == selectedEmail) ? selectedEmail : null,
                      isDense        : true,
                      isExpanded     : true,
                      dropdownColor  : const Color(0xFF1E293B),
                      iconEnabledColor: const Color(0xFF64748B),
                      style          : const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      items: professors.map<DropdownMenuItem<String>>((p) {
                        final email = p['email'] as String? ?? '';
                        final name  = p['name']  as String? ?? email;
                        final d     = p['department'] as String? ?? '';
                        return DropdownMenuItem<String>(
                          value: email,
                          child: Text(
                            d.isNotEmpty ? '$name  ·  $d' : name,
                            style: const TextStyle(fontSize: 12, color: Colors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) { if (val != null) onSwitch(val); },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.dimmed = false});
  final String label;
  final bool   dimmed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color       : dimmed ? Colors.transparent : const Color(0xFF334155),
        borderRadius: BorderRadius.circular(4),
        border      : dimmed ? Border.all(color: const Color(0xFF334155)) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize  : 10,
          fontWeight: FontWeight.w700,
          color     : dimmed ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Stats row
// ─────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.courseCount,
    required this.lectureCount,
    required this.classAvg,
  });

  final int    courseCount;
  final int    lectureCount;
  final double? classAvg;

  @override
  Widget build(BuildContext context) {
    final avgDisplay = classAvg != null ? '${classAvg!.toStringAsFixed(1)}%' : '—';
    final avgColor   = classAvg != null ? _attColor(classAvg!) : const Color(0xFF64748B);

    return Row(
      children: [
        _StatCard(label: 'Courses',    value: '$courseCount',   color: const Color(0xFF2563EB), icon: Icons.book_outlined),
        const SizedBox(width: 10),
        _StatCard(label: 'Lectures',   value: '$lectureCount',  color: const Color(0xFF16A34A), icon: Icons.calendar_month_outlined),
        const SizedBox(width: 10),
        _StatCard(label: 'Class Avg',  value: avgDisplay,       color: avgColor,                icon: Icons.bar_chart_rounded),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color, required this.icon});
  final String   label;
  final String   value;
  final Color    color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color       : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border      : Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow   : const [BoxShadow(color: Color(0x07000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Course card with class-average attendance badge + actions
// ─────────────────────────────────────────────────────────────
class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.modData,
    required this.profName,
    required this.profEmail,
  });

  final Map<String, dynamic>  course;
  final ModeratorDataProvider modData;
  final String                profName;
  final String                profEmail;

  /// Compute class-average attendance % for a course
  double _classAvg(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) return -1;
    double sum = 0;
    int count  = 0;
    for (final s in sessions) {
      final presents = List<String>.from(s['presentRolls'] as Iterable? ?? []);
      final absents  = List<String>.from(s['absentRolls']  as Iterable? ?? []);
      final total    = presents.length + absents.length;
      if (total > 0) {
        sum += (presents.length / total) * 100;
        count++;
      }
    }
    return count > 0 ? sum / count : -1;
  }

  @override
  Widget build(BuildContext context) {
    final code    = course['code']     as String? ?? '';
    final name    = course['name']     as String? ?? '';
    final branch  = course['branch']   as String? ?? ModeratorDataProvider.deriveBranch(code);
    final sem     = course['semester'] as String? ?? 'General';
    final type    = course['type']     as String? ?? 'Theory';
    final sessions = modData.getSessionsForCourse(code);
    final avg     = _classAvg(sessions);
    final hasAvg  = avg >= 0;

    final bColor = _branchColor(branch);
    final bBg    = _branchBg(branch);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border      : Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow   : const [BoxShadow(color: Color(0x07000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Top colour strip in branch colour
          Container(
            height     : 4,
            decoration : BoxDecoration(
              color        : bColor,
              borderRadius : const BorderRadius.vertical(top: Radius.circular(14)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row ──────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Course code box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color       : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        code,
                        style: const TextStyle(
                          fontSize  : 11,
                          fontWeight: FontWeight.w900,
                          color     : Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              // Branch badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: bBg, borderRadius: BorderRadius.circular(4)),
                                child: Text(branch, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: bColor)),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$sem  ·  $type',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Class avg badge
                    if (hasAvg)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color       : _attBg(avg),
                          borderRadius: BorderRadius.circular(8),
                          border      : Border.all(color: _attColor(avg).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${avg.toStringAsFixed(0)}%',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _attColor(avg)),
                            ),
                            Text(
                              'class avg',
                              style: TextStyle(fontSize: 8, color: _attColor(avg), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Class avg progress bar ────────────────
                if (hasAvg) ...[
                  _ClassAvgBar(avg: avg),
                  const SizedBox(height: 10),
                ],

                // ── Sessions count info ───────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.event_note_outlined, size: 13, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          sessions.isEmpty
                              ? 'No lectures yet'
                              : '${sessions.length} lecture${sessions.length == 1 ? '' : 's'} recorded',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    if (hasAvg)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color       : _attBg(avg),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _attLabel(avg),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _attColor(avg)),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // ── Action buttons ────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openTakeAttendanceSheet(context, modData, course),
                        icon : const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Take Attendance',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor : Colors.white,
                          elevation       : 0,
                          minimumSize     : const Size(0, 40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _openHistoryDialog(context, modData, code, name),
                      icon : const Icon(Icons.history_rounded, size: 15),
                      label: Text('Logs (${sessions.length})',
                          style: const TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF334155),
                        minimumSize    : const Size(0, 40),
                        side           : const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Take Attendance Bottom Sheet ──────────────────────────
  void _openTakeAttendanceSheet(
    BuildContext context,
    ModeratorDataProvider modData,
    Map<String, dynamic> c,
  ) {
    final code   = c['code']     as String? ?? '';
    final name   = c['name']     as String? ?? '';
    final branch = c['branch']   as String? ?? ModeratorDataProvider.deriveBranch(code);
    final sem    = c['semester'] as String? ?? 'IV Sem';

    final students = modData.getStudentsForCourse(code);
    final now      = DateTime.now();
    final todayDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final lectureNumber = modData.getSessionsForCourse(code).length + 1;

    final Map<String, bool> attendanceState = {};
    for (int i = 0; i < students.length; i++) {
      final roll = (students[i]['roll'] ?? '').trim();
      attendanceState[roll.isNotEmpty ? roll : 'student_$i'] = true;
    }

    showModalBottomSheet(
      context          : context,
      isScrollControlled: true,
      backgroundColor  : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final presentCount = attendanceState.values.where((v) => v).length;
            final absentCount  = attendanceState.length - presentCount;
            final pct = attendanceState.isNotEmpty
                ? (presentCount / attendanceState.length * 100).toStringAsFixed(0)
                : '0';
            final pctDouble = attendanceState.isNotEmpty
                ? presentCount / attendanceState.length * 100
                : 0.0;

            return SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.88,
              child: Column(
                children: [
                  // Handle bar
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 4),
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mark Attendance · $code',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    '$name  ($branch · $sem)',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Date + lecture number + quick buttons
                        Row(
                          children: [
                            _InfoPill(
                              icon : Icons.calendar_today_outlined,
                              label: todayDate,
                            ),
                            const SizedBox(width: 8),
                            _InfoPill(
                              icon : Icons.format_list_numbered_rounded,
                              label: 'Lecture #$lectureNumber',
                              blue : true,
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => setSheet(() {
                                for (final k in attendanceState.keys) {
                                  attendanceState[k] = true;
                                }
                              }),
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              child: const Text('All Present',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                            ),
                            TextButton(
                              onPressed: () => setSheet(() {
                                for (final k in attendanceState.keys) {
                                  attendanceState[k] = false;
                                }
                              }),
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              child: const Text('All Absent',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Live stats banner
                  Container(
                    margin : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color       : _attBg(pctDouble),
                      borderRadius: BorderRadius.circular(10),
                      border      : Border.all(color: _attColor(pctDouble).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SheetStat(label: 'Present', value: '$presentCount', color: const Color(0xFF16A34A)),
                        _SheetStat(label: 'Absent',  value: '$absentCount',  color: const Color(0xFFEF4444)),
                        _SheetStat(label: 'Session', value: '$pct%',         color: _attColor(pctDouble)),
                      ],
                    ),
                  ),

                  // Student list
                  Expanded(
                    child: ListView.separated(
                      padding        : const EdgeInsets.symmetric(horizontal: 16),
                      itemCount      : students.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (ctx, i) {
                        final s         = students[i];
                        final roll      = s['roll'] ?? '';
                        final sName     = s['name'] ?? '';
                        final key       = roll.trim().isNotEmpty ? roll.trim() : 'student_$i';
                        final isPresent = attendanceState[key] ?? true;

                        return InkWell(
                          onTap: () => setSheet(() => attendanceState[key] = !isPresent),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                // Index
                                Text(
                                  '${i + 1}.',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 8),
                                // Roll number
                                Container(
                                  width  : 76,
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color       : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(roll, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                                ),
                                const SizedBox(width: 10),
                                // Name
                                Expanded(
                                  child: Text(sName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                                ),
                                // Present / Absent toggle badge
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding : const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color : isPresent ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isPresent ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                    ),
                                  ),
                                  child: Text(
                                    isPresent ? 'P' : 'A',
                                    style: TextStyle(
                                      fontSize  : 12,
                                      fontWeight: FontWeight.w900,
                                      color     : isPresent ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Submit button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color : Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: SizedBox(
                      width : double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          final presents = <String>[];
                          final absents  = <String>[];
                          attendanceState.forEach((roll, present) {
                            if (present) {
                              presents.add(roll);
                            } else {
                              absents.add(roll);
                            }
                          });
                          modData.recordAttendance(
                            courseCode   : code,
                            date         : todayDate,
                            lectureNumber: lectureNumber,
                            markedBy     : profEmail,
                            markedByName : profName,
                            presentRolls : presents,
                            absentRolls  : absents,
                          );
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                'Lecture #$lectureNumber recorded for $code  ·  $presentCount/${attendanceState.length} present'),
                            backgroundColor: const Color(0xFF0F172A),
                          ));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          'Submit — $presentCount / ${attendanceState.length} Present',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Attendance History Dialog ─────────────────────────────
  void _openHistoryDialog(
    BuildContext context,
    ModeratorDataProvider modData,
    String courseCode,
    String courseName,
  ) {
    final sessions = modData.getSessionsForCourse(courseCode);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Attendance History · $courseCode',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(courseName, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: sessions.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('No lectures recorded yet.',
                          style: TextStyle(color: Color(0xFF64748B))),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap     : true,
                    itemCount      : sessions.length,
                    separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F5F9)),
                    itemBuilder: (ctx, i) {
                      final s       = sessions[i];
                      final date    = s['date']          as String? ?? '';
                      final lec     = s['lectureNumber'] as int? ?? (i + 1);
                      final presents= List<String>.from(s['presentRolls'] as Iterable? ?? []);
                      final absents = List<String>.from(s['absentRolls']  as Iterable? ?? []);
                      final total   = presents.length + absents.length;
                      final pct     = total > 0
                          ? (presents.length / total * 100)
                          : 0.0;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFEFF6FF),
                          child: Text('#$lec',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                        ),
                        title: Text(date, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          absents.isEmpty ? 'Full attendance' : 'Absent: ${absents.join(', ')}',
                          style: TextStyle(
                            fontSize: 11,
                            color   : absents.isEmpty ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color       : _attBg(pct),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${pct.toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _attColor(pct)),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style    : ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Class-average progress bar
// ─────────────────────────────────────────────────────────────
class _ClassAvgBar extends StatelessWidget {
  const _ClassAvgBar({required this.avg});
  final double avg;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height     : 7,
            decoration : BoxDecoration(
              color       : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          AnimatedContainer(
            duration   : const Duration(milliseconds: 600),
            curve      : Curves.easeOut,
            height     : 7,
            width      : (avg / 100 * w).clamp(0, w),
            decoration : BoxDecoration(color: _attColor(avg), borderRadius: BorderRadius.circular(4)),
          ),
          // 75% marker
          Positioned(left: w * 0.75 - 1, top: -2, child: Container(width: 2, height: 11, color: const Color(0xFF94A3B8))),
          // 80% marker
          Positioned(left: w * 0.80 - 1, top: -2, child: Container(width: 2, height: 11, color: const Color(0xFF94A3B8))),
          // Labels
          Positioned(left: (w * 0.75 - 8).clamp(0, w - 24), top: 11,
              child: const Text('75%', style: TextStyle(fontSize: 8, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700))),
          Positioned(left: (w * 0.80 - 8).clamp(0, w - 24), top: 11,
              child: const Text('80%', style: TextStyle(fontSize: 8, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700))),
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────
//  Small helpers
// ─────────────────────────────────────────────────────────────
class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label, this.blue = false});
  final IconData icon;
  final String   label;
  final bool     blue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color       : blue ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: blue ? const Color(0xFF2563EB) : const Color(0xFF475569)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                fontSize  : 11,
                fontWeight: FontWeight.w700,
                color     : blue ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
              )),
        ],
      ),
    );
  }
}

class _SheetStat extends StatelessWidget {
  const _SheetStat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.profName});
  final String profName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border      : Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.school_outlined, size: 48, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 12),
          const Text(
            'No Courses Assigned',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          Text(
            'No courses are mapped to $profName yet.\nAsk the moderator to assign courses.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
          ),
        ],
      ),
    );
  }
}
