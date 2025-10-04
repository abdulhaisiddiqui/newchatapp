import 'package:cloud_firestore/cloud_firestore.dart';

mixin ErrorHandler {
  Future<T?> runSafely<T>(
    Future<T> Function() action, {
    Function(String message)? onError,
    Function()? onStart,
    Function()? onDone,
  }) async {
    try {
      onStart?.call();
      final result = await action();
      return result;
    } on FirebaseException catch (e) {
      final message = _getFirebaseErrorMessage(e);
      onError?.call(message);
    } catch (e) {
      onError?.call("Unexpected error: $e");
    } finally {
      onDone?.call();
    }
    return null;
  }

  String _getFirebaseErrorMessage(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return "Permission denied. Please check your authentication and Firestore rules.";
      case 'not-found':
        return "Document not found.";
      case 'already-exists':
        return "Document already exists.";
      case 'failed-precondition':
        return "Operation failed. This might require a Firestore index. Check the error link.";
      case 'resource-exhausted':
        return "Quota exceeded. Please try again later.";
      case 'cancelled':
        return "Operation was cancelled.";
      case 'deadline-exceeded':
        return "Operation timed out. Please check your connection.";
      case 'unavailable':
        return "Service unavailable. Please try again later.";
      default:
        return "Firestore error: ${e.message}";
    }
  }
}
