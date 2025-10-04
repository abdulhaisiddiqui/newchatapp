import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'call_models.dart';

/// Service class for handling call operations with Firebase
class CallService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Active listener subscription
  StreamSubscription<QuerySnapshot>? _incomingCallListener;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// ✅ START LISTENING FOR INCOMING CALLS (call this in main.dart or app init)
  void startListeningForCalls(
    Function(String, String, String, bool) onIncomingCall,
  ) {
    final userId = currentUserId;
    if (userId == null) return;

    _incomingCallListener = _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data()!;
              onIncomingCall(
                data['callId'],
                data['callerId'],
                data['callerName'] ?? 'Unknown',
                data['isVideo'] ?? false,
              );
            }
          }
        });
  }

  /// Stop listening (call in dispose)
  void stopListeningForCalls() {
    _incomingCallListener?.cancel();
    _incomingCallListener = null;
  }

  // Initiate a call
  Future<bool> initiateCall(
    String callId,
    String receiverId,
    bool isVideo,
  ) async {
    try {
      final callerId = currentUserId;
      if (callerId == null) return false;

      final callerData = await _firestore
          .collection('users')
          .doc(callerId)
          .get();
      final callerName = callerData.data()?['username'] ?? 'Unknown User';

      // Create call document in Firestore
      await _firestore.collection('calls').doc(callId).set({
        'callId': callId,
        'callerId': callerId,
        'callerName': callerName,
        'receiverId': receiverId,
        'isVideo': isVideo,
        'status': 'ringing',
        'startTime': FieldValue.serverTimestamp(),
        'endTime': null,
        'duration': null,
      });

      return true;
    } catch (e) {
      print('Error initiating call: $e');
      return false;
    }
  }

  // Answer a call
  Future<bool> answerCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'connected',
        'connectedTime': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error answering call: $e');
      return false;
    }
  }

  // End a call
  Future<bool> endCall(String callId) async {
    try {
      // Get the call document
      final callDoc = await _firestore.collection('calls').doc(callId).get();
      final callData = callDoc.data();

      if (callData == null) return false;

      // Calculate duration if the call was connected
      int? durationInSeconds;
      if (callData['status'] == 'connected' &&
          callData['connectedTime'] != null) {
        final connectedTime = (callData['connectedTime'] as Timestamp).toDate();
        final now = DateTime.now();
        durationInSeconds = now.difference(connectedTime).inSeconds;
      }

      // Update the call document
      await _firestore.collection('calls').doc(callId).update({
        'status': 'ended',
        'endTime': FieldValue.serverTimestamp(),
        'duration': durationInSeconds,
      });

      // Save call history for both users
      if (durationInSeconds != null) {
        await _saveCallHistoryForBothUsers(callData, durationInSeconds);
      }

      return true;
    } catch (e) {
      print('Error ending call: $e');
      return false;
    }
  }

  // Decline a call
  Future<bool> declineCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'declined',
        'endTime': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error declining call: $e');
      return false;
    }
  }

  // Save call history for both caller and receiver
  Future<void> _saveCallHistoryForBothUsers(
    Map<String, dynamic> callData,
    int duration,
  ) async {
    final callerId = callData['callerId'];
    final receiverId = callData['receiverId'];
    final callerName = callData['callerName'] ?? 'Unknown';
    final isVideo = callData['isVideo'] ?? false;
    final startTime =
        (callData['startTime'] as Timestamp?)?.toDate() ?? DateTime.now();

    // Get receiver name
    final receiverDoc = await _firestore
        .collection('users')
        .doc(receiverId)
        .get();
    final receiverName = receiverDoc.data()?['username'] ?? 'Unknown';

    // Save for caller (outgoing)
    await _firestore
        .collection('users')
        .doc(callerId)
        .collection('callHistory')
        .add({
          'callId': callData['callId'],
          'userId': receiverId,
          'userName': receiverName,
          'timestamp': startTime,
          'duration': duration,
          'isVideo': isVideo,
          'direction': 'outgoing',
        });

    // Save for receiver (incoming)
    await _firestore
        .collection('users')
        .doc(receiverId)
        .collection('callHistory')
        .add({
          'callId': callData['callId'],
          'userId': callerId,
          'userName': callerName,
          'timestamp': startTime,
          'duration': duration,
          'isVideo': isVideo,
          'direction': 'incoming',
        });
  }

  // Save call history
  Future<void> saveCallHistory(String userId, CallHistoryEntry entry) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('callHistory')
          .add({
            'callId': entry.callId,
            'userId': entry.userId,
            'userName': entry.userName,
            'timestamp': entry.timestamp,
            'duration': entry.duration?.inSeconds,
            'isVideo': entry.isVideo,
            'direction': entry.direction.toString().split('.').last,
          });
    } catch (e) {
      print('Error saving call history: $e');
    }
  }

  // Get call history
  Future<List<CallHistoryEntry>> getCallHistory(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('callHistory')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return CallHistoryEntry(
          callId: data['callId'] ?? '',
          userId: data['userId'] ?? '',
          userName: data['userName'] ?? 'Unknown',
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          duration: data['duration'] != null
              ? Duration(seconds: data['duration'])
              : null,
          isVideo: data['isVideo'] ?? false,
          direction: _parseCallDirection(data['direction']),
        );
      }).toList();
    } catch (e) {
      print('Error getting call history: $e');
      return [];
    }
  }

  // Parse call direction from string
  CallDirection _parseCallDirection(String? direction) {
    switch (direction) {
      case 'incoming':
        return CallDirection.incoming;
      case 'outgoing':
        return CallDirection.outgoing;
      case 'missed':
        return CallDirection.missed;
      default:
        return CallDirection.missed;
    }
  }
}
