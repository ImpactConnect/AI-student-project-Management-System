
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:student_project_management/src/features/projects/domain/project.dart';

class CsvExporter {
  static String generateProjectCsv(List<Project> projects) {
    StringBuffer sb = StringBuffer();
    // Header
    sb.writeln('ID,Title,Student,Department,Year,Status,Date');
    
    for (var p in projects) {
      sb.writeln(
        '${_escape(p.id)},'
        '${_escape(p.title)},'
        '${_escape(p.studentName)},'
        '${_escape(p.department)},'
        '${_escape(p.year)},'
        '${_escape(p.status.name)},'
        '${_escape(p.createdAt.toIso8601String())}'
      );
    }
    return sb.toString();
  }

  static String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static Future<String?> saveAndShow(String csvContent, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvContent);
      return file.path;
    } catch (e) {
      return null;
    }
  }
}
