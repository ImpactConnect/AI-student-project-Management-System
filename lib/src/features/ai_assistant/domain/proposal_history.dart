
import 'package:cloud_firestore/cloud_firestore.dart';

class ProposalHistory {
  final String id;
  final String title;
  final String objectives;
  final String supervisorId;
  final DateTime createdAt;
  final Map<String, dynamic> analysis; // Full AI analysis result

  ProposalHistory({
    required this.id,
    required this.title,
    required this.objectives,
    required this.supervisorId,
    required this.createdAt,
    required this.analysis,
  });

  factory ProposalHistory.fromMap(Map<String, dynamic> map, String id) {
    return ProposalHistory(
      id: id,
      title: map['title'] ?? '',
      objectives: map['objectives'] ?? '',
      supervisorId: map['supervisorId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      analysis: map['analysis'] ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'objectives': objectives,
      'supervisorId': supervisorId,
      'createdAt': Timestamp.fromDate(createdAt),
      'analysis': analysis,
    };
  }
}
