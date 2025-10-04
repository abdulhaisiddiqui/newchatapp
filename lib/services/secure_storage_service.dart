import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // Keys for storing data
  static const String _isLoggedInKey = 'isLoggedIn';
  static const String _userIdKey = 'userId';
  static const String _userEmailKey = 'userEmail';
  static const String _userNameKey = 'userName';
  static const String _authTokenKey = 'authToken';
  static const String _fcmTokenKey = 'fcmToken';

  // Singleton instance
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  // Generic methods
  Future<void> write(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      print('Error writing to secure storage: $e');
      throw Exception('Failed to save data securely');
    }
  }

  Future<String?> read(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      print('Error reading from secure storage: $e');
      return null;
    }
  }

  Future<void> delete(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      print('Error deleting from secure storage: $e');
    }
  }

  Future<void> deleteAll() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      print('Error clearing secure storage: $e');
    }
  }

  // Authentication-specific methods
  Future<void> saveLoginData({
    required String userId,
    required String email,
    String? userName,
  }) async {
    await Future.wait([
      write(_isLoggedInKey, 'true'),
      write(_userIdKey, userId),
      write(_userEmailKey, email),
      if (userName != null) write(_userNameKey, userName),
    ]);
  }

  Future<Map<String, String?>> getLoginData() async {
    final results = await Future.wait([
      read(_isLoggedInKey),
      read(_userIdKey),
      read(_userEmailKey),
      read(_userNameKey),
    ]);

    return {
      'isLoggedIn': results[0],
      'userId': results[1],
      'userEmail': results[2],
      'userName': results[3],
    };
  }

  Future<bool> isLoggedIn() async {
    final isLoggedIn = await read(_isLoggedInKey);
    return isLoggedIn == 'true';
  }

  Future<String?> getUserId() async {
    return await read(_userIdKey);
  }

  Future<String?> getUserEmail() async {
    return await read(_userEmailKey);
  }

  Future<String?> getUserName() async {
    return await read(_userNameKey);
  }

  Future<void> saveAuthToken(String token) async {
    await write(_authTokenKey, token);
  }

  Future<String?> getAuthToken() async {
    return await read(_authTokenKey);
  }

  Future<void> saveFCMToken(String token) async {
    await write(_fcmTokenKey, token);
  }

  Future<String?> getFCMToken() async {
    return await read(_fcmTokenKey);
  }

  Future<void> clearAuthData() async {
    await Future.wait([
      delete(_isLoggedInKey),
      delete(_userIdKey),
      delete(_userEmailKey),
      delete(_userNameKey),
      delete(_authTokenKey),
      delete(_fcmTokenKey),
    ]);
  }

  // Validation method to check if stored user still exists
  Future<bool> validateStoredUser() async {
    try {
      final userId = await getUserId();
      if (userId == null) return false;

      // You can add additional validation here
      // For example, check if the user still exists in Firebase Auth
      // or if the stored data is still valid

      return true;
    } catch (e) {
      print('Error validating stored user: $e');
      return false;
    }
  }
}
