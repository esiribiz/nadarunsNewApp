import 'package:flutter/foundation.dart';

class AppServerConfig {
  static String get baseUrl {
    // For local development, change this to your local server URL:
    // Android emulator: http://10.0.2.2:8000
    // iOS simulator: http://127.0.0.1:8000
    // Physical device: http://<your-local-ip>:8000
    return 'https://nadaruns.com';
  }
}
