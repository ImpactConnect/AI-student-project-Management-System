
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:student_project_management/src/features/ai_assistant/domain/proposal_history.dart';
import 'package:student_project_management/src/features/projects/data/project_repository.dart';

abstract class ProposalHistoryRepository {
  Stream<List<ProposalHistory>> watchHistory(String supervisorId);
  Future<void> addHistory(ProposalHistory history);
  Future<void> deleteHistory(String id);
}

class FirestoreProposalHistoryRepository implements ProposalHistoryRepository {
  final FirebaseFirestore _firestore;

  FirestoreProposalHistoryRepository(this._firestore);

  @override
  Stream<List<ProposalHistory>> watchHistory(String supervisorId) {
    return _firestore
        .collection('proposal_history')
        .where('supervisorId', isEqualTo: supervisorId)
        .limit(20) // Keep last 20 records
        .snapshots()
        .map((snapshot) {
      final history = snapshot.docs
          .map((doc) => ProposalHistory.fromMap(doc.data(), doc.id))
          .toList();
      // Sort in memory instead of Firestore to avoid composite index
      history.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return history;
    });
  }

  @override
  Future<void> addHistory(ProposalHistory history) async {
    await _firestore.collection('proposal_history').add(history.toMap());
  }

  @override
  Future<void> deleteHistory(String id) async {
    await _firestore.collection('proposal_history').doc(id).delete();
  }
}

final proposalHistoryRepositoryProvider = Provider<ProposalHistoryRepository>((ref) {
  return FirestoreProposalHistoryRepository(ref.watch(firestoreProvider));
});

final proposalHistoryStreamProvider = StreamProvider.family<List<ProposalHistory>, String>((ref, supervisorId) {
  return ref.watch(proposalHistoryRepositoryProvider).watchHistory(supervisorId);
});
