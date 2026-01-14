
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

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter Sidebar
              if (_showFilters)
                Container(
                  width: 250,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
                  ),
                  child: _buildFilters(projects),
                ),
              
              // Data Grid
              Expanded(
                child: SfDataGrid(
                  source: dataSource,
                  columnWidthMode: ColumnWidthMode.fill,
                  selectionMode: SelectionMode.single,
                  allowSorting: true,
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
                        columnName: 'title',
                        label: _buildHeader('Title'),
                        width: 250),
                    GridColumn(
                        columnName: 'student',
                        label: _buildHeader('Student')),
                    GridColumn(
                        columnName: 'year',
                        label: _buildHeader('Year'),
                        width: 80),
                    GridColumn(
                        columnName: 'department',
                        label: _buildHeader('Department')),
                    GridColumn(
                        columnName: 'status',
                        label: _buildHeader('Status')),
                    GridColumn(
                        columnName: 'date',
                        label: _buildHeader('Date')),
                  ],
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
      padding: const EdgeInsets.all(16.0),
      alignment: Alignment.centerLeft,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildFilters(List<Project> projects) {
    // Extract unique values
    final years = projects.map((p) => p.year).toSet().toList()..sort();
    final depts = projects.map((p) => p.department).toSet().toList()..sort();
    final statuses = ProjectStatus.values.map((e) => e.name).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedYear = null;
                    _selectedDepartment = null;
                    _selectedStatus = null;
                  });
                }, 
                child: const Text('Clear'),
              ),
            ],
          ),
          const Divider(),
          _buildDropdown('Year', years, _selectedYear, (v) => setState(() => _selectedYear = v)),
          const SizedBox(height: 16),
          _buildDropdown('Department', depts, _selectedDepartment, (v) => setState(() => _selectedDepartment = v)),
          const SizedBox(height: 16),
          _buildDropdown('Status', statuses, _selectedStatus, (v) => setState(() => _selectedStatus = v)),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: projects.isEmpty ? null : () async {
              final csv = CsvExporter.generateProjectCsv(projects);
              final path = await CsvExporter.saveAndShow(csv, 'projects_export.csv');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(path != null ? 'Exported to $path' : 'Export failed'))
                );
              }
            },
            icon: const Icon(Icons.download),
            label: const Text('Export to CSV'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 45),
            ),
          ),
        ],
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
        .map<DataGridRow>((e) => DataGridRow(cells: [
              DataGridCell<String>(columnName: 'title', value: e.title),
              DataGridCell<String>(columnName: 'student', value: e.studentName),
              DataGridCell<String>(columnName: 'year', value: e.year),
              DataGridCell<String>(columnName: 'department', value: e.department),
              DataGridCell<String>(columnName: 'status', value: e.status.name),
              DataGridCell<String>(columnName: 'date', value: DateFormat.yMMMd().format(e.createdAt)),
            ]))
        .toList();
  }

  List<DataGridRow> _projects = [];

  @override
  List<DataGridRow> get rows => _projects;

  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
    return DataGridRowAdapter(
        cells: row.getCells().map<Widget>((dataGridCell) {
      if (dataGridCell.columnName == 'status') {
         return Container(
           alignment: Alignment.centerLeft,
           padding: const EdgeInsets.symmetric(horizontal: 16.0),
           child: Chip(
             label: Text(dataGridCell.value.toString().toUpperCase(), style: const TextStyle(fontSize: 10)),
             backgroundColor: _getStatusColor(dataGridCell.value.toString()),
           ),
         );
      }
      return Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(16.0),
        child: Text(dataGridCell.value.toString()),
      );
    }).toList());
  }
  
  Color _getStatusColor(String status) {
    if (status == 'approved') return Colors.green.shade200;
    if (status == 'rejected') return Colors.red.shade200;
    if (status == 'needsRevision') return Colors.orange.shade200;
    return Colors.grey.shade200;
  }
}
