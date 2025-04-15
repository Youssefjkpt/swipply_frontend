// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBBUz7WrP0LRojUA4hUe8ACFoxbsuA8qq4',
    appId: '1:463526138738:web:0c1fae0e2dfbd31c2f43eb',
    messagingSenderId: '463526138738',
    projectId: 'swipply-4c511',
    authDomain: 'swipply-4c511.firebaseapp.com',
    storageBucket: 'swipply-4c511.firebasestorage.app',
    measurementId: 'G-KGSSXG337G',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBY0PSA9t-sOWTDD0GlvJbMoVoCFvamqYo',
    appId: '1:463526138738:android:e63be7227f69355c2f43eb',
    messagingSenderId: '463526138738',
    projectId: 'swipply-4c511',
    storageBucket: 'swipply-4c511.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDgvHnOdcrPcCOiDs2Qz0NLZJUTxCoPJQA',
    appId: '1:463526138738:ios:26f5aa6ee2f370322f43eb',
    messagingSenderId: '463526138738',
    projectId: 'swipply-4c511',
    storageBucket: 'swipply-4c511.firebasestorage.app',
    androidClientId: '463526138738-6gr7n1do81ebrvt2b8uf77h3h62j66qn.apps.googleusercontent.com',
    iosClientId: '463526138738-l4nuv8lh7iesd2qkks0l45mjmeplc8ks.apps.googleusercontent.com',
    iosBundleId: 'com.example.swipply',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDgvHnOdcrPcCOiDs2Qz0NLZJUTxCoPJQA',
    appId: '1:463526138738:ios:26f5aa6ee2f370322f43eb',
    messagingSenderId: '463526138738',
    projectId: 'swipply-4c511',
    storageBucket: 'swipply-4c511.firebasestorage.app',
    androidClientId: '463526138738-6gr7n1do81ebrvt2b8uf77h3h62j66qn.apps.googleusercontent.com',
    iosClientId: '463526138738-l4nuv8lh7iesd2qkks0l45mjmeplc8ks.apps.googleusercontent.com',
    iosBundleId: 'com.example.swipply',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBBUz7WrP0LRojUA4hUe8ACFoxbsuA8qq4',
    appId: '1:463526138738:web:5ff898114a76fc412f43eb',
    messagingSenderId: '463526138738',
    projectId: 'swipply-4c511',
    authDomain: 'swipply-4c511.firebaseapp.com',
    storageBucket: 'swipply-4c511.firebasestorage.app',
    measurementId: 'G-16P6MMS57T',
  );
}
