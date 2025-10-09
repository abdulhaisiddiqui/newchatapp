import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';

class UserStatusService {
  static final UserStatusService _instance = UserStatusService._internal();
  factory UserStatusService() => _instance;
  UserStatusService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  FirebaseDatabase get _rtdb => FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: "https://baby-shop-hub-a04d1-default-rtdb.firebaseio.com/",
  );

  StreamSubscription<DatabaseEvent>? _rtdbConnectionSubscription;
  DatabaseReference? _userStatusRef;
  Timer? _onlineTimer;

  /// Mark user online
  Future<void> setUserOnline() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // periodic heartbeat
      _onlineTimer?.cancel();
      _onlineTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        _updateLastSeen();
      });
    } catch (e) {
      debugPrint('Error setting user online: $e');
    }
  }
  /// 🔹 Stream whether a specific user is typing in a chat room
  Stream<bool> getTypingStatus(String chatRoomId, String userId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('typing')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }


  /// Mark user offline
  Future<void> setUserOffline() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      _onlineTimer?.cancel();
      _onlineTimer = null;
    } catch (e) {
      debugPrint('Error setting user offline: $e');
    }
  }

  /// Ping last seen
  Future<void> _updateLastSeen() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating last seen: $e');
    }
  }

  /// Stream user status
  Stream<UserStatus> getUserStatus(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return UserStatus.offline();

      final data = doc.data()!;
      final isOnline = data['isOnline'] ?? false;
      final lastSeen = data['lastSeen'] as Timestamp?;

      return UserStatus(isOnline: isOnline, lastSeen: lastSeen?.toDate());
    });
  }

  /// Typing indicator ON/OFF
  Future<void> setTypingStatus(String chatRoomId, bool isTyping) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final typingRef = _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('typing')
          .doc(user.uid);

      if (isTyping) {
        await typingRef.set({
          'userId': user.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        await typingRef.delete();
      }
    } catch (e) {
      debugPrint('Error setting typing status: $e');
    }
  }

  /// Stream typing users in room
  Stream<List<String>> getTypingUsers(String chatRoomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('typing')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  /// Cleanup expired typing docs
  Future<void> cleanupTypingIndicators(String chatRoomId) async {
    try {
      final typingRef = _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('typing');

      final snapshot = await typingRef
          .where(
            'timestamp',
            isLessThan: Timestamp.fromDate(
              DateTime.now().subtract(const Duration(seconds: 30)),
            ),
          )
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error cleaning typing indicators: $e');
    }
  }

  /// Initialize presence monitoring
  void initializePresenceMonitoring() {
    final user = _auth.currentUser;
    if (user == null) return;

    setUserOnline(); // Firestore presence
    _setupRtdbPresence(user.uid); // RTDB fallback
  }

  void _setupRtdbPresence(String userId) {
    final connectedRef = _rtdb.ref('.info/connected');
    _userStatusRef = _rtdb.ref('status/$userId');

    _rtdbConnectionSubscription = connectedRef.onValue.listen((event) {
      final isConnected = event.snapshot.value as bool? ?? false;

      if (isConnected) {
        _userStatusRef
            ?.onDisconnect()
            .update({'state': 'offline', 'last_changed': ServerValue.timestamp})
            .then((_) {
              _userStatusRef?.update({
                'state': 'online',
                'last_changed': ServerValue.timestamp,
              });
            });
      }
    });

    _userStatusRef?.onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        final state = data?['state'] as String?;

        if (state == 'online') {
          _firestore.collection('users').doc(userId).update({
            'isOnline': true,
            'lastSeen': FieldValue.serverTimestamp(),
          });
        } else if (state == 'offline') {
          _firestore.collection('users').doc(userId).update({
            'isOnline': false,
            'lastSeen': FieldValue.serverTimestamp(),
          });
        }
      }
    });
  }

  /// Cleanup
  void dispose() {
    _rtdbConnectionSubscription?.cancel();
    _onlineTimer?.cancel();

    final user = _auth.currentUser;
    if (user != null) {
      _userStatusRef?.onDisconnect().cancel();
      _userStatusRef?.update({
        'state': 'offline',
        'last_changed': ServerValue.timestamp,
      });
    }
  }
}

class UserStatus {
  final bool isOnline;
  final DateTime? lastSeen;

  UserStatus({required this.isOnline, this.lastSeen});

  factory UserStatus.offline() =>
      UserStatus(isOnline: false, lastSeen: DateTime.now());


  String getStatusText() {
    if (isOnline) return 'Online';
    if (lastSeen == null) return 'Offline';

    final diff = DateTime.now().difference(lastSeen!);
    if (diff.inDays > 0) {
      return 'Last seen ${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    } else if (diff.inHours > 0) {
      return 'Last seen ${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    } else if (diff.inMinutes > 0) {
      return 'Last seen ${diff.inMinutes} min${diff.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Last seen just now';
    }
  }

  Color getStatusColor() => isOnline ? Colors.green : Colors.grey;
}
