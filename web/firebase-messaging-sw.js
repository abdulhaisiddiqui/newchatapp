// web/firebase-messaging-sw.js

// NOTE: use the compat version that matches your Firebase SDK version.
// Replace the version numbers with the one you use (e.g. 9.22.1 or similar)

importScripts('https://www.gstatic.com/firebasejs/9.22.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.1/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker by passing the config
// (you can copy the same config used in your web Firebase initialize).
firebase.initializeApp({
  apiKey: "AIzaSyB5vPtF80YreLTjnxj2DYuQ9gyZVR3f-Yk",
  authDomain: "baby-shop-hub-a04d1.firebaseapp.com",
  projectId: "baby-shop-hub-a04d1",
  storageBucket: "baby-shop-hub-a04d1.firebasestorage.app",
  messagingSenderId: "93624205799",
  appId: "1:93624205799:web:3920f77b4c567fdeb53d42",
});

// Retrieve firebase messaging
const messaging = firebase.messaging();

// Optional: handle background messages
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);

  const title = (payload.notification && payload.notification.title) || 'New message';
  const options = {
    body: (payload.notification && payload.notification.body) || '',
    icon: '/icons/Icon-192.png', // provide a valid icon path in web/
    data: payload.data || {}
  };

  return self.registration.showNotification(title, options);
});