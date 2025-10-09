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
    String? caption,
    String privacy = 'public', // default privacy
    required String type,
  }) async {
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

      final userDoc = await _firestore.collection("users").doc(user.uid).get();
      final username = userDoc.data()?["username"] ?? "Unknown";

      await _firestore.collection('stories').doc(user.uid).set({
        "userId": user.uid,
        "username": username,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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
        "caption": caption ?? "",
        "privacy": privacy,
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
      'updatedAt': FieldValue.serverTimestamp(), // 👈 Trigger Firestore snapshot
    });

    // 👇 Parent document update bhi trigger karega
    await _firestore.collection('stories').doc(storyDocId).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }


  /// 🔄 Get visible stories from user's chats
  /// 🔄 Get visible stories from user's chats (reactive + safe)
  Stream<List<Map<String, dynamic>>> getVisibleStories(String currentUserId) async* {
    // 🔹 Chat rooms ka live stream
    final chatRoomsStream = _firestore
        .collection("chat_rooms")
        .where("members", arrayContains: currentUserId)
        .snapshots();

    await for (final chatSnapshot in chatRoomsStream) {
      final chatUserIds = <String>{};

      for (var room in chatSnapshot.docs) {
        final members = List<String>.from(room["members"] ?? []);
        chatUserIds.addAll(members.where((id) => id != currentUserId));
      }

      if (chatUserIds.isEmpty) {
        yield [];
        continue;
      }

      // 🔹 Stories collection ka live stream
      yield* _firestore.collection("stories").snapshots().asyncMap((storiesSnap) async {
        List<Map<String, dynamic>> stories = [];

        for (var doc in storiesSnap.docs) {
          if (!chatUserIds.contains(doc.id) && doc.id != currentUserId) continue;

          final userData = doc.data();

          QuerySnapshot<Map<String, dynamic>>? userStoriesSnap;
          try {
            userStoriesSnap = await doc.reference
                .collection("userStories")
                .orderBy("timestamp", descending: true)
                .get();
          } catch (e) {
            userStoriesSnap = await doc.reference.collection("userStories").get();
          }

          final userStories = userStoriesSnap.docs.map((d) {
            final data = d.data();
            data['storyId'] = d.id;
            return data;
          }).toList();

          if (userStories.isEmpty) continue;

          final bool allSeen = userStories.every((story) {
            final viewedBy = List<String>.from(story['viewedBy'] ?? []);
            return viewedBy.contains(currentUserId);
          });

          stories.add({
            "userId": doc.id,
            "username": userData["username"] ?? "Unknown",
            "stories": userStories,
            "isSeen": allSeen,
          });
        }

        return stories;
      });
    }
  }


}
