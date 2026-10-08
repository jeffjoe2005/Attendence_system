import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/moderator_data_provider.dart';

enum ModColumnSort { slNo, code, name, branch, semester, type, professor }

class ModeratorDashboard extends StatefulWidget {
  const ModeratorDashboard({super.key});

  @override
  State<ModeratorDashboard> createState() => _ModeratorDashboardState();
}

class _ModeratorDashboardState extends State<ModeratorDashboard> {
  // Top Form Controllers
  final TextEditingController _profEmailCtrl = TextEditingController();
  final TextEditingController _crEmailCtrl = TextEditingController();
  final TextEditingController _courseNameCtrl = TextEditingController();
  final TextEditingController _courseCodeCtrl = TextEditingController();

  String _selectedBranch = 'ECE';
  String _selectedSemester = 'IV Sem';
  String _crBranch = 'ECE';
  String _crSemester = 'IV Sem';
  String _importBranchTarget = 'Auto-detect';

  // Live extracted name previews
  String _extractedProfName = '';
  String _extractedCrName = '';

  // Spreadsheet Search, Filter, Sort
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _branchFilter = 'All'; // 'All', 'CSE', 'ECE', 'EEE', 'ME', 'CE'
  String _semFilter = 'All'; // 'All', 'IV Sem', 'VI Sem', 'VIII Sem', 'M.Tech'
  String _statusFilter = 'All'; // 'All', 'Assigned', 'Unassigned'
  ModColumnSort _sortColumn = ModColumnSort.branch;
  bool _sortAsc = true;

  // Active top tab: 0: Add Professor, 1: Import CSV/Excel, 2: Add CR, 3: Add Course
  int _activeTopAction = 0;

  @override
  void initState() {
    super.initState();
    _profEmailCtrl.addListener(() {
      final email = _profEmailCtrl.text.trim();
      setState(() {
        _extractedProfName = email.isNotEmpty ? ModeratorDataProvider.extractNameFromEmail(email) : '';
      });
    });

    _crEmailCtrl.addListener(() {
      final email = _crEmailCtrl.text.trim();
      setState(() {
        _extractedCrName = email.isNotEmpty ? ModeratorDataProvider.extractNameFromEmail(email) : '';
      });
    });

    _courseCodeCtrl.addListener(() {
      final code = _courseCodeCtrl.text.trim();
      if (code.isNotEmpty) {
        final derived = ModeratorDataProvider.deriveBranch(code);
        if (derived != 'General' && derived != _selectedBranch) {
          setState(() {
            _selectedBranch = derived;
          });
        }
      }
    });

    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _profEmailCtrl.dispose();
    _crEmailCtrl.dispose();
    _courseNameCtrl.dispose();
    _courseCodeCtrl.dispose();
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

  void _onHeaderTapped(ModColumnSort col) {
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

    // Branch Filter
    if (_branchFilter != 'All') {
      list = list.where((c) => (c['branch'] ?? '').toUpperCase() == _branchFilter.toUpperCase()).toList();
    }

    // Semester Filter
    if (_semFilter != 'All') {
      list = list.where((c) => (c['semester'] ?? '').toLowerCase() == _semFilter.toLowerCase()).toList();
    }

    // Status Filter (Assigned / Unassigned)
    if (_statusFilter == 'Unassigned') {
      list = list.where((c) => data.getProfessorForCourse(c['code'] ?? '') == null).toList();
    } else if (_statusFilter == 'Assigned') {
      list = list.where((c) => data.getProfessorForCourse(c['code'] ?? '') != null).toList();
    }

    // Search Query
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

    // Sorting
    list.sort((a, b) {
      int cmp = 0;
      switch (_sortColumn) {
        case ModColumnSort.slNo:
          cmp = 0;
          break;
        case ModColumnSort.code:
          cmp = (a['code'] ?? '').compareTo(b['code'] ?? '');
          break;
        case ModColumnSort.name:
          cmp = (a['name'] ?? '').compareTo(b['name'] ?? '');
          break;
        case ModColumnSort.branch:
          cmp = (a['branch'] ?? '').compareTo(b['branch'] ?? '');
          if (cmp == 0) {
            cmp = _semWeight(a['semester']).compareTo(_semWeight(b['semester']));
          }
          break;
        case ModColumnSort.semester:
          cmp = _semWeight(a['semester']).compareTo(_semWeight(b['semester']));
          if (cmp == 0) {
            cmp = (a['code'] ?? '').compareTo(b['code'] ?? '');
          }
          break;
        case ModColumnSort.type:
          cmp = (a['type'] ?? '').compareTo(b['type'] ?? '');
          break;
        case ModColumnSort.professor:
          final profA = data.getProfessorForCourse(a['code'] ?? '') ?? 'zzz';
          final profB = data.getProfessorForCourse(b['code'] ?? '') ?? 'zzz';
          cmp = profA.compareTo(profB);
          break;
      }
      return _sortAsc ? cmp : -cmp;
    });

    return list;
  }

  // ── File Picker: Pick and import .xlsx / .csv from computer ──
  Future<void> _pickAndImportFile(BuildContext context, ModeratorDataProvider data) async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv', 'tsv', 'txt'],
      );

