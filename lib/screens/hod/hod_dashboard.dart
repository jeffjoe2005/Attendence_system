import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/moderator_data_provider.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String? _selectedCourseCode;
  String? _selectedProfessorEmail;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<ModeratorDataProvider>();
    final unassigned = data.unassignedCourses;
    final assigned = data.assignedCourses;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Admin',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black)),
            Text('Map professors to courses',
                style: TextStyle(fontSize: 12, color: Colors.black45)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEEEEEE)),
        ),
        actions: [
          TextButton(
            onPressed: () => context.read<AuthProvider>().signOut(),
            child: const Text('Logout',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: data.courses.isEmpty && data.professorEmails.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No courses or professors available yet.\n\nThe Moderator needs to add courses and professor emails first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15,
                      color: Colors.black45,
                      height: 1.6),
                ),
              ),
            )
          : ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                // ═══════════════════════════════════════
                // SECTION 1: Assign Professor to Course
                // ═══════════════════════════════════════
                _buildCard(
                  title: 'Assign Professor',
                  subtitle: 'Pick a professor and a course to link them',
                  children: [
                    // Course dropdown
                    _buildDropdown<String>(
                      label: 'Select Course',
                      value: _selectedCourseCode,
                      items: unassigned.map((c) {
                        return DropdownMenuItem(
                          value: c['code'],
                          child: Text('${c['name']}  (${c['code']})',
                              style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _selectedCourseCode = val),
                      emptyText: unassigned.isEmpty
                          ? 'All courses assigned'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // Professor dropdown
                    _buildDropdown<String>(
                      label: 'Select Professor',
                      value: _selectedProfessorEmail,
                      items: data.professorEmails.map((email) {
                        return DropdownMenuItem(
                          value: email,
                          child: Text(email,
                              style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _selectedProfessorEmail = val),
                      emptyText: data.professorEmails.isEmpty
                          ? 'No professors available'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Assign button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: (_selectedCourseCode != null &&
                                _selectedProfessorEmail != null)
                            ? () {
                                data.assignProfessor(
                                    _selectedCourseCode!,
                                    _selectedProfessorEmail!);
                                setState(() {
                                  _selectedCourseCode = null;
                                  // Keep professor selected for convenience
                                });
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFD0D0D0),
                          disabledForegroundColor: Colors.white70,
                          elevation: 0,
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Assign',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ═══════════════════════════════════════
                // SECTION 2: Current Assignments
                // ═══════════════════════════════════════
                _buildCard(
                  title: 'Current Assignments',
                  subtitle: '${assigned.length} mapped',
                  children: [
                    if (assigned.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('No assignments yet',
                            style: TextStyle(
                                fontSize: 13, color: Colors.black38)),
                      )
                    else
                      ...assigned.map((c) {
                        final code = c['code']!;
                        final profEmail = data.getProfessorForCourse(code)!;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(c['name']!,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87)),
                                    const SizedBox(height: 2),
                                    Text(code,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black45)),
                                    const SizedBox(height: 6),
                                    Text(profEmail,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black54)),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => data.removeAssignment(code),
                                child: const Text('✕',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black38)),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),

                const SizedBox(height: 16),

                // ═══════════════════════════════════════
                // SECTION 3: All Professors
                // ═══════════════════════════════════════
                _buildCard(
                  title: 'Professors',
                  subtitle: '${data.professorEmails.length} listed',
                  children: [
                    if (data.professorEmails.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('No professors added by moderator',
                            style: TextStyle(
                                fontSize: 13, color: Colors.black38)),
                      )
                    else
                      ...data.professorEmails.map((email) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(email,
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.black87)),
                        );
                      }),
                  ],
                ),

                const SizedBox(height: 16),

                // ═══════════════════════════════════════
                // SECTION 4: All Courses
                // ═══════════════════════════════════════
                _buildCard(
                  title: 'Courses',
                  subtitle: '${data.courses.length} listed',
                  children: [
                    if (data.courses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('No courses added by moderator',
                            style: TextStyle(
                                fontSize: 13, color: Colors.black38)),
                      )
                    else
                      ...data.courses.map((c) {
                        final profEmail =
                            data.getProfessorForCourse(c['code']!);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(c['name']!,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87)),
                                    const SizedBox(height: 2),
                                    Text(c['code']!,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black45)),
                                  ],
                                ),
                              ),
                              if (profEmail != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8E8E8),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('Assigned',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black54)),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('Unassigned',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.orange.shade800)),
                                ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  // ── Reusable card ──
  Widget _buildCard({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      letterSpacing: -0.3)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // ── Reusable dropdown ──
  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? emptyText,
  }) {
    if (emptyText != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Text(emptyText,
            style: const TextStyle(fontSize: 14, color: Colors.black26)),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(label,
              style: const TextStyle(fontSize: 14, color: Colors.black26)),
          isExpanded: true,
          icon: const Text('▾',
              style: TextStyle(fontSize: 14, color: Colors.black38)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
