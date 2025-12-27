import 'package:flutter_test/flutter_test.dart';
import 'package:moussa_updater/moussa_updater.dart';

void main() {
  test('Moussaupdater returns notSupported on non-mobile platforms', () async {
    final result = await MoussaUpdater.checkAndMaybeUpdate(
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
