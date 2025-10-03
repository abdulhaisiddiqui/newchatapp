import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StoryService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;

  Future<void> uploadStory({File? file, String? text, required String type}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      String? downloadUrl;

      if (file != null) {
        final ref = _storage
            .ref()
            .child('stories')
            .child(user.uid)
            .child('${DateTime.now().millisecondsSinceEpoch}');
        await ref.putFile(file);
        downloadUrl = await ref.getDownloadURL();
      }

      // ✅ users collection se username lo (uid field ke base pe)
      final userQuery = await _firestore
          .collection("users")
          .where("uid", isEqualTo: user.uid)
          .limit(1)
          .get();

      String username = "Unknown";
      if (userQuery.docs.isNotEmpty) {
        username = userQuery.docs.first["username"] ?? "Unknown";
      }

      // parent doc me user info update karo
      await _firestore.collection('stories').doc(user.uid).set({
        "userId": user.uid,
        "username": username,
        "updatedAt": FieldValue.serverTimestamp(),
      });

      // subcollection me story add karo
      await _firestore
          .collection('stories')
          .doc(user.uid)
          .collection("userStories")
          .add({
        "type": type,
        "url": downloadUrl ?? "",
        "text": text ?? "",
        "timestamp": FieldValue.serverTimestamp(),
        "expiresAt": DateTime.now().add(const Duration(hours: 24)),
      });
    } catch (e) {
      print("Error uploading story: $e");
    }
  }

  Stream<List<Map<String, dynamic>>> getVisibleStories(String currentUserId) async* {
    final chatRooms = await _firestore
        .collection("chat_rooms")
        .where("members", arrayContains: currentUserId)
        .get();

    List<String> chatUserIds = [];
    for (var room in chatRooms.docs) {
      final members = List<String>.from(room["members"] ?? []);
      chatUserIds.addAll(members.where((id) => id != currentUserId));
    }

    if (chatUserIds.isEmpty) {
      yield [];
      return;
    }

    yield* _firestore.collection("stories").snapshots().asyncMap((snapshot) async {
      List<Map<String, dynamic>> stories = [];

      for (var doc in snapshot.docs) {
        if (!chatUserIds.contains(doc.id) && doc.id != currentUserId) continue;

        final userData = doc.data();
        final userStoriesSnap = await doc.reference
            .collection("userStories")
            .orderBy("timestamp", descending: true)
            .get();

        if (userStoriesSnap.docs.isNotEmpty) {
          stories.add({
            "userId": doc.id,
            "username": userData["username"] ?? "Unknown",
            "stories": userStoriesSnap.docs.map((d) => d.data()).toList(),
          });
        }
      }
      return stories;
    });
  }
}
