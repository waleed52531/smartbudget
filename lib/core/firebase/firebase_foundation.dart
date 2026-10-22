import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Only Android has an approved Firebase registration in Stage 1.
/// Apple apps retain their existing identifiers until that decision is made.
Future<void> initializeFirebaseFoundation() async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
