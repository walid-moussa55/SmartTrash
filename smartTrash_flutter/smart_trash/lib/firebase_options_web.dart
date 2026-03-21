import 'package:firebase_core/firebase_core.dart';

// NOTE: Firebase web API keys are safe to include in client-side code.
// They are restricted by Firebase Security Rules, App Check, and domain allowlists.
// For production, ensure:
//   1. Firebase Security Rules are properly configured
//   2. App Check is enabled
//   3. HTTP referrer restrictions are set in the Google Cloud Console
const firebaseOptionsWeb = FirebaseOptions(
  apiKey: "AIzaSyDLhxd8pKAdHoN0k1667JOhOwVFn2GBYlU",
  authDomain: "smarttrash-e2204.firebaseapp.com",
  databaseURL: "https://smarttrash-e2204-default-rtdb.firebaseio.com",
  projectId: "smarttrash-e2204",
  storageBucket: "smarttrash-e2204.firebasestorage.app",
  messagingSenderId: "163524489825",
  appId: "1:163524489825:web:46e6d56b9f4ec8ef7a7020"
);