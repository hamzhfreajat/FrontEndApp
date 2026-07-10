import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAdXn5vB8YIFpy2b2iXY2Lkzsu8eHOw3hY',
    appId: '1:683492643202:android:38ec11d2c78240b4daff9b',
    messagingSenderId: '683492643202',
    projectId: 'classifiedsapp-6d4ea',
    storageBucket: 'classifiedsapp-6d4ea.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCWg4KMtIiSqPeWkRvtYZaqjSxEOUkgB8o',
    appId: '1:683492643202:ios:a61ab6867fffd726daff9b',
    messagingSenderId: '683492643202',
    projectId: 'classifiedsapp-6d4ea',
    storageBucket: 'classifiedsapp-6d4ea.firebasestorage.app',
    iosBundleId: 'com.sooqcom.app',
  );
}