      if (file == null) return;
      final ext = file.extension?.toLowerCase() ?? '';
      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file data or file is empty.')),
          );
        }
        return;
      }

      final branchArg = _importBranchTarget == 'Auto-detect' ? null : _importBranchTarget;
      Map<String, int> res;
      if (ext == 'xlsx' || ext == 'xls') {
        res = data.importExcelBytes(bytes, defaultBranch: branchArg);
      } else {
        final content = String.fromCharCodes(bytes);
        res = data.importCsvData(content, defaultBranch: branchArg);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully imported ${res['courses']} courses & ${res['professors']} professors from "${file.name}"!',
            ),
            backgroundColor: const Color(0xFF0F172A),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing file: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  // ── Dialog: Raw Text Paste Import ──
  void _openPasteTextDialog(BuildContext context, ModeratorDataProvider data) {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Paste CSV / TSV Data', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: textCtrl,
              maxLines: 8,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'Sl No,Course Code,Course Name,Branch,Semester,Course Coordinator\n1,EC250,Numerical Methods,ECE,IV Sem,Dr. Najiya V K\n2,CS250,Data Structures,CSE,IV Sem,Dr. Pravati Swain',
                hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final content = textCtrl.text.trim();
                if (content.isNotEmpty) {
                  final branchArg = _importBranchTarget == 'Auto-detect' ? null : _importBranchTarget;
                  final res = data.importCsvData(content, defaultBranch: branchArg);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Imported ${res['courses']} courses & ${res['professors']} professors!'),
                      backgroundColor: const Color(0xFF0F172A),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Analyze & Import'),
            ),
          ],
        );
      },
    );
  }

  // ── Dialog: Edit Course ──
  void _openEditCourseDialog(BuildContext context, ModeratorDataProvider data, Map<String, String> c) {
    final codeCtrl = TextEditingController(text: c['code']);
    final nameCtrl = TextEditingController(text: c['name']);
    String editBranch = c['branch'] ?? 'ECE';
    String editSem = c['semester'] ?? 'IV Sem';
    String editType = c['type'] ?? 'Theory';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Text('Edit Course ${c['code']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(labelText: 'Course Code', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Course Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: editBranch,
                      decoration: const InputDecoration(labelText: 'Branch', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'CSE', child: Text('CSE - Computer Science')),
                        DropdownMenuItem(value: 'ECE', child: Text('ECE - Electronics & Comm')),
                        DropdownMenuItem(value: 'EEE', child: Text('EEE - Electrical & Electronics')),
                        DropdownMenuItem(value: 'ME', child: Text('ME - Mechanical Engg')),
                        DropdownMenuItem(value: 'CE', child: Text('CE - Civil Engg')),
                        DropdownMenuItem(value: 'General', child: Text('General / Interdisciplinary')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => editBranch = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: editSem,
                      decoration: const InputDecoration(labelText: 'Semester', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'IV Sem', child: Text('IV Sem')),
                        DropdownMenuItem(value: 'VI Sem', child: Text('VI Sem')),
                        DropdownMenuItem(value: 'VIII Sem', child: Text('VIII Sem')),
                        DropdownMenuItem(value: 'M.Tech', child: Text('M.Tech')),
                        DropdownMenuItem(value: 'Open Elective', child: Text('Open Elective')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => editSem = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: editType,
                      decoration: const InputDecoration(labelText: 'Course Type', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'Theory', child: Text('Theory')),
                        DropdownMenuItem(value: 'Practical', child: Text('Practical / Lab')),
                        DropdownMenuItem(value: 'Elective', child: Text('Elective')),
                        DropdownMenuItem(value: 'Open Elective', child: Text('Open Elective')),
                        DropdownMenuItem(value: 'MLC', child: Text('MLC')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => editType = v);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newCode = codeCtrl.text.trim().toUpperCase();
                    final newName = nameCtrl.text.trim();
                    if (newCode.isNotEmpty && newName.isNotEmpty) {
                      data.updateCourse(
                        c['code'] ?? '',
                        newCode: newCode,
                        newName: newName,
                        newBranch: editBranch,
                        newSemester: editSem,
                        newType: editType,
                      );
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Updated course $newCode!')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Color helper for Branch Badges ──
  Color _getBranchBadgeColor(String branch) {
    switch (branch.toUpperCase()) {
      case 'CSE':
        return const Color(0xFF7C3AED); // Indigo / Violet
      case 'ECE':
        return const Color(0xFF2563EB); // Blue
      case 'EEE':
        return const Color(0xFFD97706); // Amber
      case 'ME':
        return const Color(0xFF059669); // Emerald / Green
      case 'CE':
        return const Color(0xFFEA580C); // Orange / Rust
      default:
        return const Color(0xFF475569); // Slate
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

  @override
  Widget build(BuildContext context) {
    final data = context.watch<ModeratorDataProvider>();
    final courses = _getFilteredList(data);

    final total = data.courses.length;
    final totalProfs = data.professors.length;
    final totalCrs = data.crs.length;
    final assignedCount = data.assignedCourses.length;

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
                  'Moderator Super Admin',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Full Edit Access',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                  ),
                ),
              ],
            ),
            const Text(
              'Manage 5 Branches (CSE, ECE, EEE, ME, CE), Courses, Faculty & CRs',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE2E8F0)),
        ),
        actions: [
          IconButton(
            tooltip: 'Reset Semester',
            icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF64748B)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Reset Everything?'),
                  content: const Text('This will clear all current courses, faculty, and CRs.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () {
                        data.resetSemester();
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Reset', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Reload All 5 Branches Sample Data',
            icon: const Icon(Icons.flash_on_rounded, size: 20, color: Color(0xFF2563EB)),
            onPressed: () {
              data.seedDefaultData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Seeded realistic data for CSE, ECE, EEE, ME & CE!')),
              );
            },
          ),
          TextButton(
            onPressed: () => context.read<AuthProvider>().signOut(),
            child: const Text('Logout', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ══════════════════════════════════════════════════════════════
          // TOP BAR: Quick Stats & Mode Switcher
          // ══════════════════════════════════════════════════════════════
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              children: [
                // Top Segmented Action Bar
                Row(
                  children: [
                    _buildTopOptionTab(0, '1. Add Professor ($totalProfs)', Icons.person_add_alt_1_rounded),
                    const SizedBox(width: 6),
                    _buildTopOptionTab(1, '2. Import Excel / CSV', Icons.table_view_rounded),
                    const SizedBox(width: 6),
                    _buildTopOptionTab(2, '3. Add CR ($totalCrs)', Icons.badge_outlined),
                    const SizedBox(width: 6),
                    _buildTopOptionTab(3, '+ Add Course', Icons.add_circle_outline),
                  ],
                ),
                const SizedBox(height: 10),

                // Form based on selected top tab
                if (_activeTopAction == 0) _buildAddProfessorCard(data),
                if (_activeTopAction == 1) _buildCsvImportCard(data),
                if (_activeTopAction == 2) _buildAddCrCard(data),
                if (_activeTopAction == 3) _buildAddCourseCard(data),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // ══════════════════════════════════════════════════════════════
          // SPREADSHEET TOOLBAR: Branch Tabs, Search, Sem & Status Filters
          // ══════════════════════════════════════════════════════════════
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                // Branch Selection Pills (5 Branches + All)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildBranchFilterPill('All', 'All Branches ($total)'),
                      _buildBranchFilterPill('CSE', 'CSE (${data.courses.where((c) => c['branch'] == 'CSE').length})'),
                      _buildBranchFilterPill('ECE', 'ECE (${data.courses.where((c) => c['branch'] == 'ECE').length})'),
                      _buildBranchFilterPill('EEE', 'EEE (${data.courses.where((c) => c['branch'] == 'EEE').length})'),
                      _buildBranchFilterPill('ME', 'ME (${data.courses.where((c) => c['branch'] == 'ME').length})'),
                      _buildBranchFilterPill('CE', 'CE (${data.courses.where((c) => c['branch'] == 'CE').length})'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Search & Secondary Filters
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
                            hintText: 'Search course code, name, branch or professor...',
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
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF0F172A))),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Semester Filter
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
                          value: _semFilter,
                          isDense: true,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All Semesters')),
                            DropdownMenuItem(value: 'IV Sem', child: Text('IV Sem')),
                            DropdownMenuItem(value: 'VI Sem', child: Text('VI Sem')),
                            DropdownMenuItem(value: 'VIII Sem', child: Text('VIII Sem')),
                            DropdownMenuItem(value: 'M.Tech', child: Text('M.Tech')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _semFilter = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Assignment Status Filter
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
                          value: _statusFilter,
                          isDense: true,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          items: [
                            const DropdownMenuItem(value: 'All', child: Text('All Status')),
                            DropdownMenuItem(value: 'Assigned', child: Text('Assigned ($assignedCount)')),
                            DropdownMenuItem(value: 'Unassigned', child: Text('Unassigned (${total - assignedCount})')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _statusFilter = val);
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
          // SPREADSHEET TABLE (2D Horizontal + Vertical Scroll)
          // Editable and deletable by Moderator!
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
                            const Icon(Icons.filter_alt_off_rounded, size: 36, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 8),
                            const Text('No courses found matching filter', style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _branchFilter = 'All';
                                  _semFilter = 'All';
                                  _statusFilter = 'All';
                                  _searchCtrl.clear();
                                });
                              },
                              icon: const Icon(Icons.clear_all_rounded, size: 16),
                              label: const Text('Clear Filters'),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: _buildModeratorTable(context, data, courses),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Top Option Selector Tab ──
  Widget _buildTopOptionTab(int index, String label, IconData icon) {
    final isSelected = _activeTopAction == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTopAction = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? Colors.white : const Color(0xFF475569)),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Branch Filter Pill ──
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

  // ── Top Card 1: Add Professor with Auto Name Extraction ──
  Widget _buildAddProfessorCard(ModeratorDataProvider data) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _profEmailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Professor Email',
                    hintText: 'e.g. ishaan.bhate@nitgoa.ac.in',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedBranch,
                    isDense: true,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    items: const [
                      DropdownMenuItem(value: 'ECE', child: Text('ECE Dept')),
                      DropdownMenuItem(value: 'CSE', child: Text('CSE Dept')),
                      DropdownMenuItem(value: 'EEE', child: Text('EEE Dept')),
                      DropdownMenuItem(value: 'ME', child: Text('ME Dept')),
                      DropdownMenuItem(value: 'CE', child: Text('CE Dept')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedBranch = v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  final email = _profEmailCtrl.text.trim();
                  if (email.isNotEmpty) {
                    data.addProfessor(email, department: _selectedBranch);
                    final name = ModeratorDataProvider.extractNameFromEmail(email);
                    _profEmailCtrl.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added Professor: $name ($email) in $_selectedBranch')),
                    );
                  }
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Prof'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          if (_extractedProfName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF2563EB)),
                const SizedBox(width: 4),
                Text(
                  'Extracted Name: $_extractedProfName',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 8),
                const Text(
                  '(Direct portal access on login)',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Top Card 2: Import CSV / Excel DIRECT ACTION ──
  Widget _buildCsvImportCard(ModeratorDataProvider data) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Target Branch
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _importBranchTarget,
                    isDense: true,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    items: const [
                      DropdownMenuItem(value: 'Auto-detect', child: Text('Branch: Auto-detect')),
                      DropdownMenuItem(value: 'CSE', child: Text('Branch: CSE')),
                      DropdownMenuItem(value: 'ECE', child: Text('Branch: ECE')),
                      DropdownMenuItem(value: 'EEE', child: Text('Branch: EEE')),
                      DropdownMenuItem(value: 'ME', child: Text('Branch: ME')),
                      DropdownMenuItem(value: 'CE', child: Text('Branch: CE')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _importBranchTarget = v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // PRIMARY BUTTON: Pick from Computer's File Manager
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () => _pickAndImportFile(context, data),
                    icon: const Icon(Icons.file_open_rounded, size: 18),
                    label: const Text(
                      'Browse & Import Excel/CSV from Computer (.xlsx, .csv)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Paste text fallback button
              OutlinedButton.icon(
                onPressed: () => _openPasteTextDialog(context, data),
                icon: const Icon(Icons.content_paste_rounded, size: 14),
                label: const Text('Paste Text', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '💡 File importer automatically analyzes columns for Course Code, Name, Branch, Semester, and Professor/Faculty.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  // ── Top Card 3: Add CR ──
  Widget _buildAddCrCard(ModeratorDataProvider data) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _crEmailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'CR Email',
                    hintText: 'e.g. rahul.patil@nitgoa.ac.in',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // CR Branch
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _crBranch,
                    isDense: true,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    items: const [
                      DropdownMenuItem(value: 'ECE', child: Text('ECE')),
                      DropdownMenuItem(value: 'CSE', child: Text('CSE')),
                      DropdownMenuItem(value: 'EEE', child: Text('EEE')),
                      DropdownMenuItem(value: 'ME', child: Text('ME')),
                      DropdownMenuItem(value: 'CE', child: Text('CE')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _crBranch = v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // CR Semester
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _crSemester,
                    isDense: true,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    items: const [
                      DropdownMenuItem(value: 'IV Sem', child: Text('IV Sem')),
                      DropdownMenuItem(value: 'VI Sem', child: Text('VI Sem')),
                      DropdownMenuItem(value: 'VIII Sem', child: Text('VIII Sem')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _crSemester = v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),

              ElevatedButton.icon(
                onPressed: () {
                  final email = _crEmailCtrl.text.trim();
                  if (email.isNotEmpty) {
                    data.addCR(email, branch: _crBranch, semester: _crSemester);
                    final name = ModeratorDataProvider.extractNameFromEmail(email);
                    _crEmailCtrl.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added CR: $name ($email) for $_crBranch $_crSemester')),
                    );
                  }
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add CR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          if (_extractedCrName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.badge, size: 14, color: Color(0xFFD97706)),
                const SizedBox(width: 4),
                Text(
                  'Extracted CR Name: $_extractedCrName',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Top Card 4: Add Course Manually ──
  Widget _buildAddCourseCard(ModeratorDataProvider data) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 85,
            child: TextField(
              controller: _courseCodeCtrl,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(labelText: 'Code', hintText: 'CS250', isDense: true, border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _courseNameCtrl,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(labelText: 'Course Name', hintText: 'Data Structures', isDense: true, border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 8),

          // Branch selector
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedBranch,
                isDense: true,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                items: const [
                  DropdownMenuItem(value: 'CSE', child: Text('CSE')),
                  DropdownMenuItem(value: 'ECE', child: Text('ECE')),
                  DropdownMenuItem(value: 'EEE', child: Text('EEE')),
                  DropdownMenuItem(value: 'ME', child: Text('ME')),
                  DropdownMenuItem(value: 'CE', child: Text('CE')),
                  DropdownMenuItem(value: 'General', child: Text('General')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedBranch = v);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Semester selector
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSemester,
                isDense: true,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                items: const [
                  DropdownMenuItem(value: 'IV Sem', child: Text('IV Sem')),
                  DropdownMenuItem(value: 'VI Sem', child: Text('VI Sem')),
                  DropdownMenuItem(value: 'VIII Sem', child: Text('VIII Sem')),
                  DropdownMenuItem(value: 'M.Tech', child: Text('M.Tech')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedSemester = v);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),

          ElevatedButton(
            onPressed: () {
              final code = _courseCodeCtrl.text.trim();
              final name = _courseNameCtrl.text.trim();
              if (code.isNotEmpty && name.isNotEmpty) {
                data.addCourse(name, code, branch: _selectedBranch, semester: _selectedSemester);
                _courseCodeCtrl.clear();
                _courseNameCtrl.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added course $code ($name) for $_selectedBranch!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
            ),
            child: const Text('Add Course'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // MODERATOR SPREADSHEET TABLE
  // Shows full 2D grid with Edit and Delete options for Moderator
  // ══════════════════════════════════════════════════════════════
  Widget _buildModeratorTable(BuildContext context, ModeratorDataProvider data, List<Map<String, String>> courses) {
    const double colWidthSl = 40.0;
    const double colWidthCode = 88.0;
    const double colWidthName = 230.0;
    const double colWidthBranch = 75.0;
    const double colWidthSem = 85.0;
    const double colWidthType = 75.0;
    const double colWidthProf = 240.0;
    const double colWidthAction = 90.0; // Space for Edit + Delete

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
            _buildHeaderCell('#', ModColumnSort.slNo, align: TextAlign.center),
            _buildHeaderCell('Course Code', ModColumnSort.code),
            _buildHeaderCell('Course Name', ModColumnSort.name),
            _buildHeaderCell('Branch', ModColumnSort.branch, align: TextAlign.center),
            _buildHeaderCell('Semester', ModColumnSort.semester, align: TextAlign.center),
            _buildHeaderCell('Type', ModColumnSort.type, align: TextAlign.center),
            _buildHeaderCell('Assigned Professor', ModColumnSort.professor),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              child: Text(
                'Actions',
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
          final isEven = entry.key % 2 == 0;

          return TableRow(
            decoration: BoxDecoration(color: isEven ? Colors.white : const Color(0xFFF8FAFC)),
            children: [
              // 0: Sl No
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                child: Text('$idx', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
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

              // 3: Branch (Color Coded Badge)
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
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(sem, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                  ),
                ),
              ),

              // 5: Type
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  child: Text(type, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                ),
              ),

              // 6: Professor
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: prof != null
                    ? Text(prof, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis)
                    : const Text('⚠️ Not Assigned', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
              ),

              // 7: Moderator Actions (Edit + Delete)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit button
                      InkWell(
                        onTap: () => _openEditCourseDialog(context, data, c),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF334155)),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Delete button
                      InkWell(
                        onTap: () {
                          data.removeCourse(code);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Deleted course $code')),
                          );
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildHeaderCell(String label, ModColumnSort col, {TextAlign align = TextAlign.left}) {
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
