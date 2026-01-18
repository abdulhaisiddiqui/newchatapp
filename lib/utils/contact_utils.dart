import 'package:permission_handler/permission_handler.dart';

class contactsUtils {
  // Add your utility methods here
  static Future<PermissionStatus?> getContactPermission() async {
    // Implementation for getting contact permission
    final permissions = await Permission.contacts.status;

    if (permissions != PermissionStatus.granted &&
        permissions != PermissionStatus.permanentlyDenied) {
      final newPermission = await Permission.contacts.request();
      return newPermission ?? PermissionStatus.denied;
    } else {
      return permissions;
    }
  }
}
