import 'package:flutter/material.dart';
import 'package:moussa_updater/moussa_updater.dart';
import 'force_update_page.dart';
import 'home_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _ran = false; // ✅ يمنع إعادة التنفيذ (loop)

  // عدّل دول بقيمك
  static const String _minVersion = '2.3.0';
  static const AndroidUpdateMode _androidMode = AndroidUpdateMode.immediate;
  static const bool _playOnly = true;
  static const String _androidPackageId = 'com.example.app';
  static const String _iosAppId = '1234567890';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ran) return;
    _ran = true;

    // ✅ شغّل بعد أول فريم عشان ما يحصلش مشاكل context
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootGate());
  }

  Future<void> _bootGate() async {
    final res = await Moussaupdater.checkAndMaybeUpdate(
      minVersion: _minVersion,
      androidUpdateMode: _androidMode,
      androidPackageId: _androidPackageId,
      iosAppId: _iosAppId,
      playOnly: _playOnly,
    );

    // ✅ لو Android بدأ In-App Update، اقعد في Splash (اختياري) أو اعرض Loading
    if (res.action == MoussaAction.updateStarted) {
      // تقدر تعرض نص "جارِ التحديث..." هنا
      return;
    }

    // ✅ لو اتمنع أو لازم يفتح المتجر
    if (res.action == MoussaAction.forceBlocked || res.action == MoussaAction.openStore) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ForceUpdatePage(
            androidPackageId: _androidPackageId,
            iosAppId: _iosAppId,
            result: res, // نعرض السبب/المصدر إن حبيت
          ),
        ),
      );
      return;
    }

    // ✅ لو NotSupported (Web/Desktop) أو UpToDate: ادخل التطبيق عادي
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Checking for updates...'),
            ],
          ),
        ),
      ),
    );
  }
}
