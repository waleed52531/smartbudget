import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartbudget/firebase_options.dart';

void main() {
  test('FlutterFire Android options match the native project and package', () {
    final native =
        jsonDecode(File('android/app/google-services.json').readAsStringSync())
            as Map<String, dynamic>;
    final clients = native['client'] as List;
    final matches = clients.where((dynamic client) {
      return client['client_info']['android_client_info']['package_name'] ==
          'com.corehines.smartbudget';
    }).toList();
    expect(matches, hasLength(1));
    expect(native['project_info']['project_id'], 'smartbudget-561d4');
    expect(DefaultFirebaseOptions.android.projectId, 'smartbudget-561d4');
    expect(
      DefaultFirebaseOptions.android.appId,
      matches.single['client_info']['mobilesdk_app_id'],
    );
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('applicationId = "com.corehines.smartbudget"'));
    expect(gradle, contains('namespace = "com.corehines.smartbudget"'));
  });
}
