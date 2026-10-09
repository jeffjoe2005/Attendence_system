import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/moderator_data_provider.dart';

enum ColumnSort { slNo, code, name, branch, semester, type, professor }

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // Search & Filter state
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _branchFilter = 'All'; // 'All', 'CSE', 'ECE', 'EEE', 'MCE', 'CVE'
  String _filter = 'All'; // 'All', 'Unassigned', 'IV Sem', 'VI Sem', 'VIII Sem', 'M.Tech'

  // Sorting state
  ColumnSort _sortColumn = ColumnSort.branch;
  bool _sortAsc = true;

  // Assignment modal state
  String? _modalCourseCode;
  String? _modalProfEmail;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int _semWeight(String? sem) {
    if (sem == null) return 99;
    final s = sem.toLowerCase();
    if (s.contains('iv') || s.contains('4')) return 1;
    if (s.contains('vi') && !s.contains('viii') || s.contains('6')) return 2;
    if (s.contains('viii') || s.contains('8')) return 3;
    if (s.contains('m.tech') || s.contains('mtech')) return 4;
    if (s.contains('open') || s.contains('oe')) return 5;
    return 6;
  }

  void _onHeaderTapped(ColumnSort col) {
    setState(() {
      if (_sortColumn == col) {
        _sortAsc = !_sortAsc;
      } else {
        _sortColumn = col;
        _sortAsc = true;
      }
    });
  }

  List<Map<String, String>> _getFilteredList(ModeratorDataProvider data) {
    var list = List<Map<String, String>>.from(data.courses);

    // Branch filter
    if (_branchFilter != 'All') {
      list = list.where((c) => (c['branch'] ?? '').toUpperCase() == _branchFilter.toUpperCase()).toList();
    }

    // Secondary filter
    if (_filter == 'Unassigned') {
      list = list.where((c) => data.getProfessorForCourse(c['code'] ?? '') == null).toList();
    } else if (_filter == 'Assigned') {
      list = list.where((c) => data.getProfessorForCourse(c['code'] ?? '') != null).toList();
    } else if (_filter != 'All') {
      list = list.where((c) => (c['semester'] ?? '').toLowerCase() == _filter.toLowerCase()).toList();
    }

    // Apply Search
    if (_searchQuery.isNotEmpty) {
      list = list.where((c) {
        final code = (c['code'] ?? '').toLowerCase();
        final name = (c['name'] ?? '').toLowerCase();
        final branch = (c['branch'] ?? '').toLowerCase();
        final sem = (c['semester'] ?? '').toLowerCase();
        final prof = (data.getProfessorForCourse(c['code'] ?? '') ?? '').toLowerCase();
        return code.contains(_searchQuery) ||
            name.contains(_searchQuery) ||
            branch.contains(_searchQuery) ||
            sem.contains(_searchQuery) ||
            prof.contains(_searchQuery);
      }).toList();
    }

    // Sort
    list.sort((a, b) {
      int cmp = 0;
      switch (_sortColumn) {
        case ColumnSort.slNo:
          cmp = 0;
          break;
        case ColumnSort.code:
          cmp = (a['code'] ?? '').compareTo(b['code'] ?? '');
          break;
        case ColumnSort.name:
          cmp = (a['name'] ?? '').compareTo(b['name'] ?? '');
          break;
        case ColumnSort.branch:
          cmp = (a['branch'] ?? '').compareTo(b['branch'] ?? '');
          if (cmp == 0) {
            cmp = _semWeight(a['semester']).compareTo(_semWeight(b['semester']));
          }
          break;
        case ColumnSort.semester:
          cmp = _semWeight(a['semester']).compareTo(_semWeight(b['semester']));
          if (cmp == 0) {
            cmp = (a['code'] ?? '').compareTo(b['code'] ?? '');
          }
          break;
        case ColumnSort.type:
          cmp = (a['type'] ?? '').compareTo(b['type'] ?? '');
          break;
        case ColumnSort.professor:
          final profA = data.getProfessorForCourse(a['code'] ?? '') ?? 'zzz';
          final profB = data.getProfessorForCourse(b['code'] ?? '') ?? 'zzz';
          cmp = profA.compareTo(profB);
          break;
      }
      return _sortAsc ? cmp : -cmp;
    });

    return list;
  }

  // Open modal bottom sheet to map professor to course
  void _openAssignDialog(BuildContext context, ModeratorDataProvider data, {String? defaultCourse}) {
    _modalCourseCode = defaultCourse ?? (data.unassignedCourses.isNotEmpty ? data.unassignedCourses.first['code'] : data.courses.first['code']);
    _modalProfEmail = data.professorEmails.isNotEmpty ? data.professorEmails.first : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final course = data.courses.firstWhere(
              (c) => c['code'] == _modalCourseCode,
              orElse: () => {'code': '', 'name': ''},
            );

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Map Professor to Course',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Selected Course Display
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            course['code'] ?? '',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            course['name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text('Select Faculty Member:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                  const SizedBox(height: 6),

                  // Professor Picker Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _modalProfEmail,
                        isExpanded: true,
                        hint: const Text('Choose Professor'),
                        items: data.professors.map((p) {
                          final email = p['email'] ?? '';
                          final name = p['name'] ?? email;
                          final dept = p['department'] ?? '';
                          return DropdownMenuItem(
                            value: email,
                            child: Row(
                              children: [
                                const Icon(Icons.person_outline, size: 16, color: Color(0xFF64748B)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$name  ($email)${dept.isNotEmpty ? " • $dept" : ""}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setModalState(() => _modalProfEmail = val);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_modalCourseCode != null && _modalProfEmail != null) {
                          final profName = data.getProfessorNameByEmail(_modalProfEmail!) ?? _modalProfEmail!;
                          data.assignProfessor(_modalCourseCode!, profName);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Mapped $_modalCourseCode to $profName'),
                              backgroundColor: const Color(0xFF0F172A),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Confirm Mapping', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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

  // Color helpers
  Color _getBranchBadgeColor(String branch) {
    switch (branch.toUpperCase()) {
      case 'CSE':
        return const Color(0xFF7C3AED);
      case 'ECE':
        return const Color(0xFF2563EB);
      case 'EEE':
        return const Color(0xFFD97706);
      case 'MCE':
      case 'ME':
        return const Color(0xFF059669);
      case 'CVE':
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
      case 'MCE':
      case 'ME':
        return const Color(0xFFECFDF5);
      case 'CVE':
      case 'CE':
        return const Color(0xFFFFF7ED);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _semBg(String sem) {
    final s = sem.toLowerCase();
    if (s.contains('iv') || s.contains('4')) return const Color(0xFFEFF6FF);
    if (s.contains('vi') && !s.contains('viii') || s.contains('6')) return const Color(0xFFF0FDF4);
    if (s.contains('viii') || s.contains('8')) return const Color(0xFFFAF5FF);
    if (s.contains('m.tech')) return const Color(0xFFFFF7ED);
    return const Color(0xFFF1F5F9);
  }

  Color _semText(String sem) {
    final s = sem.toLowerCase();
    if (s.contains('iv') || s.contains('4')) return const Color(0xFF2563EB);
    if (s.contains('vi') && !s.contains('viii') || s.contains('6')) return const Color(0xFF16A34A);
    if (s.contains('viii') || s.contains('8')) return const Color(0xFF9333EA);
    if (s.contains('m.tech')) return const Color(0xFFEA580C);
    return const Color(0xFF475569);
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<ModeratorDataProvider>();
    final courses = _getFilteredList(data);

    final total = data.courses.length;
    final assigned = data.assignedCourses.length;
    final unassigned = data.unassignedCourses.length;
    final percentMapped = total > 0 ? ((assigned / total) * 100).toStringAsFixed(0) : '0';

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
                const Text(
                  'Admin Portal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Faculty Mapping Mode',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                  ),
                ),
              ],
            ),
            const Text(
              'Map faculty to courses across all 5 branches',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
            child: const Text('Logout', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ══════════════════════════════════════════════════════════════
          // TOP STATS CARDS
          // ══════════════════════════════════════════════════════════════
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                _buildStatPill('Total Courses', '$total', const Color(0xFF0F172A), const Color(0xFFF8FAFC)),
                const SizedBox(width: 8),
                _buildStatPill('Mapped', '$assigned', const Color(0xFF16A34A), const Color(0xFFF0FDF4)),
                const SizedBox(width: 8),
                _buildStatPill('Unassigned', '$unassigned', const Color(0xFFD97706), const Color(0xFFFFFBEB)),
                const SizedBox(width: 8),
                _buildStatPill('Progress', '$percentMapped%', const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // ══════════════════════════════════════════════════════════════
          // BRANCH SELECTION PILLS & SEARCH TOOLBAR
          // ══════════════════════════════════════════════════════════════
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                // Branch Selection Pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildBranchFilterPill('All', 'All Branches ($total)'),
                      _buildBranchFilterPill('CSE', 'CSE (${data.courses.where((c) => c['branch'] == 'CSE').length})'),
                      _buildBranchFilterPill('ECE', 'ECE (${data.courses.where((c) => c['branch'] == 'ECE').length})'),
                      _buildBranchFilterPill('EEE', 'EEE (${data.courses.where((c) => c['branch'] == 'EEE').length})'),
                      _buildBranchFilterPill('MCE', 'MCE (${data.courses.where((c) => c['branch'] == 'MCE').length})'),
                      _buildBranchFilterPill('CVE', 'CVE (${data.courses.where((c) => c['branch'] == 'CVE').length})'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    // Search box
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 36,
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Search code, subject, branch or professor...',
                            hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 14),
                                    onPressed: () => _searchCtrl.clear(),
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFF0F172A)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Filter Dropdown
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _filter,
                          isDense: true,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          items: [
                            DropdownMenuItem(value: 'All', child: Text('All ($total)')),
                            DropdownMenuItem(value: 'Unassigned', child: Text('⚠️ Unassigned ($unassigned)')),
                            DropdownMenuItem(value: 'Assigned', child: Text('✅ Assigned ($assigned)')),
                            const DropdownMenuItem(value: 'IV Sem', child: Text('IV Sem')),
                            const DropdownMenuItem(value: 'VI Sem', child: Text('VI Sem')),
                            const DropdownMenuItem(value: 'VIII Sem', child: Text('VIII Sem')),
                            const DropdownMenuItem(value: 'M.Tech', child: Text('M.Tech')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _filter = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ══════════════════════════════════════════════════════════════
          // SPREADSHEET TABLE
          // ══════════════════════════════════════════════════════════════
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: const [
                  BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: courses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off_rounded, size: 36, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 8),
                            const Text('No courses found', style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _branchFilter = 'All';
                                  _filter = 'All';
                                  _searchCtrl.clear();
                                });
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                              child: const Text('Reset Filters'),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: _buildSpreadsheetTable(context, data, courses),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchFilterPill(String branch, String label) {
    final isSelected = _branchFilter == branch;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) setState(() => _branchFilter = branch);
        },
        selectedColor: const Color(0xFF0F172A),
        backgroundColor: const Color(0xFFF1F5F9),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF334155),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide.none),
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: textColor.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor)),
            const SizedBox(height: 1),
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSpreadsheetTable(BuildContext context, ModeratorDataProvider data, List<Map<String, String>> courses) {
    const double colWidthSl = 40.0;
    const double colWidthCode = 88.0;
    const double colWidthName = 230.0;
    const double colWidthBranch = 75.0;
    const double colWidthSem = 85.0;
    const double colWidthType = 75.0;
    const double colWidthProf = 240.0;
    const double colWidthAction = 85.0;

    const borderColor = Color(0xFFCBD5E1);

    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FixedColumnWidth(colWidthSl),
        1: FixedColumnWidth(colWidthCode),
        2: FixedColumnWidth(colWidthName),
        3: FixedColumnWidth(colWidthBranch),
        4: FixedColumnWidth(colWidthSem),
        5: FixedColumnWidth(colWidthType),
        6: FixedColumnWidth(colWidthProf),
        7: FixedColumnWidth(colWidthAction),
      },
      border: TableBorder.all(color: borderColor, width: 1),
      children: [
        // ── Header Row ──
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFF0F172A)),
          children: [
            _buildHeaderCell('#', ColumnSort.slNo, align: TextAlign.center),
            _buildHeaderCell('Course Code', ColumnSort.code),
            _buildHeaderCell('Course Name', ColumnSort.name),
            _buildHeaderCell('Branch', ColumnSort.branch, align: TextAlign.center),
            _buildHeaderCell('Semester', ColumnSort.semester, align: TextAlign.center),
            _buildHeaderCell('Type', ColumnSort.type, align: TextAlign.center),
            _buildHeaderCell('Course Coordinator / Professor', ColumnSort.professor),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              child: Text(
                'Action',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
              ),
            ),
          ],
        ),

        // ── Data Rows ──
        ...courses.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final c = entry.value;
          final code = c['code'] ?? '';
          final name = c['name'] ?? '';
          final branch = c['branch'] ?? ModeratorDataProvider.deriveBranch(code);
          final sem = c['semester'] ?? 'General';
          final type = c['type'] ?? 'Theory';
          final prof = data.getProfessorForCourse(code);
          final isEvenRow = entry.key % 2 == 0;

          Color rowBg;
          if (prof == null) {
            rowBg = const Color(0xFFFFFBEB); // Warm amber highlight for unassigned
          } else if (isEvenRow) {
            rowBg = Colors.white;
          } else {
            rowBg = const Color(0xFFF8FAFC);
          }

          return TableRow(
            decoration: BoxDecoration(color: rowBg),
            children: [
              // 0: Sl No
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                child: Text('$idx', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
              ),

              // 1: Code
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Text(code, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              ),

              // 2: Name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),

              // 3: Branch Badge
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getBranchBgColor(branch),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _getBranchBadgeColor(branch).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      branch,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _getBranchBadgeColor(branch)),
                    ),
                  ),
                ),
              ),

              // 4: Semester
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _semBg(sem),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _semText(sem).withValues(alpha: 0.2)),
                    ),
                    child: Text(sem, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _semText(sem))),
                  ),
                ),
              ),

              // 5: Type
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  child: Text(type, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                ),
              ),

              // 6: Professor
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: prof != null
                    ? Text(prof, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis)
                    : const Text('⚠️ Not Assigned', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
              ),

              // 7: Action (Assign / Change)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: prof != null
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => _openAssignDialog(context, data, defaultCourse: code),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                                child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF334155)),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () {
                                data.removeAssignment(code);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Unlinked professor from $code'), duration: const Duration(seconds: 1)),
                                );
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(4)),
                                child: const Icon(Icons.link_off_rounded, size: 14, color: Color(0xFFDC2626)),
                              ),
                            ),
                          ],
                        )
                      : SizedBox(
                          height: 28,
                          child: ElevatedButton(
                            onPressed: () => _openAssignDialog(context, data, defaultCourse: code),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            child: const Text('Assign', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildHeaderCell(String label, ColumnSort col, {TextAlign align = TextAlign.left}) {
    final isSelected = _sortColumn == col;
    final sortIcon = isSelected ? (_sortAsc ? ' ▲' : ' ▼') : '';

    return InkWell(
      onTap: () => _onHeaderTapped(col),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Text(
          '$label$sortIcon',
          textAlign: align,
          style: TextStyle(
            color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
