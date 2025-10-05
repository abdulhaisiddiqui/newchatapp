import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StoryService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;

  /// 📤 Upload Story (image or text)
  Future<void> uploadStory({
    File? file,
    String? text,
    required String type,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      String? downloadUrl;

      // 🔹 1. Upload image if provided
      if (file != null) {
        final ref = _storage
            .ref()
            .child('stories')
            .child(user.uid)
            .child('${DateTime.now().millisecondsSinceEpoch}');
        await ref.putFile(file);
        downloadUrl = await ref.getDownloadURL();
      }

      // 🔹 2. Get username from users collection
      final userDoc = await _firestore.collection("users").doc(user.uid).get();
      final username = userDoc.data()?["username"] ?? "Unknown";

      // 🔹 3. Update parent document with basic info
      await _firestore.collection('stories').doc(user.uid).set({
        "userId": user.uid,
        "username": username,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 🔹 4. Add substory
      final newStoryRef = _firestore
          .collection('stories')
          .doc(user.uid)
          .collection("userStories")
          .doc();

      await newStoryRef.set({
        "storyId": newStoryRef.id,
        "type": type,
        "url": downloadUrl ?? "",
        "text": text ?? "",
        "timestamp": FieldValue.serverTimestamp(),
        "expiresAt": DateTime.now().add(const Duration(hours: 24)),
        "viewedBy": [],
      });
    } catch (e) {
      print("⚠️ Error uploading story: $e");
    }
  }

  /// 👁️ Mark a story as viewed
  Future<void> markStoryAsViewed(String storyDocId, String storyId) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    final storyRef = _firestore
        .collection('stories')
        .doc(storyDocId)
        .collection('userStories')
        .doc(storyId);

    await storyRef.update({
      'viewedBy': FieldValue.arrayUnion([currentUid]),
    });
  }

  /// 🔄 Get visible stories from user's chats
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

        final storyList = userStoriesSnap.docs.map((d) {
          final data = d.data();
          return {
            "storyId": data["storyId"] ?? d.id,
            "type": data["type"] ?? "text",
            "url": data["url"] ?? "",
            "text": data["text"] ?? "",
            "viewedBy": List<String>.from(data["viewedBy"] ?? []),
            "timestamp": data["timestamp"],
          };
        }).toList();

        if (storyList.isNotEmpty) {
          if (userStoriesSnap.docs.isNotEmpty) {
            final userStories = userStoriesSnap.docs.map((d) {
              final data = d.data();
              data['storyId'] = d.id; // 👈 story id save for marking viewed later
              return data;
            }).toList();

            // 👇 Check if current user has seen ALL stories
            final bool allSeen = userStories.every((story) {
              final viewedBy = List<String>.from(story['viewedBy'] ?? []);
              return viewedBy.contains(currentUserId);
            });

            stories.add({
              "userId": doc.id,
              "username": userData["username"] ?? "Unknown",
              "stories": userStories,
              "isSeen": allSeen, // 👈 add this
            });
          }

        }
      }
      return stories;
    });
  }
}
