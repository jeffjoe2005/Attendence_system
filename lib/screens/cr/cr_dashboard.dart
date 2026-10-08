import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/moderator_data_provider.dart';

class CRDashboard extends StatefulWidget {
  const CRDashboard({super.key});

  @override
  State<CRDashboard> createState() => _CRDashboardState();
}

class _CRDashboardState extends State<CRDashboard> {
  String? _selectedCrEmail;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final modData = context.watch<ModeratorDataProvider>();

    if (_selectedCrEmail == null) {
      if (auth.userEmail.isNotEmpty && modData.isCREmail(auth.userEmail)) {
        _selectedCrEmail = auth.userEmail;
      } else if (modData.crs.isNotEmpty) {
        _selectedCrEmail = modData.crs.first['email'];
      }
    }

    final activeEmail = _selectedCrEmail ?? '';
    final crData = modData.crs.firstWhere(
      (c) => c['email'] == activeEmail,
      orElse: () => {'email': activeEmail, 'name': 'CR', 'branch': 'ECE', 'semester': 'IV Sem'},
    );

    final crName = crData['name'] ?? 'Class Representative';
    final crBranch = crData['branch'] ?? 'ECE';
    final crSemester = crData['semester'] ?? 'IV Sem';

    // Courses for this CR's branch and semester
    final classCourses = modData.courses.where((c) {
      final b = c['branch'] ?? '';
      final s = c['semester'] ?? '';
      return (b == crBranch || b == 'General') && s == crSemester;
    }).toList();

    // Students in this CR's class
    final classmates = modData.students.where((s) {
      return (s['branch'] ?? '') == crBranch && (s['semester'] ?? '') == crSemester;
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
                  crName,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('$crBranch CR', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
                ),
              ],
            ),
            Text(
              '$crBranch • $crSemester • $activeEmail',
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
          // ── CR Switcher (For Multi-Branch Testing) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.badge_outlined, size: 18, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                const Text('Active CR:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCrEmail,
                      isDense: true,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      items: modData.crs.map((c) {
                        final email = c['email'] ?? '';
                        final name = c['name'] ?? email;
                        final br = c['branch'] ?? '';
                        final sm = c['semester'] ?? '';
                        return DropdownMenuItem(
                          value: email,
                          child: Text('$name ($br - $sm)'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCrEmail = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Class Summary Stats ──
          Row(
            children: [
              _buildStatCard('Class Subjects', '${classCourses.length}', Icons.menu_book_rounded, const Color(0xFF2563EB)),
              const SizedBox(width: 10),
              _buildStatCard('Classmates', '${classmates.length}', Icons.people_alt_rounded, const Color(0xFF16A34A)),
              const SizedBox(width: 10),
              _buildStatCard('Branch', crBranch, Icons.domain_rounded, const Color(0xFF7C3AED)),
            ],
          ),

          const SizedBox(height: 18),

          // ── Class Courses & Proxy Attendance ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$crBranch $crSemester Timetable Courses',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              Text(
                '${classCourses.length} Courses',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ...classCourses.map((c) {
            final code = c['code'] ?? '';
            final name = c['name'] ?? '';
            final prof = modData.getProfessorForCourse(code) ?? 'Unassigned';
            final sessions = modData.getSessionsForCourse(code);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(code, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${sessions.length} sessions', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 16),

          // ── Classmates Roster ──
          Text(
            '$crBranch Classmates Attendance Roster',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: classmates.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, i) {
                final student = classmates[i];
                final roll = student['roll'] ?? '';
                final sName = student['name'] ?? '';
                final stats = modData.getStudentAttendanceStats(roll);
                final pct = (stats['percentage'] as double).toStringAsFixed(0);
                final isWarning = (stats['percentage'] as double) < 75.0;

                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFEFF6FF),
                    child: Text(
                      roll.length >= 3 ? roll.substring(roll.length - 2) : '#',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                    ),
                  ),
                  title: Text(sName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  subtitle: Text(roll, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isWarning ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isWarning ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color),
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
}
