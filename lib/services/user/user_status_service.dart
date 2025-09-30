import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';

class UserStatusService {
  static final UserStatusService _instance = UserStatusService._internal();
  factory UserStatusService() => _instance;
  UserStatusService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  StreamSubscription<DocumentSnapshot>? _presenceSubscription;
  StreamSubscription<DatabaseEvent>? _rtdbConnectionSubscription;
  DatabaseReference? _userStatusRef;
  Timer? _onlineTimer;

  // Online status management
  Future<void> setUserOnline() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });

      // Set up periodic online status updates
      _onlineTimer?.cancel();
      _onlineTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        _updateOnlineStatus();
      });
    } catch (e) {
      debugPrint('Error setting user online: $e');
    }
  }

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

  Future<void> _updateOnlineStatus() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating online status: $e');
    }
  }

  // Get user status stream
  Stream<UserStatus> getUserStatus(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return UserStatus.offline();

      final data = doc.data()!;
      final isOnline = data['isOnline'] ?? false;
      final lastSeen = data['lastSeen'] as Timestamp?;

      return UserStatus(isOnline: isOnline, lastSeen: lastSeen?.toDate());
    });
  }

  // Typing status management
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

  // Get typing users stream
  Stream<List<String>> getTypingUsers(String chatRoomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('typing')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => doc.id).toList();
        });
  }

  // Clean up old typing indicators
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
      debugPrint('Error cleaning up typing indicators: $e');
    }
  }

  // Initialize presence monitoring
  void initializePresenceMonitoring() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Set up Firestore presence
    setUserOnline();

    // Set up Realtime Database presence
    _setupRtdbPresence(user.uid);
  }

  void _setupRtdbPresence(String userId) {
    // Set up connection monitoring
    final connectedRef = _rtdb.ref('.info/connected');
    _userStatusRef = _rtdb.ref('status/$userId');

    _rtdbConnectionSubscription = connectedRef.onValue.listen((event) {
      final isConnected = event.snapshot.value as bool? ?? false;

      if (isConnected) {
        // We're connected (or reconnected)
        // Set up onDisconnect operations
        _userStatusRef
            ?.onDisconnect()
            .update({'state': 'offline', 'last_changed': ServerValue.timestamp})
            .then((_) {
              // Update user status to online
              _userStatusRef?.update({
                'state': 'online',
                'last_changed': ServerValue.timestamp,
              });
            });
      }
    });

    // Sync RTDB status with Firestore for offline capabilities
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

  // Cleanup
  void dispose() {
    _presenceSubscription?.cancel();
    _rtdbConnectionSubscription?.cancel();
    _onlineTimer?.cancel();

    final user = _auth.currentUser;
    if (user != null) {
      // Remove onDisconnect operations
      _userStatusRef?.onDisconnect().cancel();

      // Set status to offline
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

  factory UserStatus.offline() {
    return UserStatus(isOnline: false, lastSeen: DateTime.now());
  }

  String getStatusText() {
    if (isOnline) {
      return 'Online';
    } else if (lastSeen != null) {
      final now = DateTime.now();
      final difference = now.difference(lastSeen!);

      if (difference.inDays > 0) {
        return 'Last seen ${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return 'Last seen ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return 'Last seen ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Last seen just now';
      }
    } else {
      return 'Offline';
    }
  }

  Color getStatusColor() {
    return isOnline ? Colors.green : Colors.grey;
  }
}
