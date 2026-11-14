import 'package:flutter/material.dart';
import '../providers/portal_provider.dart';

/// The moderator's spreadsheet controls, operating on server course IDs.
class ServerCourseTable extends StatefulWidget {
  final PortalProvider portal;
  final void Function(Map<String, dynamic>) onOpen;
  final void Function(Map<String, dynamic>) onEdit;
  final bool fullscreen;
  const ServerCourseTable(
      {super.key,
      required this.portal,
      required this.onOpen,
      required this.onEdit,
      this.fullscreen = false});
  @override
  State<ServerCourseTable> createState() => _ServerCourseTableState();
}

class _ServerCourseTableState extends State<ServerCourseTable> {
  String branch = '', semester = '', status = '', query = '', sort = 'code';
  bool ascending = true, compact = false;
  double zoom = 1;
  final selected = <String>{};

  Future<void> bulk(bool archive) async {
    final professors = widget.portal
        .rows('users')
        .where((u) => u['role'] == 'professor' && u['active'] == true)
        .toList();
    final ids = <String>{};
    final approved = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, change) => AlertDialog(
                  title: Text(archive
                      ? 'Archive ${selected.length} courses?'
                      : 'Assign ${selected.length} courses'),
                  content: SizedBox(
                      width: 440,
                      child: SingleChildScrollView(
                          child: archive
                              ? const Text(
                                  'End active enrollments and CR permissions. Attendance history will be retained.')
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                      const Text(
                                          'Replace the selected courses’ professor assignments. Select nobody to unassign.'),
                                      ...professors.map((p) => CheckboxListTile(
                                          title: Text(p['name']),
                                          subtitle: Text(p['email']),
                                          value: ids.contains(p['id']),
                                          onChanged: (v) => change(() {
                                                if (v == true) {
                                                  ids.add(p['id']);
                                                } else {
                                                  ids.remove(p['id']);
                                                }
                                              }))),
                                    ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Confirm')),
                  ],
                )));
    if (approved != true || !mounted) return;
    try {
      await widget.portal.mutate('POST', '/courses/bulk', {
        'course_ids': selected.toList(),
        'action': archive ? 'archive' : 'assign',
        'professor_ids': ids.toList(),
      });
      if (!mounted) return;
      setState(selected.clear);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Courses updated')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget filter(String label, String value, Iterable<String> values,
      ValueChanged<String> change) {
    final choices = values.toSet().toList()..sort();
    return SizedBox(
        width: 160,
        child: DropdownButtonFormField<String>(
          key: ValueKey('$label:$value:${choices.join(",")}'),
          initialValue: choices.contains(value) ? value : '',
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            const DropdownMenuItem(value: '', child: Text('All')),
            ...choices
                .where((v) => v.isNotEmpty)
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          ],
          onChanged: (v) => setState(() => change(v ?? '')),
        ));
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.portal,
      builder: (context, _) {
        final all = widget.portal.rows('courses');
        selected.removeWhere((id) => !all.any((c) => c['id'] == id));
        final courses = all
            .where((c) =>
                (branch.isEmpty || c['branch'] == branch) &&
                (semester.isEmpty || c['semester'] == semester) &&
                (status.isEmpty ||
                    (status == 'Assigned') ==
                        (c['professor_ids'] as List).isNotEmpty) &&
                '${c['code']} ${c['name']} ${c['professor_name']} ${c['section']}'
                    .toLowerCase()
                    .contains(query))
            .toList()
          ..sort((a, b) =>
              (ascending ? 1 : -1) * '${a[sort]}'.compareTo('${b[sort]}'));
        final controls = Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              filter('Branch', branch, all.map((c) => '${c['branch']}'),
                  (v) => branch = v),
              filter('Semester', semester, all.map((c) => '${c['semester']}'),
                  (v) => semester = v),
              filter('Assignment', status, ['Assigned', 'Unassigned'],
                  (v) => status = v),
              SizedBox(
                  width: 240,
                  child: TextField(
                      decoration:
                          const InputDecoration(labelText: 'Search table'),
                      onChanged: (v) =>
                          setState(() => query = v.toLowerCase()))),
              FilterChip(
                  label: const Text('Compact'),
                  selected: compact,
                  onSelected: (v) => setState(() => compact = v)),
              IconButton(
                  tooltip: 'Zoom out',
                  onPressed:
                      zoom <= .85 ? null : () => setState(() => zoom -= .15),
                  icon: const Icon(Icons.zoom_out)),
              Text('${(zoom * 100).round()}%'),
              IconButton(
                  tooltip: 'Zoom in',
                  onPressed:
                      zoom >= 1.3 ? null : () => setState(() => zoom += .15),
                  icon: const Icon(Icons.zoom_in)),
              if (!widget.fullscreen)
                IconButton(
                    tooltip: 'Fullscreen table',
                    icon: const Icon(Icons.fullscreen),
                    onPressed: () => showDialog(
                        context: context,
                        builder: (ctx) => Dialog.fullscreen(
                            child: Scaffold(
                                appBar: AppBar(
                                    title: const Text('Course table'),
                                    leading: IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: () => Navigator.pop(ctx))),
                                body: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: ServerCourseTable(
                                        portal: widget.portal,
                                        onOpen: (c) {
                                          Navigator.pop(ctx);
                                          widget.onOpen(c);
                                        },
                                        onEdit: (c) {
                                          Navigator.pop(ctx);
                                          widget.onEdit(c);
                                        },
                                        fullscreen: true)))))),
              if (selected.isNotEmpty) ...[
                Text('${selected.length} selected'),
                FilledButton(
                    onPressed: widget.portal.saving ? null : () => bulk(false),
                    child: const Text('Bulk assign')),
                OutlinedButton(
                    onPressed: widget.portal.saving ? null : () => bulk(true),
                    child: const Text('Bulk archive')),
                TextButton(
                    onPressed: () => setState(selected.clear),
                    child: const Text('Clear selection')),
              ],
            ]);
        const keys = [
          'code',
          'name',
          'branch',
          'semester',
          'section',
          'professor_name'
        ];
        const labels = [
          'Code',
          'Course',
          'Branch',
          'Semester',
          'Section',
          'Professors'
        ];
        final table = SingleChildScrollView(
            child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  sortColumnIndex: keys.indexOf(sort),
                  sortAscending: ascending,
                  dataTextStyle: TextStyle(
                      fontSize: 14 * zoom,
                      color: Theme.of(context).colorScheme.onSurface),
                  headingTextStyle: TextStyle(
                      fontSize: 14 * zoom,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface),
                  dataRowMinHeight: (compact ? 44 : 60) * zoom,
                  dataRowMaxHeight: (compact ? 60 : 88) * zoom,
                  columnSpacing: 24 * zoom,
                  columns: [
                    for (var i = 0; i < keys.length; i++)
                      DataColumn(
                          label: Text(labels[i]),
                          onSort: (_, asc) => setState(() {
                                sort = keys[i];
                                ascending = asc;
                              })),
                    const DataColumn(label: Text('Actions'))
                  ],
                  rows: courses
                      .map((c) => DataRow(
                            selected: selected.contains(c['id']),
                            onSelectChanged: (v) => setState(() {
                              if (v == true) {
                                selected.add(c['id']);
                              } else {
                                selected.remove(c['id']);
                              }
                            }),
                            cells: [
                              for (final key in keys)
                                DataCell(ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 240),
                                    child: Text('${c[key]}',
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis))),
                              DataCell(Row(children: [
                                IconButton(
                                    tooltip: 'Edit course',
                                    onPressed: () => widget.onEdit(c),
                                    icon: const Icon(Icons.edit)),
                                IconButton(
                                    tooltip: 'Open attendance',
                                    onPressed: () => widget.onOpen(c),
                                    icon: const Icon(Icons.fact_check))
                              ]))
                            ],
                          ))
                      .toList(),
                )));
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          controls,
          const SizedBox(height: 12),
          Text('${courses.length} courses'),
          if (widget.fullscreen)
            Expanded(child: table)
          else
            SizedBox(height: 400, child: table),
        ]);
      });
}
