
import 'package:cloud_firestore/cloud_firestore.dart';

enum ProjectStatus {
  pending,
  approved,
  needsRevision,
  rejected,
}

class Project {
  final String id;
  final String title;
  final String objectives;
  final String studentName;
  final String department;
  final String year; // [NEW]
  final String supervisorId;
  final ProjectStatus status;
  final DateTime createdAt;
  final String? documentUrl;
  final double? similarityScore;
  final List<String>? achievements; // [NEW]
  final List<String>? recommendations; // [NEW]
  final Map<String, dynamic>? aiFeedback;
  final Map<String, dynamic>? extractedData; // [NEW] Structured fields for AI

  Project({
    required this.id,
    required this.title,
    required this.objectives,
    required this.studentName,
    required this.department,
    required this.year,
    required this.supervisorId,
    required this.status,
    required this.createdAt,
    this.documentUrl,
    this.similarityScore,
    this.achievements,
    this.recommendations,
    this.aiFeedback,
    this.extractedData,
  });

  factory Project.fromMap(Map<String, dynamic> map, String id) {
    return Project(
      id: id,
      title: map['title'] ?? '',
      objectives: map['objectives'] ?? '',
      studentName: map['studentName'] ?? '',
      department: map['department'] ?? '',
      year: map['year'] ?? DateTime.now().year.toString(),
      supervisorId: map['supervisorId'] ?? '',
      status: ProjectStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ProjectStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      documentUrl: map['documentUrl'],
      similarityScore: map['similarityScore']?.toDouble(),
      achievements: (map['achievements'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      recommendations: (map['recommendations'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      aiFeedback: map['aiFeedback'],
      extractedData: map['extractedData'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'objectives': objectives,
      'studentName': studentName,
      'department': department,
      'year': year,
      'supervisorId': supervisorId,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'documentUrl': documentUrl,
      'similarityScore': similarityScore,
      'achievements': achievements,
      'recommendations': recommendations,
      'recommendations': recommendations,
      'aiFeedback': aiFeedback,
      'extractedData': extractedData,
    };
  }
}
