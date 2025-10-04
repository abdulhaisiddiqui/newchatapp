import 'dart:io';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:chatapp/services/error_handler.dart';

class StoryService with ErrorHandler {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;

  Future<void> uploadStory({
    required String userId,
    required String username,
    String? text,
    File? file,
    String type = "text", // text | image | video
  }) async {
    await runSafely(
      () async {
        String? downloadUrl;

        if (file != null) {
          final ref = _storage.ref().child(
            "stories/$userId/${DateTime.now().millisecondsSinceEpoch}",
          );

          await ref.putFile(file);
          downloadUrl = await ref.getDownloadURL();
        }

        await _firestore
            .collection("stories")
            .doc(userId)
            .collection("userStories")
            .add({
              "username": username,
              "userId": userId,
              "type": type,
              "text": text,
              "url": downloadUrl,
              "timestamp": FieldValue.serverTimestamp(),
              "expiresAt": DateTime.now().add(const Duration(hours: 24)),
            });
      },
      onError: (msg) {
        print("❌ Error uploading story: $msg");
        throw Exception(msg);
      },
    );

    // Show notification for new story
    await _showStoryNotification(username);
  }

  // 📬 Show local notification for new story
  Future<void> _showStoryNotification(String username) async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: 'stories',
          title: 'New Story Posted!',
          body: '$username added a new story.',
          notificationLayout: NotificationLayout.BigText,
          displayOnForeground: false, // Don't show when app is in foreground
          displayOnBackground: true,
        ),
      );
    } catch (e) {
      debugPrint('Error showing story notification: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getVisibleStories(
    String currentUserId,
  ) async* {
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

    yield* _firestore.collection("stories").snapshots().asyncMap((
      snapshot,
    ) async {
      List<Map<String, dynamic>> stories = [];

      for (var doc in snapshot.docs) {
        if (!chatUserIds.contains(doc.id) && doc.id != currentUserId) continue;

        final userData = doc.data();
        final userStoriesSnap = await doc.reference
            .collection("userStories")
            .orderBy("timestamp", descending: true)
            .where(
              "expiresAt",
              isGreaterThan: DateTime.now(),
            ) // Only show active stories
            .get();

        if (userStoriesSnap.docs.isNotEmpty) {
          // Get username from users collection if not in stories doc
          String username = userData["username"] as String? ?? "Unknown";
          if (username == "Unknown") {
            try {
              final userDoc = await _firestore
                  .collection("users")
                  .doc(doc.id)
                  .get();
              username =
                  userDoc.data()?["username"] as String? ?? "Unknown User";
            } catch (e) {
              username = "Unknown User";
            }
          }

          stories.add({
            "userId": doc.id,
            "username": username,
            "stories": userStoriesSnap.docs.map((d) => d.data()).toList(),
          });
        }
      }
      return stories;
    });
  }

  // Fetch all stories for a better story viewer experience
  Future<List<Map<String, dynamic>>> fetchAllStories(
    String currentUserId,
  ) async {
    try {
      final chatRooms = await _firestore
          .collection("chat_rooms")
          .where("members", arrayContains: currentUserId)
          .get();

      List<String> chatUserIds = [];
      for (var room in chatRooms.docs) {
        final members = List<String>.from(room["members"] ?? []);
        chatUserIds.addAll(members.where((id) => id != currentUserId));
      }

      final snapshot = await _firestore.collection("stories").get();
      List<Map<String, dynamic>> stories = [];

      for (var doc in snapshot.docs) {
        if (!chatUserIds.contains(doc.id) && doc.id != currentUserId) continue;

        final userData = doc.data();
        final userStoriesSnap = await doc.reference
            .collection("userStories")
            .orderBy("timestamp", descending: true)
            .where("expiresAt", isGreaterThan: DateTime.now())
            .get();

        if (userStoriesSnap.docs.isNotEmpty) {
          // Get username from users collection if not in stories doc
          String username = userData["username"] as String? ?? "Unknown";
          if (username == "Unknown") {
            try {
              final userDoc = await _firestore
                  .collection("users")
                  .doc(doc.id)
                  .get();
              username =
                  userDoc.data()?["username"] as String? ?? "Unknown User";
            } catch (e) {
              username = "Unknown User";
            }
          }

          stories.add({
            "userId": doc.id,
            "username": username,
            "stories": userStoriesSnap.docs.map((d) => d.data()).toList(),
          });
        }
      }
      return stories;
    } catch (e) {
      print("Error fetching stories: $e");
      return [];
    }
  }
}
