import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:student_project_management/src/features/projects/domain/project.dart';

abstract class ProjectRepository {
  Stream<List<Project>> watchProjects();
  Future<void> addProject(Project project);
  Future<void> updateProject(Project project);
  Future<void> deleteProject(String projectId);
  Future<Project?> getProject(String projectId);
  Future<List<Project>> getProjects();
  Future<List<Map<String, dynamic>>>
  getProjectsSummary(); // For duplicate checking
}

class FirestoreProjectRepository implements ProjectRepository {
  final FirebaseFirestore _firestore;

  FirestoreProjectRepository(this._firestore);

  @override
  Stream<List<Project>> watchProjects() {
    return _firestore.collection('projects').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Project.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Future<void> addProject(Project project) async {
    await _firestore.collection('projects').add(project.toMap());
    await _syncProjectsSummary();
  }

  @override
  Future<void> updateProject(Project project) async {
    await _firestore
        .collection('projects')
        .doc(project.id)
        .update(project.toMap());
    await _syncProjectsSummary();
  }

  @override
  Future<void> deleteProject(String projectId) async {
    await _firestore.collection('projects').doc(projectId).delete();
    await _syncProjectsSummary();
  }

  @override
  Future<Project?> getProject(String projectId) async {
    final doc = await _firestore.collection('projects').doc(projectId).get();
    if (doc.exists && doc.data() != null) {
      return Project.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  @override
  Future<List<Project>> getProjects() async {
    final snapshot = await _firestore.collection('projects').get();
    return snapshot.docs
        .map((doc) => Project.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Get compact summary of all projects for fast duplicate checking
  @override
  Future<List<Map<String, dynamic>>> getProjectsSummary() async {
    try {
      final doc = await _firestore
          .collection('summaries')
          .doc('all_projects')
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final projects = data['projects'] as List<dynamic>?;
        return projects?.cast<Map<String, dynamic>>() ?? [];
      }
    } catch (e) {
      print('Error getting summary, falling back to full fetch: $e');
    }

    // Fallback: generate summary from projects collection
    final projects = await getProjects();
    return projects.map((p) => p.toSummaryJson()).toList();
  }

  /// Sync the summary document with current project data
  Future<void> _syncProjectsSummary() async {
    try {
      final projects = await getProjects();
      final summaryList = projects.map((p) => p.toSummaryJson()).toList();

      await _firestore.collection('summaries').doc('all_projects').set({
        'projects': summaryList,
        'updatedAt': FieldValue.serverTimestamp(),
        'count': projects.length,
      });
    } catch (e) {
      print('Error syncing projects summary: $e');
      // Non-critical - don't throw, just log
    }
  }
}

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return FirestoreProjectRepository(ref.watch(firestoreProvider));
});

final projectsStreamProvider = StreamProvider<List<Project>>((ref) {
  final repository = ref.watch(projectRepositoryProvider);
  return repository.watchProjects();
});
