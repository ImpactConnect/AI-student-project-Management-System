import 'package:cloud_firestore/cloud_firestore.dart';

enum ProjectStatus { pending, approved, needsRevision, rejected }

class Project {
  final String id;
  final String title;
  final String objectives;
  final String studentName;
  final String department;
  final String year;
  final String supervisorId;
  final ProjectStatus status;
  final DateTime createdAt;
  final DateTime? dateUploaded; // [NEW] Explicit upload date
  final String? documentUrl;
  final double? similarityScore;
  final Map<String, dynamic>? extractedData; // Form auto-fill data
  final Map<String, dynamic>? aiAnalysis; // [RESTRUCTURED] Cached AI analysis

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
    this.dateUploaded,
    this.documentUrl,
    this.similarityScore,
    this.extractedData,
    this.aiAnalysis,
  });

  /// Convenience getters for AI analysis fields
  /// Convenience getters for AI analysis fields
  String? get problemStatement => aiAnalysis?['problemStatement'];
  List<String>? get aiObjectives =>
      (aiAnalysis?['objectives'] as List<dynamic>?)?.cast<String>();
  String? get methodology => aiAnalysis?['methodology'];
  String? get implementation => aiAnalysis?['implementation'];
  String? get results => aiAnalysis?['results'];
  List<String>? get areasForImprovement =>
      (aiAnalysis?['areasForImprovement'] as List<dynamic>?)?.cast<String>();
  List<String>? get outcomes => (aiAnalysis?['outcomes'] as List<dynamic>?)
      ?.cast<
        String
      >(); // Keep for backward compat if needed, or remove? Prompt changed 'outcomes' to 'results' (String)
  List<String>? get recommendations =>
      (aiAnalysis?['recommendations'] as List<dynamic>?)?.cast<String>();
  bool get hasAiAnalysis => aiAnalysis != null && aiAnalysis!.isNotEmpty;

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
      dateUploaded: (map['dateUploaded'] as Timestamp?)?.toDate(),
      documentUrl: map['documentUrl'],
      similarityScore: map['similarityScore']?.toDouble(),
      extractedData: map['extractedData'],
      aiAnalysis: map['aiAnalysis'],
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
      'dateUploaded': dateUploaded != null
          ? Timestamp.fromDate(dateUploaded!)
          : null,
      'documentUrl': documentUrl,
      'similarityScore': similarityScore,
      'extractedData': extractedData,
      'aiAnalysis': aiAnalysis,
    };
  }

  /// For JSON summary file (compact format)
  Map<String, dynamic> toSummaryJson() {
    return {
      'id': id,
      'title': title,
      'objectives': objectives,
      'studentName': studentName,
      'department': department,
      'year': year,
    };
  }

  /// Create a copy with updated fields
  Project copyWith({
    String? id,
    String? title,
    String? objectives,
    String? studentName,
    String? department,
    String? year,
    String? supervisorId,
    ProjectStatus? status,
    DateTime? createdAt,
    DateTime? dateUploaded,
    String? documentUrl,
    double? similarityScore,
    Map<String, dynamic>? extractedData,
    Map<String, dynamic>? aiAnalysis,
  }) {
    return Project(
      id: id ?? this.id,
      title: title ?? this.title,
      objectives: objectives ?? this.objectives,
      studentName: studentName ?? this.studentName,
      department: department ?? this.department,
      year: year ?? this.year,
      supervisorId: supervisorId ?? this.supervisorId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      dateUploaded: dateUploaded ?? this.dateUploaded,
      documentUrl: documentUrl ?? this.documentUrl,
      similarityScore: similarityScore ?? this.similarityScore,
      extractedData: extractedData ?? this.extractedData,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
    );
  }
}
