import 'package:flutter/material.dart';
import 'package:moussa_updater/moussa_updater.dart';

class ForceUpdatePage extends StatelessWidget {
  final String androidPackageId;
  final String iosAppId;
  final MoussaupdaterResult result;

  const ForceUpdatePage({
    super.key,
    required this.androidPackageId,
    required this.iosAppId,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'لازم تحدّث التطبيق عشان تكمّل',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'حمّل النسخة الرسمية من المتجر ثم افتح التطبيق تاني.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // ✅ معلومات Debug اختيارية (مفيدة أثناء التطوير)
                  _DebugBox(result: result),

                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await Moussaupdater.openStore(
                          androidPackageId: androidPackageId,
                          iosAppId: iosAppId,
                        );
                      },
                      child: const Text('Update'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DebugBox extends StatelessWidget {
  final MoussaupdaterResult result;

  const _DebugBox({required this.result});

  @override
  Widget build(BuildContext context) {
    // تقدر تشيل البوكس ده في production
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 12, color: Colors.black54),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('platform: ${result.platform}'),
            Text('action: ${result.action.name}'),
            if (result.installerSource != null)
              Text('installerSource: ${result.installerSource!.name}'),
            if (result.currentVersion.isNotEmpty)
              Text('currentVersion: ${result.currentVersion}'),
            if (result.minVersion.isNotEmpty)
              Text('minVersion: ${result.minVersion}'),
            if (result.reason != null) Text('reason: ${result.reason}'),
          ],
        ),
      ),
    );
  }
}
