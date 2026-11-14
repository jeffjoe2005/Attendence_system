import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/moderator_data_provider.dart';

// ─────────────────────────────────────────────────────────────
//  Theme & Attendance Threshold Palette
// ─────────────────────────────────────────────────────────────
const _kInk = Color(0xFF0F172A);
const _kMuted = Color(0xFF64748B);
const _kLine = Color(0xFFE2E8F0);
const _kPageBg = Color(0xFFF1F5F9);
const _kSoftBg = Color(0xFFF8FAFC);

const _kRed = Color(0xFFEF4444); // < 75 %
const _kRedText = Color(0xFFB91C1C);
const _kRedBg = Color(0xFFFEE2E2);
const _kRedBorder = Color(0xFFFCA5A5);

const _kYellow = Color(0xFFEAB308); // 75 – 80 %
const _kYellowText = Color(0xFFA16207);
const _kYellowBg = Color(0xFFFEF9C3);
const _kYellowBorder = Color(0xFFFDE047);

const _kGreen = Color(0xFF22C55E); // > 80 %
const _kGreenText = Color(0xFF15803D);
const _kGreenBg = Color(0xFFDCFCE7);
const _kGreenBorder = Color(0xFF86EFAC);

const _kNeutral = Color(0xFF94A3B8); // 0 classes taken
const _kNeutralText = Color(0xFF475569);
const _kNeutralBg = Color(0xFFF8FAFC);
const _kNeutralBorder = Color(0xFFE2E8F0);

enum _AttendanceBand { all, short, borderline, good }

class _AttendanceStyle {
  const _AttendanceStyle({
    required this.accent,
    required this.text,
    required this.bg,
    required this.border,
    required this.label,
    required this.icon,
    required this.band,
  });

  final Color accent;
  final Color text;
  final Color bg;
  final Color border;
  final String label;
  final IconData icon;
  final _AttendanceBand band;

  factory _AttendanceStyle.fromPercentage(double? pct) {
    if (pct == null) {
      return const _AttendanceStyle(
        accent: _kNeutral,
        text: _kNeutralText,
        bg: _kNeutralBg,
        border: _kNeutralBorder,
        label: 'No Classes Yet',
        icon: Icons.schedule_rounded,
        band: _AttendanceBand.all,
      );
    }
    if (pct < 75) {
      return const _AttendanceStyle(
        accent: _kRed,
        text: _kRedText,
        bg: _kRedBg,
        border: _kRedBorder,
        label: 'Short Attendance',
        icon: Icons.warning_amber_rounded,
        band: _AttendanceBand.short,
      );
    }
    if (pct <= 80) {
      return const _AttendanceStyle(
        accent: _kYellow,
        text: _kYellowText,
        bg: _kYellowBg,
        border: _kYellowBorder,
        label: 'Borderline',
        icon: Icons.info_outline_rounded,
        band: _AttendanceBand.borderline,
      );
    }
    return const _AttendanceStyle(
      accent: _kGreen,
      text: _kGreenText,
      bg: _kGreenBg,
      border: _kGreenBorder,
      label: 'Good Standing',
      icon: Icons.check_circle_rounded,
      band: _AttendanceBand.good,
    );
  }
}

class _CourseAttendanceItem {
  const _CourseAttendanceItem({
    required this.code,
    required this.name,
    required this.type,
    required this.prof,
    required this.attended,
    required this.total,
    required this.pct,
    required this.style,
  });

  final String code;
  final String name;
  final String type;
  final String prof;
  final int attended;
  final int total;
  final double? pct;
  final _AttendanceStyle style;
}

// ─────────────────────────────────────────────────────────────
//  Student Portal
// ─────────────────────────────────────────────────────────────
class ServerStudentDashboard extends StatefulWidget {
  const ServerStudentDashboard({super.key, this.studentRoll, this.serverData});

  final Map<String, dynamic>? serverData;

  /// Optional explicit student roll override (useful for preview/testing).
  final String? studentRoll;

  @override
  State<ServerStudentDashboard> createState() => _ServerStudentDashboardState();
}

