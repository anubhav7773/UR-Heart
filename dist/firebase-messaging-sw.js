importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js');

// Initialize Firebase inside Web Push Service Worker
firebase.initializeApp({
  apiKey: 'AIzaSyBlKy9rPprSKhrrMuXZLppiupVOV8Fr5W0',
  appId: '1:527791570469:web:527791570469',
  messagingSenderId: '527791570469',
  projectId: 'ur-heart-44b46',
  authDomain: 'ur-heart-44b46.firebaseapp.com',
  storageBucket: 'ur-heart-44b46.firebasestorage.app',
});

const messaging = firebase.messaging();

// Outside-the-app Background Push Handler (triggers when tab is closed/backgrounded)
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background push message:', payload);
  const title = (payload.notification && payload.notification.title) ||
                (payload.data && payload.data.title) ||
                'UR-Heart Sanctuary';
  const body = (payload.notification && payload.notification.body) ||
               (payload.data && payload.data.body) ||
               'You have a new sacred alert in UR-Heart.';

  const options = {
    body: body,
    icon: '/icons/Icon-192.png',
    badge: '/favicon.png',
    vibrate: [200, 100, 200],
    tag: 'ur-heart-push',
    renotify: true,
    data: payload.data || {},
  };

  self.registration.showNotification(title, options);
});

// Bring app to focus when user clicks on system tray notification
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});
