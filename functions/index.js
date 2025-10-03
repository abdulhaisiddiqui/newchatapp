const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Trigger on new message creation in Firestore
exports.sendMessageNotification = functions.firestore
  .document('messages/{messageId}')
  .onCreate(async (snap, context) => {
    const messageData = snap.data();
    if (!messageData) {
      console.error('No data in message snapshot');
      return null;
    }

    const recipientId = messageData.recipientId;
    const senderName = messageData.senderName || 'Someone';
    const content = messageData.content || 'New message';
    const chatId = messageData.chatId;

    if (!recipientId) {
      console.error('Missing recipientId');
      return null;
    }

    try {
      const userDoc = await admin.firestore().collection('users').doc(recipientId).get();
      if (!userDoc.exists) {
        console.log('No user document found for recipient:', recipientId);
        return null;
      }

      const userData = userDoc.data();
      const fcmToken = userData?.fcmToken;

      if (!fcmToken) {
        console.log('No FCM token for user:', recipientId);
        return null;
      }

      const payload = {
        notification: {
          title: `New Message from ${senderName}`,
          body: content,
        },
        data: {
          chatId: chatId || '',
        },
        token: fcmToken,
      };

      await admin.messaging().send(payload);
      console.log('Notification sent successfully to:', recipientId);
      return null;
    } catch (error) {
      console.error('Error sending notification:', error);
      return null;
    }
  });