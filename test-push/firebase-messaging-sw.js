// =====================================================
// firebase-messaging-sw.js (테스트용)
// 백그라운드 푸시 수신 핸들러
// 반드시 호스팅 루트(/firebase-messaging-sw.js) 경로에 배포되어야 함
// FCM SDK 권장 패턴: compat 빌드 사용 (importScripts 호환)
// =====================================================

importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

// ⚠️ index.html 의 firebaseConfig 와 동일한 값으로 교체
firebase.initializeApp({
  apiKey:            "YOUR_API_KEY",
  authDomain:        "YOUR_PROJECT.firebaseapp.com",
  projectId:         "YOUR_PROJECT",
  storageBucket:     "YOUR_PROJECT.appspot.com",
  messagingSenderId: "YOUR_SENDER_ID",
  appId:             "YOUR_APP_ID"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw] 백그라운드 수신', payload);
  const title = payload.notification?.title || payload.data?.title || '알림';
  const body  = payload.notification?.body  || payload.data?.body  || '';
  self.registration.showNotification(title, {
    body: body,
    icon: '/icon-192.png',
    badge: '/icon-192.png'
  });
});
