import 'package:firebase_core/firebase_core.dart';

// NOTE: Firebase web API keys are safe to include in client-side code.
// They are restricted by Firebase Security Rules, App Check, and domain allowlists.
// For production, ensure:
//   1. Firebase Security Rules are properly configured
//   2. App Check is enabled
//   3. HTTP referrer restrictions are set in the Google Cloud Console
const firebaseOptionsWeb = FirebaseOptions(
  apiKey: "",
  authDomain: "",
  databaseURL: "",
  projectId: "",
  storageBucket: "",
  messagingSenderId: "",
  appId: ""
);