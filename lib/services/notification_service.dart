import 'package:awesome_notifications/awesome_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> showMessageNotification({
    required String chatRoomId,
    required String senderName,
    required String messageText,
    required String receiverId,
    required String receiverEmail,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: 'chat_messages',
        title: senderName,
        body: messageText,
        notificationLayout: NotificationLayout.Messaging,
        wakeUpScreen: true,
        payload: {
          'chatRoomId': chatRoomId,
          'receiverId': receiverId,
          'receiverEmail': receiverEmail,
          'senderName': senderName,
        },
      ),
    );
  }

  Future<void> showStoryNotification({
    required String uploaderName,
    required String storyType,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: 'stories',
        title: 'New Story',
        body: '$uploaderName posted a new $storyType',
        notificationLayout: NotificationLayout.Default,
        wakeUpScreen: false,
        payload: {'uploaderName': uploaderName, 'storyType': storyType},
      ),
    );
  }

  Future<void> showCallNotification({
    required String callerName,
    required String callerId,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: 'calls',
        title: 'Incoming Call',
        body: '$callerName is calling...',
        notificationLayout: NotificationLayout.Default,
        wakeUpScreen: true,
        payload: {'callerId': callerId, 'callerName': callerName},
      ),
    );
  }

  Future<bool> requestPermission() async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      isAllowed = await AwesomeNotifications()
          .requestPermissionToSendNotifications();
    }
    return isAllowed;
  }

  Future<void> cancelNotification(int id) async {
    await AwesomeNotifications().cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
  }
}
