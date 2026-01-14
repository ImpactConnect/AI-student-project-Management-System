
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:student_project_management/src/features/settings/domain/ai_config.dart';

class AISettingsRepository {
  final FirebaseFirestore _firestore;

  AISettingsRepository(this._firestore);

  Stream<AIConfig> watchAIConfig() {
    return _firestore
        .collection('settings')
        .doc('ai_config')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return AIConfig.empty();
      }
      return AIConfig.fromMap(snapshot.data()!);
    });
  }

  Future<void> updateAIConfig(AIConfig config) async {
    await _firestore
        .collection('settings')
        .doc('ai_config')
        .set(config.toMap());
  }
}

final aiSettingsRepositoryProvider = Provider<AISettingsRepository>((ref) {
  return AISettingsRepository(FirebaseFirestore.instance);
});

final aiConfigStreamProvider = StreamProvider<AIConfig>((ref) {
  return ref.watch(aiSettingsRepositoryProvider).watchAIConfig();
});
