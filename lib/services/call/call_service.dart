import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'call_models.dart';

/// Service class for handling call operations with Firebase
class CallService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Initiate a call
  Future<bool> initiateCall(String callId, String receiverId, bool isVideo) async {
    try {
      final callerId = currentUserId;
      if (callerId == null) return false;

      final callerData = await _firestore.collection('users').doc(callerId).get();
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
      if (callData['status'] == 'connected' && callData['connectedTime'] != null) {
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

  // Save call history
  Future<void> saveCallHistory(String userId, CallHistoryEntry entry) async {
    try {
      await _firestore.collection('users').doc(userId).collection('callHistory').add({
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