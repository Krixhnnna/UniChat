import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class DatabaseService {
  final CollectionReference users = FirebaseFirestore.instance.collection('users');

  Future<void> createOrUpdateUser(UserModel user) async {
    await users.doc(user.id).set(user.toMap(), SetOptions(merge: true));
  }

  Future<UserModel?> getUser(String id) async {
    final doc = await users.doc(id).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  Stream<UserModel?> userStream(String id) {
    return users.doc(id).snapshots().map((doc) {
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    });
  }

  Future<List<UserModel>> getAllUsersExcept(String excludeId) async {
    final query = await users.where('id', isNotEqualTo: excludeId).get();
    return query.docs.map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }
} 