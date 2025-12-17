import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContactService {
  static final ContactService _instance = ContactService._internal();
  factory ContactService() => _instance;
  ContactService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Add a contact
  Future<void> addContact(String contactUserId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _firestore
        .collection('contacts')
        .doc(user.uid)
        .collection('contacts')
        .doc(contactUserId)
        .set({'addedAt': FieldValue.serverTimestamp()});
  }

  /// Remove a contact
  Future<void> removeContact(String contactUserId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _firestore
        .collection('contacts')
        .doc(user.uid)
        .collection('contacts')
        .doc(contactUserId)
        .delete();
  }

  /// Get user's contacts as a stream of user IDs
  Stream<List<String>> getContacts() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('contacts')
        .doc(user.uid)
        .collection('contacts')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  /// Check if a user is a contact
  Future<bool> isContact(String contactUserId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _firestore
        .collection('contacts')
        .doc(user.uid)
        .collection('contacts')
        .doc(contactUserId)
        .get();

    return doc.exists;
  }
}
