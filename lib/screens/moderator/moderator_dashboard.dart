import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/moderator_data_provider.dart';

class ModeratorDashboard extends StatefulWidget {
  const ModeratorDashboard({super.key});

  @override
  State<ModeratorDashboard> createState() => _ModeratorDashboardState();
}

class _ModeratorDashboardState extends State<ModeratorDashboard> {
  // ── Controllers ──
  final _courseNameCtrl = TextEditingController();
  final _courseCodeCtrl = TextEditingController();
  final _profEmailCtrl = TextEditingController();
  final _crEmailCtrl = TextEditingController();

  @override
  void dispose() {
    _courseNameCtrl.dispose();
    _courseCodeCtrl.dispose();
    _profEmailCtrl.dispose();
    _crEmailCtrl.dispose();
    super.dispose();
  }

  void _resetSemester(ModeratorDataProvider data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Reset Semester',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: const Text(
          'This will clear all courses, professor emails, and CR emails. Are you sure?',
          style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              data.resetSemester();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<ModeratorDataProvider>();

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
            Text('Moderator',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black)),
            Text('Manage courses & emails',
                style: TextStyle(fontSize: 12, color: Colors.black45)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEEEEEE)),
        ),
        actions: [
          TextButton(
            onPressed: () => _resetSemester(data),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade600,
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            child: const Text('Reset Sem'),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: () => context.read<AuthProvider>().signOut(),
            child: const Text('Logout',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // ═══════════════════════════════════════
          // SECTION 1: Courses
          // ═══════════════════════════════════════
          _buildSectionCard(
            title: 'Courses',
            subtitle: '${data.courses.length} added',
            children: [
              _buildTextField(_courseNameCtrl, 'Course Name'),
              const SizedBox(height: 10),
              _buildTextField(_courseCodeCtrl, 'Course Code'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () {
                    final name = _courseNameCtrl.text.trim();
                    final code = _courseCodeCtrl.text.trim();
                    if (name.isEmpty || code.isEmpty) return;
                    data.addCourse(name, code);
                    _courseNameCtrl.clear();
                    _courseCodeCtrl.clear();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Add Course',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
              if (data.courses.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(height: 1, color: const Color(0xFFEEEEEE)),
                const SizedBox(height: 8),
                ...data.courses.asMap().entries.map((entry) {
                  final i = entry.key;
                  final c = entry.value;
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c['name']!,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87)),
                              const SizedBox(height: 2),
                              Text(c['code']!,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.black45)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => data.removeCourse(i),
                          child: const Text('✕',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.black38)),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              if (data.courses.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('No courses added yet',
                      style: TextStyle(fontSize: 13, color: Colors.black38)),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // ═══════════════════════════════════════
          // SECTION 2: Professor Emails
          // ═══════════════════════════════════════
          _buildSectionCard(
            title: 'Professor Emails',
            subtitle: '${data.professorEmails.length} added',
            note: 'Emails here are treated as professors, not students',
            children: [
              _buildTextField(_profEmailCtrl, 'professor@email.com',
                  inputType: TextInputType.emailAddress),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () {
                    final email = _profEmailCtrl.text.trim();
                    if (email.isEmpty) return;
                    data.addProfessorEmail(email);
                    _profEmailCtrl.clear();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Add Professor Email',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
              if (data.professorEmails.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(height: 1, color: const Color(0xFFEEEEEE)),
                const SizedBox(height: 8),
                ...data.professorEmails.asMap().entries.map((entry) {
                  final i = entry.key;
                  final email = entry.value;
                  return _buildEmailRow(email, () {
                    data.removeProfessorEmail(i);
                  });
                }),
              ],
              if (data.professorEmails.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('No professor emails added yet',
                      style: TextStyle(fontSize: 13, color: Colors.black38)),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // ═══════════════════════════════════════
          // SECTION 3: CR Emails
          // ═══════════════════════════════════════
          _buildSectionCard(
            title: 'CR Emails',
            subtitle: '${data.crEmails.length} added',
            children: [
              _buildTextField(_crEmailCtrl, 'cr@email.com',
                  inputType: TextInputType.emailAddress),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () {
                    final email = _crEmailCtrl.text.trim();
                    if (email.isEmpty) return;
                    data.addCREmail(email);
                    _crEmailCtrl.clear();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Add CR Email',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
              if (data.crEmails.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(height: 1, color: const Color(0xFFEEEEEE)),
                const SizedBox(height: 8),
                ...data.crEmails.asMap().entries.map((entry) {
                  final i = entry.key;
                  final email = entry.value;
                  return _buildEmailRow(email, () {
                    data.removeCREmail(i);
                  });
                }),
              ],
              if (data.crEmails.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('No CR emails added yet',
                      style: TextStyle(fontSize: 13, color: Colors.black38)),
                ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    String? note,
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
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(note,
                style: const TextStyle(fontSize: 12, color: Colors.black38)),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint,
      {TextInputType inputType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: inputType,
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: Colors.black26),
        filled: true,
        fillColor: const Color(0xFFF9F9F9),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black54, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildEmailRow(String email, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(email,
                style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ),
          GestureDetector(
            onTap: onRemove,
            child: const Text('✕',
                style: TextStyle(fontSize: 16, color: Colors.black38)),
          ),
        ],
      ),
    );
  }
}
