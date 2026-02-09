
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:student_project_management/src/features/projects/data/project_repository.dart';
import 'package:student_project_management/src/features/projects/domain/project.dart';
import 'package:student_project_management/src/utils/csv_exporter.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class ProjectListScreen extends ConsumerStatefulWidget {
  const ProjectListScreen({super.key});

  @override
  ConsumerState<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends ConsumerState<ProjectListScreen> {
  // Filter States
  String? _selectedYear;
  String? _selectedStatus;
  String? _selectedDepartment;
  bool _showFilters = true;

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
            onPressed: () => setState(() => _showFilters = !_showFilters),
            tooltip: 'Toggle Filters',
          ),
          IconButton(onPressed: () => ref.refresh(projectsStreamProvider), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: projectsAsync.when(
        data: (projects) {
          // Apply Filters
          final filteredProjects = projects.where((p) {
            if (_selectedYear != null && p.year != _selectedYear) return false;
            if (_selectedStatus != null && p.status.name != _selectedStatus) return false;
            if (_selectedDepartment != null && p.department != _selectedDepartment) return false;
            return true;
          }).toList();

          final dataSource = ProjectDataSource(
            projects: filteredProjects, 
            context: context,
            onTap: (projectId) => context.go('/projects/$projectId'),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter Bar at Top
              if (_showFilters)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                  ),
                  child: Row(
                    children: [
                      const Text('Filters:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDropdown(
                          'Year',
                          ['All', ...projects.map((p) => p.year).toSet().toList()],
                          _selectedYear,
                          (val) => setState(() => _selectedYear = val == 'All' ? null : val),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDropdown(
                          'Department',
                          ['All', ...projects.map((p) => p.department).toSet().toList()],
                          _selectedDepartment,
                          (val) => setState(() => _selectedDepartment = val == 'All' ? null : val),
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedYear = null;
                            _selectedDepartment = null;
                            _selectedStatus = null;
                          });
                        },
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          final csv = CsvExporter.generateProjectCsv(filteredProjects);
                          final path = await CsvExporter.saveAndShow(csv, 'projects_export.csv');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(path != null ? 'Exported to $path' : 'Export failed')),
                            );
                          }
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Export to CSV'),
                      ),
                    ],
                  ),
                ),
              
              // Data Grid with modern styling
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SfDataGrid(
                      source: dataSource,
                      columnWidthMode: ColumnWidthMode.fill, // Fill available width
                      selectionMode: SelectionMode.single,
                      allowSorting: true,
                      gridLinesVisibility: GridLinesVisibility.horizontal,
                      headerGridLinesVisibility: GridLinesVisibility.none,
                      rowHeight: 60,
                      headerRowHeight: 56,
                      isScrollbarAlwaysShown: true, // Always show scrollbar
                      verticalScrollPhysics: const AlwaysScrollableScrollPhysics(),
                      onCellTap: (details) {
                         if (details.rowColumnIndex.rowIndex == 0) return; // Header
                         final rowIndex = details.rowColumnIndex.rowIndex - 1;
                         if (rowIndex >= 0 && rowIndex < filteredProjects.length) {
                           final project = filteredProjects[rowIndex];
                           context.go('/projects/${project.id}');
                         }
                      },
                      columns: <GridColumn>[
                         GridColumn(
                            columnName: 'sn',
                            label: _buildHeader('S/N'),
                            width: 70),
                         GridColumn(
                            columnName: 'title',
                            label: _buildHeader('Title'),
                            columnWidthMode: ColumnWidthMode.fill), // Takes remaining space, allows wrapping
                        GridColumn(
                            columnName: 'student',
                            label: _buildHeader('Student'),
                            width: 180),
                        GridColumn(
                            columnName: 'year',
                            label: _buildHeader('Year'),
                            width: 100),
                        GridColumn(
                            columnName: 'department',
                            label: _buildHeader('Department'),
                            width: 180),
                        GridColumn(
                            columnName: 'date',
                            label: _buildHeader('Date'),
                            width: 140),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.go('/projects/new');
        },
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
      ),
    );
  }

  Widget _buildHeader(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      ),
      child: Text(
        text, 
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 0.5,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? currentValue, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      value: currentValue,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }
}

class ProjectDataSource extends DataGridSource {
  final BuildContext context;
  final Function(String) onTap;
  
  ProjectDataSource({required List<Project> projects, required this.context, required this.onTap}) {
    _projects = projects
        .asMap()
        .entries
        .map<DataGridRow>((entry) => DataGridRow(cells: [
              DataGridCell<int>(columnName: 'sn', value: entry.key + 1), // Serial number
              DataGridCell<String>(columnName: 'title', value: entry.value.title),
              DataGridCell<String>(columnName: 'student', value: entry.value.studentName),
              DataGridCell<String>(columnName: 'year', value: entry.value.year),
              DataGridCell<String>(columnName: 'department', value: entry.value.department),
              DataGridCell<String>(columnName: 'date', value: DateFormat.yMMMd().format(entry.value.createdAt)),
            ]))
        .toList();
  }

  List<DataGridRow> _projects = [];

  @override
  List<DataGridRow> get rows => _projects;

  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
    final rowIndex = _projects.indexOf(row);
    final isEven = rowIndex % 2 == 0;
    
    return DataGridRowAdapter(
        color: isEven 
            ? Colors.transparent 
            : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
        cells: row.getCells().map<Widget>((dataGridCell) {
      // S/N column - centered
      if (dataGridCell.columnName == 'sn') {
        return Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            dataGridCell.value.toString(),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        );
      }
      // Special handling for title column - allow text wrapping and bold
      if (dataGridCell.columnName == 'title') {
        return Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Text(
            dataGridCell.value.toString(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        );
      }
      
      return Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Text(
          dataGridCell.value.toString(),
          style: const TextStyle(fontSize: 13),
        ),
      );
    }).toList());
  }
}
