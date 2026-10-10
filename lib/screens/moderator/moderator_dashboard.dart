import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/moderator_data_provider.dart';

enum ModColumnSort { slNo, code, name, branch, semester, type, professor }

/// Moderator Portal — College-wide curriculum & faculty allocation control.
/// UI redesign matching clean Inter minimalist aesthetics:
/// - Charcoal & slate ink palette (#0F172A, #64748B, #E2E8F0, #F8FAFC, #F1F5F9)
/// - Top action tools (Add Faculty, Import Excel/CSV, Add CR, + Course, Storage & Backup)
/// - Centered branch filter tabs with course counters
/// - Two-column filter card (Search, Semester, Status)
/// - Bulk action banner on row selection (Bulk Assign, Delete, Clear)
/// - Clean spreadsheet table with inline professor picker, load counters, and course type badges
/// - Density toggle (Compact / Comfortable), Zoom controls (85% - 130%), and Fullscreen Zoom Mode
/// - Add/Edit Course modal dialog and toast notifications with Undo
class ModeratorDashboard extends StatefulWidget {
  const ModeratorDashboard({super.key});

  @override
  State<ModeratorDashboard> createState() => _ModeratorDashboardState();
}

class _ModeratorDashboardState extends State<ModeratorDashboard> {
  // Palette constants
  static const Color ink = Color(0xFF0F172A);
  static const Color mut = Color(0xFF64748B);
  static const Color line = Color(0xFFE2E8F0);
  static const Color soft = Color(0xFFF8FAFC);
  static const Color pageBg = Color(0xFFF1F5F9);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueBg = Color(0xFFEFF6FF);
  static const Color amber = Color(0xFFB45309);
  static const Color amberBg = Color(0xFFFFFBEB);
  static const Color red = Color(0xFFDC2626);
  static const Color redBg = Color(0xFFFEF2F2);

  // Top Form Controllers
  final TextEditingController _profEmailCtrl = TextEditingController();
  final TextEditingController _crEmailCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  String _selectedProfDept = 'ECE';
  String _crBranch = 'ECE';
  String _crSemester = 'VI Sem';
  String _importBranchTarget = 'Auto-detect';

  // Live extracted name previews
  String _extractedProfName = '';
  String _extractedCrName = '';

  // Spreadsheet Search, Filter, Sort
  String _searchQuery = '';
  String _branchFilter = 'All'; // 'All', 'CSE', 'ECE', 'EEE', 'MCE', 'CVE'
  String _semFilter = 'All'; // 'All', 'IV Sem', 'VI Sem', 'VIII Sem', 'M.Tech'
  String _statusFilter = 'All'; // 'All', 'Assigned', 'Unassigned'
  ModColumnSort _sortColumn = ModColumnSort.code;
  bool _sortAsc = true;

  // Active top tool: 0: Add Faculty, 1: Import CSV/Excel, 2: Add CR, 4: Storage & Backup
  int _activeTopAction = 0;

  // Table Density & Zoom
  bool _isCompact = false;
  double _tableScale = 1.0;

  // Selected row codes for bulk actions
  final Set<String> _selectedCodes = {};