class _ServerStudentDashboardState extends State<ServerStudentDashboard>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  late final AnimationController _animCtrl;
  String _searchQuery = '';
  _AttendanceBand _selectedBand = _AttendanceBand.all;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q != _searchQuery) {
        setState(() => _searchQuery = q);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  static String _semesterLabelFromInt(int sem) {
    switch (sem) {
      case 3:
        return 'III Sem';
      case 4:
        return 'IV Sem';
      case 5:
        return 'V Sem';
      case 6:
        return 'VI Sem';
      case 7:
        return 'VII Sem';
      case 8:
        return 'VIII Sem';
      default:
        return 'VI Sem';
    }
  }

  Map<String, String> _resolveActiveStudent(
    AuthProvider auth,
    ModeratorDataProvider modData,
  ) {
    if (widget.serverData != null) {
      final user = Map<String, dynamic>.from(widget.serverData!['user']);
      return {
        'roll': user['roll_number'] ?? '',
        'name': user['name'] ?? 'Student',
        'branch': user['branch'] ?? '',
        'semester': (user['semester'] ?? 0) > 0
            ? _semesterLabelFromInt(user['semester'])
            : 'Not assigned',
        'email': user['email'] ?? ''
      };
    }
    final overrideRoll = widget.studentRoll?.trim() ?? '';
    if (overrideRoll.isNotEmpty) {
      final matched = modData.students.where((s) => s['roll'] == overrideRoll);
      if (matched.isNotEmpty) {
        return matched.first;
      }
    }

    final user = auth.userModel;
    if (user != null) {
      final userRoll = user.rollNumber.trim();
      final userEmail = user.email.trim().toLowerCase();
      final matched = modData.students.where((s) =>
          (userRoll.isNotEmpty && s['roll'] == userRoll) ||
          (userEmail.isNotEmpty &&
              (s['email'] ?? '').toLowerCase() == userEmail));
      if (matched.isNotEmpty) {
        return matched.first;
      }
      return {
        'roll': userRoll.isNotEmpty ? userRoll : 'NITG-STD',
        'name': user.name.isNotEmpty ? user.name : 'Student',
        'branch': user.branch.isNotEmpty ? user.branch : 'ECE',
        'semester':
            user.semester > 0 ? _semesterLabelFromInt(user.semester) : 'VI Sem',
        'email': user.email,
      };
    }

    if (modData.students.isNotEmpty) {
      return modData.students.first;
    }

    return const {
      'roll': '',
      'name': 'Student',
      'branch': 'ECE',
      'semester': 'VI Sem',
      'email': 'student@nitgoa.ac.in',
    };
  }

  List<_CourseAttendanceItem> _buildCourseItems(
    List<Map<String, String>> enrolledCourses,
    String activeRoll,
    ModeratorDataProvider modData,
  ) {
    return enrolledCourses.map((c) {
      final code = c['code'] ?? '';
      final name = c['name'] ?? '';
      final type = c['type'] ?? 'Theory';
      final prof = widget.serverData != null
          ? (c['professor_name'] ?? 'Unassigned')
          : modData.getProfessorForCourse(code) ?? 'Unassigned';

      final sessions = modData.getSessionsForCourse(code);
      int attended = 0;
      for (final s in sessions) {
        final presents =
            List<String>.from(s['presentRolls'] as Iterable? ?? []);
        if (presents.contains(activeRoll)) {
          attended++;
        }
      }

      final serverStats = widget.serverData?['stats']?[c['id']];
      if (serverStats != null) attended = serverStats['attended'] as int;
      final total =
          serverStats != null ? serverStats['total'] as int : sessions.length;
      final double? pct = total > 0 ? (attended / total) * 100 : null;
      return _CourseAttendanceItem(
        code: code,
        name: name,
        type: type,
        prof: prof,
        attended: attended,
        total: total,
        pct: pct,
        style: _AttendanceStyle.fromPercentage(pct),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final modData = context.watch<ModeratorDataProvider>();

    final studentData = _resolveActiveStudent(auth, modData);
    final activeRoll = studentData['roll'] ?? '';
    final studentName = studentData['name'] ?? 'Student';
    final branch = studentData['branch'] ?? 'ECE';
    final semester = studentData['semester'] ?? 'VI Sem';
    final normBranch = ModeratorDataProvider.normalizeBranch(branch);

    final enrolledCourses = widget.serverData != null
        ? List<Map<String, dynamic>>.from(widget.serverData!['courses'])
            .where((c) =>
                (widget.serverData!['enrolled_ids'] as List).contains(c['id']))
            .map((c) => c.map((k, v) => MapEntry(k, v?.toString() ?? '')))
            .toList()
        : modData.courses.where((c) {
            final rawB = c['branch'] ?? '';
            final normB = ModeratorDataProvider.normalizeBranch(rawB);
            final s = c['semester'] ?? '';
            return (normB == normBranch || rawB == 'General') && s == semester;
          }).toList();

    final allItems = _buildCourseItems(enrolledCourses, activeRoll, modData);
    final filteredItems = allItems.where((item) {
      if (_selectedBand != _AttendanceBand.all &&
          item.style.band != _selectedBand) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final matchesCode = item.code.toLowerCase().contains(_searchQuery);
        final matchesName = item.name.toLowerCase().contains(_searchQuery);
        final matchesProf = item.prof.toLowerCase().contains(_searchQuery);
        return matchesCode || matchesName || matchesProf;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        child: Column(
          children: [
            _StudentHeader(
              studentName: studentName,
              activeRoll: activeRoll,
              branch: branch,
              semester: semester,
              onSignOut: () => context.read<AuthProvider>().signOut(),
            ),
            Expanded(
              child: FadeTransition(
                opacity:
                    CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ToolbarSection(
                              totalCount: allItems.length,
                              visibleCount: filteredItems.length,
                              selectedBand: _selectedBand,
                              searchController: _searchCtrl,
                              hasQuery: _searchQuery.isNotEmpty,
                              onSelectBand: (band) {
                                setState(() {
                                  _selectedBand = _selectedBand == band
                                      ? _AttendanceBand.all
                                      : band;
                                });
                              },
                              onClearSearch: () => _searchCtrl.clear(),
                            ),
                            const SizedBox(height: 16),
                            if (allItems.isEmpty)
                              _EmptyCoursesCard(
                                  branch: branch, semester: semester)
                            else if (filteredItems.isEmpty)
                              _NoMatchingCoursesCard(
                                onResetFilters: () {
                                  _searchCtrl.clear();
                                  setState(() =>
                                      _selectedBand = _AttendanceBand.all);
                                },
                              )
                            else
                              _ResponsiveCourseGrid(items: filteredItems),
                          ],
                        ),
                      ),
                    ),
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
//  Clean Minimalist Header (matches app theme)
// ─────────────────────────────────────────────────────────────
class _StudentHeader extends StatelessWidget {
  const _StudentHeader({
    required this.studentName,
    required this.activeRoll,
    required this.branch,
    required this.semester,
    required this.onSignOut,
  });

  final String studentName;
  final String activeRoll;
  final String branch;
  final String semester;
  final VoidCallback onSignOut;

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'S';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _kLine)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Row(
            children: [
              // Monogram Avatar
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _kInk,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Text(
                    _initials(studentName),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Student Name + Meta Chips
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kInk),
                    ),
                    const Text('Student Portal', style: TextStyle(fontSize: 10, color: Color(0xFF2563EB))),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (activeRoll.isNotEmpty)
                          _MetaChip(label: activeRoll, bold: true),
                        _MetaChip(label: branch),
                        _MetaChip(label: semester),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Logout action
              OutlinedButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout_rounded, size: 15),
                label: const Text('Logout',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kInk,
                  backgroundColor: _kSoftBg,
                  side: const BorderSide(color: _kLine),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.bold = false});
  final String label;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _kPageBg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          color: bold ? _kInk : _kMuted,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Toolbar: Heading, Count Badge, Search & Interactive Colour Legend
// ─────────────────────────────────────────────────────────────
class _ToolbarSection extends StatelessWidget {
  const _ToolbarSection({
    required this.totalCount,
    required this.visibleCount,
    required this.selectedBand,
    required this.searchController,
    required this.hasQuery,
    required this.onSelectBand,
    required this.onClearSearch,
  });

  final int totalCount;
  final int visibleCount;
  final _AttendanceBand selectedBand;
  final TextEditingController searchController;
  final bool hasQuery;
  final ValueChanged<_AttendanceBand> onSelectBand;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final countLabel = selectedBand == _AttendanceBand.all && !hasQuery
        ? '$totalCount subjects'
        : '$visibleCount of $totalCount';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 680;
              final titleRow = Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Registered Courses',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _kInk,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kInk,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      countLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              );

              final searchBox = SizedBox(
                width: isWide ? 280 : double.infinity,
                height: 38,
                child: TextField(
                  controller: searchController,
                  style: const TextStyle(fontSize: 12.5, color: _kInk),
                  decoration: InputDecoration(
                    hintText: 'Search code, course, or faculty...',
                    hintStyle:
                        const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 17, color: _kMuted),
                    suffixIcon: hasQuery
                        ? IconButton(
                            onPressed: onClearSearch,
                            icon: const Icon(Icons.close_rounded,
                                size: 16, color: _kMuted),
                            padding: EdgeInsets.zero,
                          )
                        : null,
                    filled: true,
                    fillColor: _kSoftBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: const BorderSide(color: _kLine),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: const BorderSide(color: _kLine),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: const BorderSide(color: _kInk),
                    ),
                  ),
                ),
              );

              if (isWide) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [titleRow, searchBox],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleRow,
                  const SizedBox(height: 10),
                  searchBox,
                ],
              );
            },
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: _kPageBg),
          const SizedBox(height: 12),

          // Colour Threshold Legend / Filter Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _LegendFilterPill(
                label: 'All',
                dotColor: _kInk,
                activeBg: _kInk,
                activeBorder: _kInk,
                activeText: Colors.white,
                isActive: selectedBand == _AttendanceBand.all,
                onTap: () => onSelectBand(_AttendanceBand.all),
              ),
              _LegendFilterPill(
                label: '< 75% Short',
                dotColor: _kRed,
                activeBg: _kRedBg,
                activeBorder: _kRedBorder,
                activeText: _kRedText,
                isActive: selectedBand == _AttendanceBand.short,
                onTap: () => onSelectBand(_AttendanceBand.short),
              ),
              _LegendFilterPill(
                label: '75 – 80% Borderline',
                dotColor: _kYellow,
                activeBg: _kYellowBg,
                activeBorder: _kYellowBorder,
                activeText: _kYellowText,
                isActive: selectedBand == _AttendanceBand.borderline,
                onTap: () => onSelectBand(_AttendanceBand.borderline),
              ),
              _LegendFilterPill(
                label: '> 80% Good',
                dotColor: _kGreen,
                activeBg: _kGreenBg,
                activeBorder: _kGreenBorder,
                activeText: _kGreenText,
                isActive: selectedBand == _AttendanceBand.good,
                onTap: () => onSelectBand(_AttendanceBand.good),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendFilterPill extends StatelessWidget {
  const _LegendFilterPill({
    required this.label,
    required this.dotColor,
    required this.activeBg,
    required this.activeBorder,
    required this.activeText,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final Color dotColor;
  final Color activeBg;
  final Color activeBorder;
  final Color activeText;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? activeBg : _kSoftBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? activeBorder : _kLine,
            width: isActive ? 1.3 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive && activeBg == _kInk ? Colors.white : dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? activeText : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Responsive Multi-Column Card Grid
// ─────────────────────────────────────────────────────────────
class _ResponsiveCourseGrid extends StatelessWidget {
  const _ResponsiveCourseGrid({required this.items});
  final List<_CourseAttendanceItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w >= 980 ? 3 : (w >= 620 ? 2 : 1);

        if (cols == 1) {
          return Column(
            children: items
                .map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child:
                          _CourseAttendanceCard(item: item, fillHeight: false),
                    ))
                .toList(),
          );
        }

        final rows = <Widget>[];
        for (int i = 0; i < items.length; i += cols) {
          final rowChildren = <Widget>[];
          for (int c = 0; c < cols; c++) {
            final idx = i + c;
            if (idx < items.length) {
              rowChildren.add(Expanded(
                  child: _CourseAttendanceCard(
                      item: items[idx], fillHeight: true)));
            } else {
              rowChildren.add(const Expanded(child: SizedBox()));
            }
            if (c < cols - 1) {
              rowChildren.add(const SizedBox(width: 14));
            }
          }
          rows.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: rowChildren,
                ),
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Per-course attendance card
// ─────────────────────────────────────────────────────────────
class _CourseAttendanceCard extends StatelessWidget {
  const _CourseAttendanceCard({required this.item, this.fillHeight = false});
  final _CourseAttendanceItem item;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final style = item.style;
    final pct = item.pct;
    final total = item.total;
    final attended = item.attended;

    String hint = 'No lectures taken by professor yet';
    if (pct != null && total > 0) {
      if (pct < 75) {
        final needed = ((0.75 * total - attended) / 0.25).ceil().clamp(0, 999);
        hint = 'Need $needed more class${needed == 1 ? '' : 'es'} for 75%';
      } else {
        final canMiss =
            ((attended - 0.75 * total) / 0.75).floor().clamp(0, 999);
        hint = 'Can miss $canMiss more class${canMiss == 1 ? '' : 'es'} safely';
      }
    }

    final pctText = pct != null ? '${pct.toStringAsFixed(1)}%' : '—';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: pct != null ? style.border : _kLine,
          width: pct != null ? 1.3 : 1,
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x090F172A), blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Builder(
          builder: (context) {
            final body = Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Header row: Code + Type + Status Pill + Title + Professor
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _kInk,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.code,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _kPageBg,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    item.type,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _kMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: style.bg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: style.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(style.icon,
                                      size: 11.5, color: style.text),
                                  const SizedBox(width: 4),
                                  Text(
                                    style.label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: style.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 11),

                      // Course Title & Professor
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _kInk,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded,
                              size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.prof,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontSize: 12, color: _kMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Highlighted Attendance Stats Box + Guidance Footer
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 11),
                        decoration: BoxDecoration(
                          color: style.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: style.border),
                        ),
                        child: Row(
                          children: [
                            _CourseStatCell(
                              label: 'Classes Taken',
                              value: '$total',
                              valueColor: _kInk,
                            ),
                            Container(
                                width: 1, height: 30, color: style.border),
                            _CourseStatCell(
                              label: 'Attended',
                              value: '$attended',
                              valueColor: _kInk,
                            ),
                            Container(
                                width: 1, height: 30, color: style.border),
                            _CourseStatCell(
                              label: 'Percentage',
                              value: pctText,
                              valueColor: style.text,
                              highlight: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            total == 0
                                ? Icons.event_busy_outlined
                                : ((pct ?? 0) < 75
                                    ? Icons.arrow_upward_rounded
                                    : Icons.shield_outlined),
                            size: 12.5,
                            color: total == 0 ? _kMuted : style.text,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              hint,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: total == 0 ? _kMuted : style.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Container(height: 5, color: style.accent),
                if (fillHeight) Expanded(child: body) else body,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CourseStatCell extends StatelessWidget {
  const _CourseStatCell({
    required this.label,
    required this.value,
    required this.valueColor,
    this.highlight = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: highlight ? 18 : 16,
              fontWeight: FontWeight.w900,
              color: valueColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _kMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Empty & Filtered Empty States
// ─────────────────────────────────────────────────────────────
class _EmptyCoursesCard extends StatelessWidget {
  const _EmptyCoursesCard({required this.branch, required this.semester});
  final String branch;
  final String semester;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kLine),
      ),
      child: Column(
        children: [
          const Icon(Icons.school_outlined, size: 46, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 12),
          const Text(
            'No Courses Found',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: _kInk),
          ),
          const SizedBox(height: 6),
          Text(
            'No courses are registered for $branch – $semester.\nAsk the moderator to import the timetable.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: _kMuted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _NoMatchingCoursesCard extends StatelessWidget {
  const _NoMatchingCoursesCard({required this.onResetFilters});
  final VoidCallback onResetFilters;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kLine),
      ),
      child: Column(
        children: [
          const Icon(Icons.filter_list_off_rounded,
              size: 42, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 10),
          const Text(
            'No matching courses',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: _kInk),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try clearing the search query or selecting All courses.',
            style: TextStyle(fontSize: 12.5, color: _kMuted),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onResetFilters,
            style: OutlinedButton.styleFrom(
              foregroundColor: _kInk,
              side: const BorderSide(color: _kLine),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Show All Courses',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
