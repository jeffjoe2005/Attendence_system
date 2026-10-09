import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/moderator_data_provider.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  String? _selectedRoll;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final modData = context.watch<ModeratorDataProvider>();

    // Determine active student
    if (_selectedRoll == null) {
      if (auth.userModel?.rollNumber.isNotEmpty ?? false) {
        _selectedRoll = auth.userModel!.rollNumber;
      } else if (modData.students.isNotEmpty) {
        _selectedRoll = modData.students.first['roll'];
      }
    }

    final activeRoll = _selectedRoll ?? '';
    final studentData = modData.students.firstWhere(
      (s) => s['roll'] == activeRoll,
      orElse: () => {'roll': activeRoll, 'name': 'Student', 'branch': 'ECE', 'semester': 'IV Sem', 'email': 'student@nitgoa.ac.in'},
    );

    final studentName = studentData['name'] ?? 'Student';
    final branch = studentData['branch'] ?? 'ECE';
    final semester = studentData['semester'] ?? 'IV Sem';

    // Enrolled courses for this student's branch and semester
    final enrolledCourses = modData.courses.where((c) {
      final b = c['branch'] ?? '';
      final s = c['semester'] ?? '';
      return (b == branch || b == 'General') && s == semester;
    }).toList();

    // Compute student stats
    final overallStats = modData.getStudentAttendanceStats(activeRoll);
    final overallPct = (overallStats['percentage'] as num?)?.toDouble() ?? 85.0;
    final isShortAttendance = overallPct < 75.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  studentName,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('$branch Student', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                ),
              ],
            ),
            Text(
              '$activeRoll • $branch • $semester',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE2E8F0)),
        ),
        actions: [
          TextButton(
            onPressed: () => context.read<AuthProvider>().signOut(),
            child: const Text('Logout', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // ── Student Switcher (Test across all 5 branches) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_pin_circle_outlined, size: 18, color: Color(0xFF059669)),
                const SizedBox(width: 8),
                const Text('Active Student:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedRoll,
                      isDense: true,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      items: modData.students.map((s) {
                        final roll = s['roll'] ?? '';
                        final name = s['name'] ?? roll;
                        final br = s['branch'] ?? '';
                        return DropdownMenuItem(
                          value: roll,
                          child: Text('$name ($roll • $br)'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedRoll = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Overall Attendance Hero Card ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isShortAttendance
                    ? [const Color(0xFF991B1B), const Color(0xFFDC2626)]
                    : [const Color(0xFF0F172A), const Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 3)),
              ],
            ),
            child: Row(
              children: [
                // Percentage badge circle
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 3),
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  child: Center(
                    child: Text(
                      '${overallPct.toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isShortAttendance ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                            size: 16,
                            color: isShortAttendance ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isShortAttendance ? 'CRITICAL ATTENDANCE ALERT' : 'EXAM ELIGIBILITY SAFE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isShortAttendance ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isShortAttendance
                            ? 'Attendance is below 75% threshold! Attend upcoming lectures to regain eligibility.'
                            : 'Above 75% mandatory NIT Goa attendance requirement. Keep it up!',
                        style: const TextStyle(fontSize: 12, color: Colors.white, height: 1.3),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Total: ${overallStats['attended']} attended of ${overallStats['total']} total classes',
                        style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ── Subject-Wise Attendance Breakdown ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Course-wise Attendance Breakdown',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              Text(
                '${enrolledCourses.length} Subjects',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ...enrolledCourses.map((c) {
            final code = c['code'] ?? '';
            final name = c['name'] ?? '';
            final prof = modData.getProfessorForCourse(code) ?? 'Unassigned';
            final sessions = modData.getSessionsForCourse(code);

            // Compute subject attendance
            int attendedInSubject = 0;
            int totalInSubject = sessions.length;

            for (final s in sessions) {
              final presents = List<String>.from(s['presentRolls'] as Iterable? ?? []);
              if (presents.contains(activeRoll)) {
                attendedInSubject++;
              }
            }

            final subjectPct = totalInSubject > 0 ? (attendedInSubject / totalInSubject) * 100 : 85.0;
            final isLow = subjectPct < 75.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(code, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                            const SizedBox(height: 2),
                            Text('Faculty: $prof', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isLow ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${subjectPct.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isLow ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: subjectPct / 100,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isLow ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        totalInSubject > 0 ? '$attendedInSubject of $totalInSubject lectures attended' : 'No lectures recorded yet',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      Text(
                        isLow ? '⚠️ Short attendance' : 'Eligible',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isLow ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