  @override
  void initState() {
    super.initState();
    _profEmailCtrl.addListener(() {
      if (!mounted) return;
      final email = _profEmailCtrl.text.trim();
      setState(() {
        _extractedProfName = email.isNotEmpty ? ModeratorDataProvider.extractNameFromEmail(email) : '';
      });
    });

    _crEmailCtrl.addListener(() {
      if (!mounted) return;
      final email = _crEmailCtrl.text.trim();
      setState(() {
        _extractedCrName = email.isNotEmpty ? ModeratorDataProvider.extractNameFromEmail(email) : '';
      });
    });

    _searchCtrl.addListener(() {
      if (!mounted) return;
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _profEmailCtrl.dispose();
    _crEmailCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  int _semWeight(String? sem) {
    if (sem == null) return 99;
    final s = sem.toLowerCase();
    if (s.contains('i') && !s.contains('iv') && !s.contains('vi')) return 1;
    if (s.contains('ii') && !s.contains('vii')) return 2;
    if (s.contains('iii') && !s.contains('viii')) return 3;
    if (s.contains('iv') || s.contains('4')) return 4;
    if (s.contains('v') && !s.contains('iv') && !s.contains('vi')) return 5;
    if (s.contains('vi') && !s.contains('vii') && !s.contains('viii') || s.contains('6')) return 6;
    if (s.contains('vii') && !s.contains('viii') || s.contains('7')) return 7;
    if (s.contains('viii') || s.contains('8')) return 8;
    if (s.contains('m.tech') || s.contains('mtech')) return 9;
    return 10;
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

    // Status Filter (Assigned / Needs professor)
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

  String _getProfInitials(String name) {
    final clean = name.trim().replaceAll(RegExp(r'^Dr\.?\s*', caseSensitive: false), '');
    final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Map<String, int> _calcProfLoad(ModeratorDataProvider data) {
    final map = <String, int>{};
    for (final c in data.courses) {
      final prof = data.getProfessorForCourse(c['code'] ?? '');
      if (prof != null && prof.isNotEmpty) {
        map[prof] = (map[prof] ?? 0) + 1;
      }
    }
    return map;
  }

  void _showToast(String message, {VoidCallback? onUndo}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
        duration: Duration(milliseconds: onUndo != null ? 4500 : 2000),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            if (onUndo != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  onUndo();
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Undo', style: TextStyle(color: Color(0xFF93C5FD), fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _deleteCourse(Map<String, String> course, ModeratorDataProvider data) {
    final code = course['code'] ?? '';
    final prof = data.getProfessorForCourse(code);
    data.removeCourse(code);
    _selectedCodes.remove(code);
    setState(() {});
    _showToast('$code deleted', onUndo: () {
      data.addCourse(
        course['name'] ?? '',
        code,
        branch: course['branch'],
        semester: course['semester'],
        type: course['type'] ?? 'Theory',
      );
      if (prof != null) {
        data.assignProfessor(code, prof);
      }
      setState(() {});
    });
  }

  void _bulkDelete(ModeratorDataProvider data) {
    final toDelete = data.courses.where((c) => _selectedCodes.contains(c['code'])).toList();
    final savedMappings = <String, String>{};
    for (final c in toDelete) {
      final code = c['code'] ?? '';
      final prof = data.getProfessorForCourse(code);
      if (prof != null) savedMappings[code] = prof;
      data.removeCourse(code);
    }
    final count = toDelete.length;
    _selectedCodes.clear();
    setState(() {});
    _showToast('$count courses deleted', onUndo: () {
      for (final c in toDelete) {
        final code = c['code'] ?? '';
        data.addCourse(
          c['name'] ?? '',
          code,
          branch: c['branch'],
          semester: c['semester'],
          type: c['type'] ?? 'Theory',
        );
        if (savedMappings.containsKey(code)) {
          data.assignProfessor(code, savedMappings[code]!);
        }
      }
      setState(() {});
    });
  }

  void _bulkAssign(String professor, ModeratorDataProvider data) {
    if (professor.isEmpty) return;
    final count = _selectedCodes.length;
    for (final code in _selectedCodes) {
      data.assignProfessor(code, professor);
    }
    _selectedCodes.clear();
    setState(() {});
    _showToast('$count courses → $professor');
  }

  void _copyCsv(List<Map<String, String>> visibleCourses, ModeratorDataProvider data) {
    final buffer = StringBuffer();
    buffer.writeln('"Code","Course","Branch","Sem","Type","Professor"');
    for (final c in visibleCourses) {
      final code = c['code'] ?? '';
      final name = c['name'] ?? '';
      final branch = c['branch'] ?? '';
      final sem = c['semester'] ?? '';
      final type = c['type'] ?? '';
      final prof = data.getProfessorForCourse(code) ?? '';
      buffer.writeln('"$code","$name","$branch","$sem","$type","$prof"');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    _showToast('CSV copied');
  }

  // ── File Picker: Import spreadsheet file ──
  Future<void> _pickAndImportFile(BuildContext context, ModeratorDataProvider data) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final name = file.name.toLowerCase();
      String ext = (file.extension ?? '').toLowerCase();
      if (ext.isEmpty && name.contains('.')) {
        ext = name.split('.').last;
      }

      final isExcelOrCsv = ext == 'xlsx' || ext == 'xls' || ext == 'csv' || ext == 'tsv' || ext == 'txt';
      if (!isExcelOrCsv) {
        _showToast('Please select a spreadsheet file (.xlsx, .csv)');
        return;
      }

      List<int>? rawBytes = file.bytes;
      if (rawBytes == null && file.path != null) {
        rawBytes = await File(file.path!).readAsBytes();
      }

      if (rawBytes == null || rawBytes.isEmpty) {
        _showToast('Could not read file data or file is empty.');
        return;
      }

      final branchArg = _importBranchTarget == 'Auto-detect' ? null : _importBranchTarget;
      Map<String, int> res;
      if (ext == 'xlsx' || ext == 'xls') {
        res = data.importExcelBytes(rawBytes, defaultBranch: branchArg, fileName: file.name);
      } else {
        final content = utf8.decode(rawBytes, allowMalformed: true);
        res = data.importCsvData(content, defaultBranch: branchArg);
      }

      _showToast('Imported ${res['courses']} courses & ${res['professors']} professors!');
    } catch (e) {
      _showToast('Error importing file: $e');
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: line)),
          title: const Text('Paste CSV / TSV Data', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: ink)),
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
                fillColor: soft,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: line)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: ink),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final content = textCtrl.text.trim();
                if (content.isNotEmpty) {
                  final branchArg = _importBranchTarget == 'Auto-detect' ? null : _importBranchTarget;
                  final res = data.importCsvData(content, defaultBranch: branchArg);
                  Navigator.pop(ctx);
                  _showToast('Imported ${res['courses']} courses & ${res['professors']} professors!');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              ),
              child: const Text('Analyze & Import'),
            ),
          ],
        );
      },
    );
  }

  // ── Add / Edit Course Modal Dialog ──
  void _openCourseDialog(BuildContext context, ModeratorDataProvider data, {Map<String, String>? course}) {
    final isEditing = course != null;
    final codeCtrl = TextEditingController(text: course?['code'] ?? '');
    final nameCtrl = TextEditingController(text: course?['name'] ?? '');
    String branch = course?['branch'] ?? (_branchFilter != 'All' ? _branchFilter : 'ECE');
    String sem = course?['semester'] ?? (_semFilter != 'All' ? _semFilter : 'VI Sem');
    String type = course?['type'] ?? 'Theory';
    String prof = (course != null ? data.getProfessorForCourse(course['code'] ?? '') : null) ?? '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: line),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                width: 440,
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Edit course' : 'Add course',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ink),
                      ),
                      const SizedBox(height: 14),
                      // Row 1: Course Code & Type
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Course code', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: mut)),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: codeCtrl,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: line)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: line)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: ink)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Type', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: mut)),
                                const SizedBox(height: 4),
                                Container(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(color: line),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: type,
                                      isExpanded: true,
                                      items: ['Theory', 'Lab', 'MLC', 'Elective']
                                          .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13))))
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) setDlgState(() => type = val);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Row 2: Course Name
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Course name', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: mut)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: nameCtrl,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: line)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: line)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: ink)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Row 3: Branch & Semester
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Branch', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: mut)),
                                const SizedBox(height: 4),
                                Container(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(color: line),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: branch,
                                      isExpanded: true,
                                      items: ModeratorDataProvider.supportedBranches
                                          .map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 13))))
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) setDlgState(() => branch = val);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Semester', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: mut)),
                                const SizedBox(height: 4),
                                Container(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(color: line),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: ['I Sem', 'II Sem', 'III Sem', 'IV Sem', 'V Sem', 'VI Sem', 'VII Sem', 'VIII Sem', 'M.Tech'].contains(sem) ? sem : 'VI Sem',
                                      isExpanded: true,
                                      items: ['I Sem', 'II Sem', 'III Sem', 'IV Sem', 'V Sem', 'VI Sem', 'VII Sem', 'VIII Sem', 'M.Tech']
                                          .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) setDlgState(() => sem = val);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Row 4: Assigned Professor
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Assigned professor', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: mut)),
                          const SizedBox(height: 4),
                          Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: line),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: prof.isEmpty ? '' : prof,
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem(value: '', child: Text('Unassigned', style: TextStyle(fontSize: 13, color: mut))),
                                  ...data.professors.map((p) => DropdownMenuItem(value: p['name'] ?? '', child: Text(p['name'] ?? '', style: const TextStyle(fontSize: 13)))),
                                ],
                                onChanged: (val) {
                                  if (val != null) setDlgState(() => prof = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Actions: Cancel & Save
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              foregroundColor: ink,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                                side: const BorderSide(color: line),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w500)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              final code = codeCtrl.text.trim().toUpperCase();
                              final name = nameCtrl.text.trim();
                              if (code.isEmpty || name.isEmpty) return;

                              if (isEditing) {
                                data.updateCourse(
                                  course['code']!,
                                  newCode: code,
                                  newName: name,
                                  newBranch: branch,
                                  newSemester: sem,
                                  newType: type,
                                );
                                if (prof.isNotEmpty) {
                                  data.assignProfessor(code, prof);
                                } else {
                                  data.removeAssignment(code);
                                }
                                _showToast('Course updated');
                              } else {
                                data.addCourse(name, code, branch: branch, semester: sem, type: type);
                                if (prof.isNotEmpty) {
                                  data.assignProfessor(code, prof);
                                }
                                _showToast('Course added');
                              }
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ink,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            child: const Text('Save course', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Fullscreen Zoom Mode ──
  void _openFullscreenZoomTable(BuildContext context, ModeratorDataProvider data, List<Map<String, String>> courses) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => FullscreenTableZoomViewer(
          data: data,
          branchFilter: _branchFilter,
          semFilter: _semFilter,
          statusFilter: _statusFilter,
          searchQuery: _searchQuery,
          tableBuilder: (buildCtx, scale) {
            final freshData = buildCtx.watch<ModeratorDataProvider>();
            final list = _getFilteredList(freshData);
            return _buildModeratorTable(buildCtx, freshData, list, scale: scale);
          },
        ),
      ),
    );
  }

  void _showExportDialog(ModeratorDataProvider data) {
    final jsonStr = data.exportJsonString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Attendance Data (JSON)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink)),
        content: SizedBox(
          width: 580,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Complete backup snapshot of courses, faculty, CRs, and attendance sessions:', style: TextStyle(fontSize: 12, color: mut)),
              const SizedBox(height: 10),
              Container(
                height: 240,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(8)),
                child: SingleChildScrollView(
                  child: SelectableText(jsonStr, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF38BDF8))),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonStr));
              Navigator.pop(ctx);
              _showToast('JSON backup copied to clipboard!');
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy to Clipboard'),
            style: ElevatedButton.styleFrom(backgroundColor: ink, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(ModeratorDataProvider data) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Import JSON Backup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink)),
          content: SizedBox(
            width: 580,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Paste previously exported JSON data to restore courses and assignments:', style: TextStyle(fontSize: 12, color: mut)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final clip = await Clipboard.getData(Clipboard.kTextPlain);
                        if (clip?.text != null) {
                          setDlgState(() => controller.text = clip!.text!);
                        }
                      },
                      icon: const Icon(Icons.paste_rounded, size: 14),
                      label: const Text('Paste from Clipboard', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: controller,
                  maxLines: 8,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  decoration: InputDecoration(
                    hintText: '{\n  "courses": [...],\n  "mappings": {...}\n}',
                    filled: true,
                    fillColor: soft,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: line)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                final ok = await data.importJsonString(text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (!mounted) return;
                if (ok) {
                  _showToast('Database restored successfully!');
                } else {
                  _showToast('Failed to parse JSON backup.');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: ink, foregroundColor: Colors.white),
              child: const Text('Import & Restore'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmResetEverything(ModeratorDataProvider data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Everything?'),
        content: const Text(
          'This will permanently wipe out all data (courses, professors, CRs, students, mappings, attendance records, and disk storage). Nothing will be left behind.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await data.resetEverything();
              setState(() {
                _selectedCodes.clear();
              });
              _showToast('Everything wiped out. All data cleared.');
            },
            style: ElevatedButton.styleFrom(backgroundColor: red, foregroundColor: Colors.white),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );
  }

  void _confirmResetDefaults(ModeratorDataProvider data) => _confirmResetEverything(data);

  @override
  Widget build(BuildContext context) {
    final data = context.watch<ModeratorDataProvider>();
    final courses = _getFilteredList(data);

    final totalCourses = data.courses.length;
    final totalProfs = data.professors.length;
    final totalCrs = data.crs.length;
    final assignedCount = data.assignedCourses.length;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_rounded, color: ink, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Moderator Portal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: redBg,
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                'Full Access',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: red),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: line),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Menu',
            icon: const Icon(Icons.more_vert_rounded, color: ink),
            onSelected: (val) {
              if (val == 'reset') {
                _confirmResetEverything(data);
              } else if (val == 'reload') {
                data.seedDefaultData();
                _showToast('Reloaded sample data for all 5 branches');
              } else if (val == 'logout') {
                context.read<AuthProvider>().signOut();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'reload',
                child: Row(
                  children: [
                    Icon(Icons.flash_on_rounded, size: 18, color: blue),
                    SizedBox(width: 8),
                    Text('Reload Sample Data', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restart_alt_rounded, size: 18, color: red),
                    SizedBox(width: 8),
                    Text('Reset Everything', style: TextStyle(fontSize: 13, color: red)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: mut),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1500),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            children: [
              // ── 1. Tools Row ──
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildToolButton(
                      index: 0,
                      label: 'Add Faculty ($totalProfs)',
                      isActive: _activeTopAction == 0,
                    ),
                    const SizedBox(width: 8),
                    _buildToolButton(
                      index: 1,
                      label: 'Import Excel/CSV',
                      isActive: _activeTopAction == 1,
                    ),
                    const SizedBox(width: 8),
                    _buildToolButton(
                      index: 2,
                      label: '3. Add CR ($totalCrs)',
                      isActive: _activeTopAction == 2,
                    ),
                    const SizedBox(width: 8),
                    _buildToolButton(
                      index: 3,
                      label: '+ Course',
                      isActive: false,
                      onTapDirect: () => _openCourseDialog(context, data),
                    ),
                    const SizedBox(width: 8),
                    _buildToolButton(
                      index: 4,
                      label: 'Storage & Backup',
                      isActive: _activeTopAction == 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── 2. Active Tool Form Card ──
              if (_activeTopAction == 0) _buildAddFacultyCard(data),
              if (_activeTopAction == 1) _buildCsvImportCard(data),
              if (_activeTopAction == 2) _buildAddCrCard(data),
              if (_activeTopAction == 4) _buildBackupStorageCard(data),

              // ── 3. Branch Filter Tabs ──
              Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildBranchTab('All', 'All Branches', totalCourses),
                        ...ModeratorDataProvider.supportedBranches.map((br) {
                          final cnt = data.courses.where((c) => (c['branch'] ?? '').toUpperCase() == br).length;
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _buildBranchTab(br, br, cnt),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),

              // ── 4. Search & Filters Card ──
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: line),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Search course code, name, branch or professor…',
                        hintStyle: const TextStyle(color: mut, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: mut),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16, color: mut),
                                onPressed: () => _searchCtrl.clear(),
                              )
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: line)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: line)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: ink)),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        final isMobile = constraints.maxWidth < 600;
                        final semWidget = Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: line),
                            borderRadius: BorderRadius.circular(9),
                            color: Colors.white,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _semFilter,
                              isExpanded: true,
                              style: const TextStyle(fontSize: 13, color: ink, fontWeight: FontWeight.w500),
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
                        );

                        final statusWidget = Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: line),
                            borderRadius: BorderRadius.circular(9),
                            color: Colors.white,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _statusFilter,
                              isExpanded: true,
                              style: const TextStyle(fontSize: 13, color: ink, fontWeight: FontWeight.w500),
                              items: [
                                const DropdownMenuItem(value: 'All', child: Text('All Status')),
                                DropdownMenuItem(value: 'Unassigned', child: Text('Needs professor (${totalCourses - assignedCount})')),
                                DropdownMenuItem(value: 'Assigned', child: Text('Assigned ($assignedCount)')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _statusFilter = val);
                              },
                            ),
                          ),
                        );

                        if (isMobile) {
                          return Column(
                            children: [
                              semWidget,
                              const SizedBox(height: 8),
                              statusWidget,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: semWidget),
                            const SizedBox(width: 10),
                            Expanded(child: statusWidget),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              // ── 5. Courses Table Card ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: line),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Head Row
                    Row(
                      children: [
                        Text.rich(
                          TextSpan(
                            text: 'Courses ',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink),
                            children: [
                              TextSpan(
                                text: '(${courses.length})',
                                style: const TextStyle(color: mut, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Density Toggle
                        OutlinedButton(
                          onPressed: () => setState(() => _isCompact = !_isCompact),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ink,
                            side: const BorderSide(color: line),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(_isCompact ? 'Comfortable' : 'Compact', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
                        ),
                        const SizedBox(width: 8),
                        // Copy CSV
                        OutlinedButton(
                          onPressed: () => _copyCsv(courses, data),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ink,
                            side: const BorderSide(color: line),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Copy CSV', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
                        ),
                        const SizedBox(width: 10),
                        // Zoom Out button
                        Tooltip(
                          message: 'Zoom Out Table',
                          child: InkWell(
                            onTap: _tableScale > 0.70
                                ? () => setState(() => _tableScale = (_tableScale - 0.15).clamp(0.70, 2.0))
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: line),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text('−', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _tableScale > 0.70 ? ink : mut)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Zoom Value Chip (Tap to reset)
                        Tooltip(
                          message: 'Current Zoom: ${(_tableScale * 100).round()}%. Tap to reset to 100%',
                          child: InkWell(
                            onTap: () => setState(() => _tableScale = 1.0),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Text(
                                '${(_tableScale * 100).round()}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _tableScale != 1.0 ? blue : ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Zoom In button
                        Tooltip(
                          message: 'Zoom In Table',
                          child: InkWell(
                            onTap: _tableScale < 2.0
                                ? () => setState(() => _tableScale = (_tableScale + 0.15).clamp(0.70, 2.0))
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: line),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text('+', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _tableScale < 2.0 ? ink : mut)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Zoom View (Opens Fullscreen Zoom Viewer)
                        ElevatedButton.icon(
                          onPressed: () => _openFullscreenZoomTable(context, data, courses),
                          icon: const Icon(Icons.fullscreen_rounded, size: 14),
                          label: const Text('Zoom View', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ink,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Bulk Actions Banner
                    if (_selectedCodes.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: ink,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${_selectedCodes.length} selected',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            Container(
                              height: 34,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  hint: const Text('Assign professor to selected…', style: TextStyle(fontSize: 12, color: ink, fontWeight: FontWeight.w500)),
                                  items: data.professors.map((p) {
                                    final name = p['name'] ?? '';
                                    return DropdownMenuItem(value: name, child: Text(name, style: const TextStyle(fontSize: 12, color: ink)));
                                  }).toList(),
                                  onChanged: (prof) {
                                    if (prof != null) _bulkAssign(prof, data);
                                  },
                                ),
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () => _bulkDelete(data),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Color(0xFF475569)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Delete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                            OutlinedButton(
                              onPressed: () => setState(() => _selectedCodes.clear()),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Color(0xFF475569)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Clear', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Spreadsheet Table Window
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: line),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: courses.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.menu_book_outlined, size: 36, color: mut.withValues(alpha: 0.5)),
                                    const SizedBox(height: 10),
                                    Text(
                                      totalCourses == 0
                                          ? 'No courses added yet.'
                                          : 'No courses match current filters.',
                                      style: const TextStyle(color: ink, fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      totalCourses == 0
                                          ? 'Click "+ Course" or "Import Excel/CSV" above to start adding courses.'
                                          : 'Try adjusting your search query, branch, or semester filters.',
                                      style: const TextStyle(color: mut, fontSize: 12.5),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: _buildModeratorTable(
                                    context,
                                    data,
                                    courses,
                                    scale: _tableScale,
                                    availableWidth: constraints.maxWidth,
                                  ),
                                );
                              },
                            ),
                    ),

                    // Table Footer
                    Padding(
                      padding: const EdgeInsets.only(top: 12, left: 2),
                      child: Text(
                        'Showing ${courses.length} of $totalCourses courses',
                        style: const TextStyle(color: mut, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Tool Button Helper ──
  Widget _buildToolButton({
    required int index,
    required String label,
    required bool isActive,
    VoidCallback? onTapDirect,
  }) {
    return InkWell(
      onTap: onTapDirect ?? () => setState(() => _activeTopAction = index),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? ink : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: isActive ? ink : line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? Colors.white : ink,
          ),
        ),
      ),
    );
  }

  // ── Branch Filter Tab Helper ──
  Widget _buildBranchTab(String key, String title, int count) {
    final isSelected = _branchFilter == key;
    return InkWell(
      onTap: () => setState(() => _branchFilter = key),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? ink : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: isSelected ? ink : line),
        ),
        child: Text(
          '$title ($count)',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : mut,
          ),
        ),
      ),
    );
  }

  // ── Tool Card 0: Add Faculty ──
  Widget _buildAddFacultyCard(ModeratorDataProvider data) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _profEmailCtrl,
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'Professor Email',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: ink)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          if (_extractedProfName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Name preview: Dr. $_extractedProfName',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: blue),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: line),
                    color: Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedProfDept,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 13, color: ink, fontWeight: FontWeight.w500),
                      items: const [
                        DropdownMenuItem(value: 'ECE', child: Text('ECE Dept')),
                        DropdownMenuItem(value: 'CSE', child: Text('CSE Dept')),
                        DropdownMenuItem(value: 'EEE', child: Text('EEE Dept')),
                        DropdownMenuItem(value: 'MCE', child: Text('MCE Dept')),
                        DropdownMenuItem(value: 'CVE', child: Text('CVE Dept')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedProfDept = val);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  final email = _profEmailCtrl.text.trim();
                  if (email.isNotEmpty) {
                    final name = _extractedProfName.isNotEmpty ? 'Dr. $_extractedProfName' : null;
                    data.addProfessor(email, name: name, department: _selectedProfDept);
                    _profEmailCtrl.clear();
                    _showToast('${name ?? email} added');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  minimumSize: const Size(0, 42),
                ),
                child: const Text('+ Add Faculty', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tool Card 1: Import Excel/CSV ──
  Widget _buildCsvImportCard(ModeratorDataProvider data) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: line),
                    color: Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _importBranchTarget,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 13, color: ink, fontWeight: FontWeight.w500),
                      items: const [
                        DropdownMenuItem(value: 'Auto-detect', child: Text('Target: Auto-detect from file')),
                        DropdownMenuItem(value: 'ECE', child: Text('Target: ECE Dept')),
                        DropdownMenuItem(value: 'CSE', child: Text('Target: CSE Dept')),
                        DropdownMenuItem(value: 'EEE', child: Text('Target: EEE Dept')),
                        DropdownMenuItem(value: 'MCE', child: Text('Target: MCE Dept')),
                        DropdownMenuItem(value: 'CVE', child: Text('Target: CVE Dept')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _importBranchTarget = val);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _pickAndImportFile(context, data),
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: const Text('Choose File (.xlsx, .csv)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  minimumSize: const Size(0, 42),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _openPasteTextDialog(context, data),
                icon: const Icon(Icons.content_paste_rounded, size: 16),
                label: const Text('Paste Text'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ink,
                  side: const BorderSide(color: line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  minimumSize: const Size(0, 42),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tool Card 2: 3. Add CR ──
  Widget _buildAddCrCard(ModeratorDataProvider data) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _crEmailCtrl,
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              labelText: 'CR Email',
              hintText: 'cr.ece@nitgoa.ac.in',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: ink)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          if (_extractedCrName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Name preview: $_extractedCrName (CR)',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: amber),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: line),
                    color: Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _crBranch,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 13, color: ink, fontWeight: FontWeight.w500),
                      items: const [
                        DropdownMenuItem(value: 'ECE', child: Text('ECE Branch')),
                        DropdownMenuItem(value: 'CSE', child: Text('CSE Branch')),
                        DropdownMenuItem(value: 'EEE', child: Text('EEE Branch')),
                        DropdownMenuItem(value: 'MCE', child: Text('MCE Branch')),
                        DropdownMenuItem(value: 'CVE', child: Text('CVE Branch')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _crBranch = val);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: line),
                    color: Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _crSemester,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 13, color: ink, fontWeight: FontWeight.w500),
                      items: const [
                        DropdownMenuItem(value: 'IV Sem', child: Text('IV Sem')),
                        DropdownMenuItem(value: 'VI Sem', child: Text('VI Sem')),
                        DropdownMenuItem(value: 'VIII Sem', child: Text('VIII Sem')),
                        DropdownMenuItem(value: 'M.Tech', child: Text('M.Tech')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _crSemester = val);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  final email = _crEmailCtrl.text.trim();
                  if (email.isNotEmpty) {
                    final name = _extractedCrName.isNotEmpty ? '$_extractedCrName ($_crBranch CR)' : null;
                    data.addCR(email, name: name, branch: _crBranch, semester: _crSemester);
                    _crEmailCtrl.clear();
                    _showToast('${name ?? email} registered as CR');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  minimumSize: const Size(0, 42),
                ),
                child: const Text('Add CR', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tool Card 4: Storage & Backup ──
  Widget _buildBackupStorageCard(ModeratorDataProvider data) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton.icon(
            onPressed: () => _showExportDialog(data),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Export JSON Backup'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _showImportDialog(data),
            icon: const Icon(Icons.upload_rounded, size: 16),
            label: const Text('Import JSON Backup'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ink,
              side: const BorderSide(color: line),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              await data.saveToStorage();
              _showToast('All changes flushed to disk!');
            },
            icon: const Icon(Icons.save_rounded, size: 16, color: blue),
            label: const Text('Force Save Now', style: TextStyle(color: blue)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF93C5FD)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _confirmResetEverything(data),
            icon: const Icon(Icons.restart_alt_rounded, size: 16, color: red),
            label: const Text('Reset Everything', style: TextStyle(color: red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFCA5A5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  // ── Main Spreadsheet Table Builder ──
  Widget _buildModeratorTable(
    BuildContext context,
    ModeratorDataProvider data,
    List<Map<String, String>> courses, {
    double scale = 1.0,
    double? availableWidth,
  }) {
    final double baseWidth = 945.0 * scale;
    final double targetWidth = (availableWidth != null && availableWidth.isFinite)
        ? math.max(baseWidth, availableWidth)
        : baseWidth;
    final double extraWidth = targetWidth > baseWidth ? (targetWidth - baseWidth) : 0.0;

    final double colWidthCheck = (42.0 * scale);
    final double colWidthSl = (40.0 * scale);
    final double colWidthCode = (105.0 * scale);
    final double colWidthName = (245.0 * scale) + (extraWidth * 0.55);
    final double colWidthBranch = (85.0 * scale);
    final double colWidthSem = (90.0 * scale);
    final double colWidthProf = (250.0 * scale) + (extraWidth * 0.45);
    final double colWidthAction = (88.0 * scale);

    final double verticalPad = _isCompact ? (6.0 * scale) : (11.0 * scale);
    final allSelected = courses.isNotEmpty && courses.every((c) => _selectedCodes.contains(c['code']));
    final loadMap = _calcProfLoad(data);

    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: {
        0: FixedColumnWidth(colWidthCheck),
        1: FixedColumnWidth(colWidthSl),
        2: FixedColumnWidth(colWidthCode),
        3: FixedColumnWidth(colWidthName),
        4: FixedColumnWidth(colWidthBranch),
        5: FixedColumnWidth(colWidthSem),
        6: FixedColumnWidth(colWidthProf),
        7: FixedColumnWidth(colWidthAction),
      },
      children: [
        // ── Header Row ──
        TableRow(
          decoration: const BoxDecoration(
            color: soft,
            border: Border(bottom: BorderSide(color: line)),
          ),
          children: [
            // Checkbox: Select all
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4.0 * scale),
              child: Center(
                child: Checkbox(
                  value: allSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        for (final c in courses) {
                          final code = c['code'];
                          if (code != null) _selectedCodes.add(code);
                        }
                      } else {
                        for (final c in courses) {
                          _selectedCodes.remove(c['code']);
                        }
                      }
                    });
                  },
                  activeColor: ink,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
            _buildHeaderCell('#', ModColumnSort.slNo, align: TextAlign.center, scale: scale),
            _buildHeaderCell('Course Code', ModColumnSort.code, scale: scale),
            _buildHeaderCell('Course Name', ModColumnSort.name, scale: scale),
            _buildHeaderCell('Branch', ModColumnSort.branch, align: TextAlign.center, scale: scale),
            _buildHeaderCell('Semester', ModColumnSort.semester, align: TextAlign.center, scale: scale),
            _buildHeaderCell('Assigned Professor', ModColumnSort.professor, scale: scale),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0 * scale, vertical: 11.0 * scale),
              child: Text(
                'Actions',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: mut,
                  fontWeight: FontWeight.w600,
                  fontSize: (11.0 * scale).clamp(8.5, 20.0),
                ),
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
          final isSelected = _selectedCodes.contains(code);

          return TableRow(
            decoration: BoxDecoration(
              color: isSelected ? blueBg : Colors.white,
              border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            children: [
              // 0: Checkbox
              Padding(
                padding: EdgeInsets.symmetric(vertical: 2.0 * scale),
                child: Center(
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedCodes.add(code);
                        } else {
                          _selectedCodes.remove(code);
                        }
                      });
                    },
                    activeColor: ink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ),

              // 1: Row index #
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0 * scale, vertical: verticalPad),
                child: Text(
                  '$idx',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: (11.0 * scale).clamp(8.5, 20.0),
                    color: const Color(0xFF94A3B8),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),

              // 2: Course Code
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0 * scale, vertical: verticalPad),
                child: Text(
                  code,
                  style: TextStyle(
                    fontSize: (12.5 * scale).clamp(9.5, 22.0),
                    fontWeight: FontWeight.w600,
                    color: ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),

              // 3: Course Name + Type Badge
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0 * scale, vertical: verticalPad),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: (12.5 * scale).clamp(9.5, 22.0),
                          fontWeight: FontWeight.w500,
                          color: ink,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildTypeBadge(type, scale: scale),
                  ],
                ),
              ),

              // 4: Branch Badge
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0 * scale, vertical: verticalPad),
                  child: _buildBranchBadge(branch, scale: scale),
                ),
              ),

              // 5: Semester Badge
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0 * scale, vertical: verticalPad),
                  child: _buildSemesterBadge(sem, scale: scale),
                ),
              ),

              // 6: Assigned Professor
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0 * scale, vertical: (verticalPad - 3).clamp(2.0, 15.0)),
                child: prof != null && prof.isNotEmpty
                    ? Row(
                        children: [
                          Container(
                            width: 28 * scale,
                            height: 28 * scale,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE0E7FF),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _getProfInitials(prof),
                              style: TextStyle(
                                color: const Color(0xFF3730A3),
                                fontSize: (11 * scale).clamp(8.0, 18.0),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(width: 8 * scale),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: data.professors.any((p) => p['name'] == prof) ? prof : null,
                                isDense: true,
                                isExpanded: true,
                                style: TextStyle(
                                  fontSize: (12.5 * scale).clamp(9.0, 20.0),
                                  fontWeight: FontWeight.w500,
                                  color: ink,
                                ),
                                items: [
                                  const DropdownMenuItem(value: '', child: Text('Unassigned', style: TextStyle(color: mut))),
                                  ...data.professors.map((p) => DropdownMenuItem(
                                    value: p['name'] ?? '',
                                    child: Text(p['name'] ?? '', overflow: TextOverflow.ellipsis),
                                  )),
                                ],
                                onChanged: (newProf) {
                                  if (newProf == null || newProf.isEmpty) {
                                    data.removeAssignment(code);
                                    _showToast('$code unassigned');
                                  } else {
                                    data.assignProfessor(code, newProf);
                                    _showToast('$code → $newProf');
                                  }
                                },
                              ),
                            ),
                          ),
                          SizedBox(width: 4 * scale),
                          Text(
                            '${loadMap[prof] ?? 0} courses',
                            style: TextStyle(
                              fontSize: (10 * scale).clamp(7.5, 16.0),
                              color: mut,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Container(
                            width: 28 * scale,
                            height: 28 * scale,
                            decoration: BoxDecoration(
                              color: amberBg,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFF59E0B), style: BorderStyle.solid),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '?',
                              style: TextStyle(
                                color: amber,
                                fontSize: (12 * scale).clamp(8.0, 18.0),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(width: 8 * scale),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: null,
                                hint: Text(
                                  'Assign professor',
                                  style: TextStyle(
                                    fontSize: (12 * scale).clamp(8.5, 18.0),
                                    fontWeight: FontWeight.w500,
                                    color: amber,
                                  ),
                                ),
                                isDense: true,
                                isExpanded: true,
                                items: [
                                  ...data.professors.map((p) => DropdownMenuItem(
                                    value: p['name'] ?? '',
                                    child: Text(p['name'] ?? '', overflow: TextOverflow.ellipsis),
                                  )),
                                ],
                                onChanged: (newProf) {
                                  if (newProf != null && newProf.isNotEmpty) {
                                    data.assignProfessor(code, newProf);
                                    _showToast('$code → $newProf');
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
              ),

              // 7: Moderator Actions (✎ Edit + 🗑 Delete)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0 * scale, vertical: (verticalPad - 4).clamp(1.0, 12.0)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () => _openCourseDialog(context, data, course: c),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 32 * scale,
                        height: 32 * scale,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: line),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.edit_outlined, size: (15 * scale).clamp(10.0, 24.0), color: ink),
                      ),
                    ),
                    SizedBox(width: 6 * scale),
                    InkWell(
                      onTap: () => _deleteCourse(c, data),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 32 * scale,
                        height: 32 * scale,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: line),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.delete_outline_rounded, size: (15 * scale).clamp(10.0, 24.0), color: mut),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  // ── Header Cell Builder ──
  Widget _buildHeaderCell(String label, ModColumnSort col, {TextAlign align = TextAlign.left, double scale = 1.0}) {
    final isSelected = _sortColumn == col;
    return InkWell(
      onTap: () => _onHeaderTapped(col),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.0 * scale, vertical: 11.0 * scale),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: align == TextAlign.center ? Alignment.center : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: align == TextAlign.center ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Text(
                label,
                textAlign: align,
                style: TextStyle(
                  color: isSelected ? ink : mut,
                  fontWeight: FontWeight.w600,
                  fontSize: (11.5 * scale).clamp(8.5, 20.0),
                ),
              ),
              const SizedBox(width: 3),
              Text(
                isSelected ? (_sortAsc ? '▲' : '▼') : '▲',
                style: TextStyle(
                  fontSize: (9.0 * scale).clamp(7.0, 14.0),
                  color: isSelected ? blue : mut.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Type Badge Builder ──
  Widget _buildTypeBadge(String type, {double scale = 1.0}) {
    Color bgColor = const Color(0xFFF1F5F9);
    Color textColor = mut;
    if (type == 'MLC') {
      bgColor = amberBg;
      textColor = amber;
    } else if (type == 'Lab') {
      bgColor = const Color(0xFFECFDF5);
      textColor = const Color(0xFF047857);
    } else if (type == 'Elective' || type == 'OE') {
      bgColor = const Color(0xFFF5F3FF);
      textColor = const Color(0xFF6D28D9);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: (7.0 * scale).clamp(4.0, 14.0), vertical: (2.0 * scale).clamp(1.0, 6.0)),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: (10.0 * scale).clamp(7.5, 16.0),
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  // ── Branch Badge Builder ──
  Widget _buildBranchBadge(String branch, {double scale = 1.0}) {
    Color bgColor = blueBg;
    Color textColor = blue;
    switch (branch.toUpperCase()) {
      case 'CSE':
        bgColor = const Color(0xFFF5F3FF);
        textColor = const Color(0xFF7C3AED);
        break;
      case 'ECE':
        bgColor = const Color(0xFFEFF6FF);
        textColor = const Color(0xFF2563EB);
        break;
      case 'EEE':
        bgColor = const Color(0xFFECFDF5);
        textColor = const Color(0xFF059669);
        break;
      case 'MCE':
      case 'ME':
        bgColor = const Color(0xFFFFF7ED);
        textColor = const Color(0xFFEA580C);
        break;
      case 'CVE':
      case 'CE':
        bgColor = const Color(0xFFFEF2F2);
        textColor = const Color(0xFFDC2626);
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: (8.0 * scale).clamp(4.0, 16.0), vertical: (2.5 * scale).clamp(1.0, 6.0)),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        branch,
        style: TextStyle(
          fontSize: (11.0 * scale).clamp(8.0, 18.0),
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  // ── Semester Badge Builder ──
  Widget _buildSemesterBadge(String semester, {double scale = 1.0}) {
    final label = semester.contains('Sem') ? semester : '$semester Sem';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: (8.0 * scale).clamp(4.0, 16.0), vertical: (2.5 * scale).clamp(1.0, 6.0)),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: (11.0 * scale).clamp(8.0, 18.0),
          fontWeight: FontWeight.w600,
          color: const Color(0xFF334155),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FULLSCREEN TABLE ZOOM VIEWER
// ══════════════════════════════════════════════════════════════
class FullscreenTableZoomViewer extends StatefulWidget {
  final ModeratorDataProvider data;
  final String branchFilter;
  final String semFilter;
  final String statusFilter;
  final String searchQuery;
  final Widget Function(BuildContext context, double scale) tableBuilder;

  const FullscreenTableZoomViewer({
    super.key,
    required this.data,
    required this.branchFilter,
    required this.semFilter,
    required this.statusFilter,
    required this.searchQuery,
    required this.tableBuilder,
  });

  @override
  State<FullscreenTableZoomViewer> createState() => _FullscreenTableZoomViewerState();
}

class _FullscreenTableZoomViewerState extends State<FullscreenTableZoomViewer> {
  final TransformationController _transController = TransformationController();
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _transController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transController.removeListener(_onTransformChanged);
    _transController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _transController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.03) {
      setState(() => _currentScale = scale);
    }
  }

  void _zoomIn() {
    final current = _transController.value.getMaxScaleOnAxis();
    final target = (current + 0.25).clamp(0.5, 3.5);
    _setScale(target);
  }

  void _zoomOut() {
    final current = _transController.value.getMaxScaleOnAxis();
    final target = (current - 0.25).clamp(0.5, 3.5);
    _setScale(target);
  }

  void _resetZoom() {
    _setScale(1.0);
  }

  void _setScale(double target) {
    setState(() {
      _currentScale = target;
      _transController.value = Matrix4.diagonal3Values(target, target, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ModeratorDataProvider>();

    final filterDesc = [
      if (widget.branchFilter != 'All') widget.branchFilter,
      if (widget.semFilter != 'All') widget.semFilter,
      if (widget.statusFilter != 'All') widget.statusFilter,
      if (widget.searchQuery.isNotEmpty) '"${widget.searchQuery}"',
    ].join(' • ');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Zoom Out & Exit',
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.zoom_in_rounded, size: 18, color: Color(0xFF38BDF8)),
                SizedBox(width: 6),
                Text(
                  'Course Table (Zoom Mode)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ],
            ),
            Text(
              filterDesc.isNotEmpty ? filterDesc : 'Full Master Course Sheet',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white, size: 20),
            tooltip: 'Zoom Out',
            onPressed: _zoomOut,
          ),
          Center(
            child: InkWell(
              onTap: _resetZoom,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF38BDF8)),
                ),
                child: Text(
                  '${(_currentScale * 100).round()}%',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF38BDF8)),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 20),
            tooltip: 'Zoom In',
            onPressed: _zoomIn,
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_fullscreen_rounded, size: 14),
              label: const Text('Exit Zoom', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _transController,
              constrained: false,
              minScale: 0.4,
              maxScale: 3.5,
              boundaryMargin: const EdgeInsets.all(300),
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: widget.tableBuilder(context, 1.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
