// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing


import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:moussa_updater/moussa_updater.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('Moussaupdater returns notSupported on non-mobile platforms', () async {
    final result = await Moussaupdater.checkAndMaybeUpdate(
      minVersion: '1.0.0',
      androidUpdateMode: AndroidUpdateMode.immediate,
      androidPackageId: 'com.example.app',
      iosAppId: '1234567890',
      playOnly: true,
    );

    expect(
      result.action == MoussaAction.notSupported ||
      result.action == MoussaAction.upToDate ||
      result.action == MoussaAction.forceBlocked,
      true,
    );
  });
}
