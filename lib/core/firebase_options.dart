import 'package:firebase_core/firebase_core.dart';
import 'env.dart';

/// Firebase config — 빌드 시 --dart-define 으로 주입된 Env에서 가져옴.
class DefaultFirebaseOptions {
  static FirebaseOptions get current => const FirebaseOptions(
        apiKey: Env.firebaseApiKey,
        appId: Env.firebaseAppId,
        messagingSenderId: Env.firebaseMessagingSenderId,
        projectId: Env.firebaseProjectId,
        authDomain: Env.firebaseAuthDomain,
        storageBucket: Env.firebaseStorageBucket,
      );
}
