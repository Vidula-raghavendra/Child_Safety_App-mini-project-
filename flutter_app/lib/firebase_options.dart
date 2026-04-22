import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDYW46FRRDUttTpPZyspWwx81pxY5D8bPQ',
    appId: '1:177637427027:web:092051f88240b92aab43a6',
    messagingSenderId: '177637427027',
    projectId: 'gen-lang-client-0825681960',
    authDomain: 'gen-lang-client-0825681960.firebaseapp.com',
    storageBucket: 'gen-lang-client-0825681960.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDYW46FRRDUttTpPZyspWwx81pxY5D8bPQ',
    appId: '1:177637427027:android:placeholder',
    messagingSenderId: '177637427027',
    projectId: 'gen-lang-client-0825681960',
    storageBucket: 'gen-lang-client-0825681960.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDYW46FRRDUttTpPZyspWwx81pxY5D8bPQ',
    appId: '1:177637427027:ios:placeholder',
    messagingSenderId: '177637427027',
    projectId: 'gen-lang-client-0825681960',
    storageBucket: 'gen-lang-client-0825681960.firebasestorage.app',
    iosBundleId: 'com.example.safenest',
  );
}
