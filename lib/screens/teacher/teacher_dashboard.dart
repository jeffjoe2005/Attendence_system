import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/moderator_data_provider.dart';

class ProfessorDashboard extends StatefulWidget {
  const ProfessorDashboard({super.key});

  @override
  State<ProfessorDashboard> createState() => _ProfessorDashboardState();
}

class _ProfessorDashboardState extends State<ProfessorDashboard> {
  String? _selectedProfEmail;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final modData = context.watch<ModeratorDataProvider>();

    // Determine active professor email
    if (_selectedProfEmail == null) {
      if (auth.userEmail.isNotEmpty && modData.isProfessorEmail(auth.userEmail)) {
        _selectedProfEmail = auth.userEmail;
      } else if (modData.professors.isNotEmpty) {
        _selectedProfEmail = modData.professors.first['email'];
      }
    }

    final activeEmail = _selectedProfEmail ?? '';
    final profName = modData.getProfessorNameByEmail(activeEmail) ??
        (activeEmail.isNotEmpty ? ModeratorDataProvider.extractNameFromEmail(activeEmail) : 'Faculty');

    // Filter courses mapped to this professor
    final myCourses = modData.courses.where((c) {
      final assigned = modData.getProfessorForCourse(c['code'] ?? '') ?? '';
      return activeEmail.isNotEmpty && assigned.toLowerCase().contains(activeEmail.toLowerCase());
    }).toList();

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
                  profName,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Faculty Portal', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                ),
              ],
            ),
            Text(
              activeEmail.isNotEmpty ? activeEmail : 'faculty@nitgoa.ac.in',
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
          // ── Faculty Switcher & Status Bar (For Development & Testing) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.swap_horiz_rounded, size: 18, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                const Text('Viewing As:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedProfEmail,
                      isDense: true,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      items: modData.professors.map((p) {
                        final email = p['email'] ?? '';
                        final name = p['name'] ?? email;
                        final dept = p['department'] ?? '';
                        return DropdownMenuItem(
                          value: email,
                          child: Text('$name ($dept)'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedProfEmail = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Quick Summary Stats ──
          Row(
            children: [
              _buildStatCard('Assigned Courses', '${myCourses.length}', Icons.book_outlined, const Color(0xFF2563EB)),
              const SizedBox(width: 10),
              _buildStatCard(
                'Total Lectures',
                '${myCourses.fold<int>(0, (acc, c) => acc + modData.getSessionsForCourse(c['code'] ?? '').length)}',
                Icons.calendar_month_outlined,
                const Color(0xFF16A34A),
              ),
              const SizedBox(width: 10),
              _buildStatCard('Students Taught', '${myCourses.length * 8}', Icons.group_outlined, const Color(0xFFD97706)),
            ],
          ),

          const SizedBox(height: 18),

          // ── Section Title ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Assigned Courses',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              Text(
                '${myCourses.length} Courses Active',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Courses List ──
          if (myCourses.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.school_outlined, size: 40, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 10),
                    Text(
                      'No courses assigned to $profName yet',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Switch to Admin portal to map courses, or choose another professor above.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            )
          else
            ...myCourses.map((c) {
              final code = c['code'] ?? '';
              final name = c['name'] ?? '';
              final branch = c['branch'] ?? ModeratorDataProvider.deriveBranch(code);
              final sem = c['semester'] ?? 'General';
              final type = c['type'] ?? 'Theory';
              final sessions = modData.getSessionsForCourse(code);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Course Code Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            code,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Title & Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  // Branch Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getBranchBgColor(branch),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      branch,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _getBranchBadgeColor(branch)),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$sem  •  $type',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${sessions.length} Lectures',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),

                    // Action Buttons: Take Attendance & History
                    Row(
                      children: [
                        // TAKE ATTENDANCE BUTTON
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _openTakeAttendanceSheet(context, modData, c, profName, activeEmail),
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: const Text('Take Attendance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              minimumSize: const Size(0, 38),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // VIEW HISTORY BUTTON
                        OutlinedButton.icon(
                          onPressed: () => _openAttendanceHistoryDialog(context, modData, code, name),
                          icon: const Icon(Icons.history_rounded, size: 15),
                          label: Text('Logs (${sessions.length})', style: const TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF334155),
                            minimumSize: const Size(0, 38),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  // ── Take Attendance Modal Bottom Sheet ──
  void _openTakeAttendanceSheet(
    BuildContext context,
    ModeratorDataProvider modData,
    Map<String, String> course,
    String profName,
    String profEmail,
  ) {
    final code = course['code'] ?? '';
    final name = course['name'] ?? '';
    final branch = course['branch'] ?? ModeratorDataProvider.deriveBranch(code);
    final sem = course['semester'] ?? 'IV Sem';

    final students = modData.getStudentsForCourse(code);
    final now = DateTime.now();
    final todayDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    int lectureNumber = modData.getSessionsForCourse(code).length + 1;
    // Map to track attendance status: studentRoll -> bool isPresent
    final Map<String, bool> attendanceState = {
      for (final s in students) s['roll'] ?? '': true, // Default all present
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final presentCount = attendanceState.values.where((v) => v).length;
            final absentCount = attendanceState.length - presentCount;
            final percentage = attendanceState.isNotEmpty ? ((presentCount / attendanceState.length) * 100).toStringAsFixed(0) : '0';

            return SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.85,
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mark Attendance • $code',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                ),
                                Text(
                                  '$name ($branch - $sem)',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Date & Lecture Slot Info
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF475569)),
                                  const SizedBox(width: 5),
                                  Text(todayDate, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Lecture #$lectureNumber',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                              ),
                            ),
                            const Spacer(),
                            // Quick Action Buttons
                            TextButton(
                              onPressed: () {
                                setSheetState(() {
                                  for (final k in attendanceState.keys) {
                                    attendanceState[k] = true;
                                  }
                                });
                              },
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              child: const Text('All Present', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                            ),
                            TextButton(
                              onPressed: () {
                                setSheetState(() {
                                  for (final k in attendanceState.keys) {
                                    attendanceState[k] = false;
                                  }
                                });
                              },
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              child: const Text('All Absent', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Stats banner
                  Container(
                    color: const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Present: $presentCount', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                        Text('Absent: $absentCount', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                        Text('Attendance: $percentage%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                      ],
                    ),
                  ),

                  // Student Roster
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: students.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (ctx, i) {
                        final s = students[i];
                        final roll = s['roll'] ?? '';
                        final sName = s['name'] ?? '';
                        final isPresent = attendanceState[roll] ?? true;

                        return InkWell(
                          onTap: () {
                            setSheetState(() {
                              attendanceState[roll] = !isPresent;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                // Roll Number
                                Container(
                                  width: 80,
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    roll,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Student Name
                                Expanded(
                                  child: Text(
                                    sName,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                  ),
                                ),

                                // Status Indicator Switch
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isPresent ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isPresent ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                    ),
                                  ),
                                  child: Text(
                                    isPresent ? 'PRESENT' : 'ABSENT',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isPresent ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
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

                  // Bottom Submit Button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () {
                          final presents = <String>[];
                          final absents = <String>[];
                          attendanceState.forEach((roll, present) {
                            if (present) {
                              presents.add(roll);
                            } else {
                              absents.add(roll);
                            }
                          });

                          modData.recordAttendance(
                            courseCode: code,
                            date: todayDate,
                            lectureNumber: lectureNumber,
                            markedBy: profEmail,
                            markedByName: profName,
                            presentRolls: presents,
                            absentRolls: absents,
                          );

                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Recorded Lecture #$lectureNumber for $code! ($presentCount/${students.length} present)'),
                              backgroundColor: const Color(0xFF0F172A),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          'Submit Attendance ($presentCount/${students.length} Present)',
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

  // ── View Attendance History Modal ──
  void _openAttendanceHistoryDialog(
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Attendance History • $courseCode', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(courseName, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: sessions.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('No attendance lectures recorded yet.', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: sessions.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (ctx, i) {
                      final s = sessions[i];
                      final date = s['date'] ?? '';
                      final lec = s['lectureNumber'] ?? 1;
                      final presents = (s['presentRolls'] as List<String>? ?? []);
                      final absents = (s['absentRolls'] as List<String>? ?? []);
                      final total = presents.length + absents.length;
                      final pct = total > 0 ? ((presents.length / total) * 100).toStringAsFixed(0) : '0';

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFEFF6FF),
                          child: Text('#$lec', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                        ),
                        title: Text('Date: $date', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          absents.isEmpty ? 'All students present' : 'Absent: ${absents.join(', ')}',
                          style: TextStyle(fontSize: 11, color: absents.isEmpty ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('$pct%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 18, color: color),
                Text(
                  value,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBranchBadgeColor(String branch) {
    switch (branch.toUpperCase()) {
      case 'CSE':
        return const Color(0xFF7C3AED);
      case 'ECE':
        return const Color(0xFF2563EB);
      case 'EEE':
        return const Color(0xFFD97706);
      case 'ME':
        return const Color(0xFF059669);
      case 'CE':
        return const Color(0xFFEA580C);
      default:
        return const Color(0xFF475569);
    }
  }

  Color _getBranchBgColor(String branch) {
    switch (branch.toUpperCase()) {
      case 'CSE':
        return const Color(0xFFF5F3FF);
      case 'ECE':
        return const Color(0xFFEFF6FF);
      case 'EEE':
        return const Color(0xFFFEF3C7);
      case 'ME':
        return const Color(0xFFECFDF5);
      case 'CE':
        return const Color(0xFFFFF7ED);
      default:
        return const Color(0xFFF1F5F9);
    }
  }
}
