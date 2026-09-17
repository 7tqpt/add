// **تصويرُ عطلٍ قائم — لا مقترح.** الشيفرةُ المشحونةُ كما هي، ولا سطرَ في
// `lib/` تغيّر.
//
//   SHOTS=<مجلّد> flutter test tool/photo_lock_bug_shot_test.dart
//
// ── العطلُ الذي أخرجه صاحبُ المنصّة ─────────────────────────────────────────
//
// قال: «عند ما أجي أغيّر صورة يخرجني التطبيق ولم يتغيّر شيء».
//
// **والسببُ قفلُ التطبيق الذي فُرض في ١٫٤٩٫**، لا الصورةُ ولا الرفع:
//
//   ١) يُضغط القرصُ فتُفتح ورقةُ «اختيار من المعرض».
//   ٢) و**المعرضُ نافذةُ نظامٍ خارج التطبيق** — فيهبط التطبيقُ إلى الخلفيّة،
//      و`RootScreen.didChangeAppLifecycleState` يُنادي `lock.onLeave()`.
//   ٣) تُختار الصورةُ فيعود التطبيقُ: `resumed` → `lock.onReturn()` →
//      **`_locked = true`**.
//   ٤) فيبدّل `RootScreen` الشجرةَ كلَّها بشاشة الرمز — **وتُهدَم معها
//      `AccountScreen`**. فالانتظارُ المعلَّق على `pickImage` يعود إلى حالةٍ
//      `mounted == false`، فيرجع صامتاً قبل أن يرفع شيئاً.
//
// فالذي رآه: شاشةُ رمزٍ في وجهه («يخرجني التطبيق»)، وصورةٌ لم تتبدّل («ولم
// يتغيّر شيء»). وكلاهما أثرٌ واحد.
//
// **وليس عطلَ الصورة وحدَها.** كلُّ ما يفتح نافذةَ نظامٍ يفعلها: الكاميرا،
// وانتقاءُ الملفّات، وواتساب في تأكيد الرقم، وإعداداتُ الإشعارات، والخرائط.
//
// ── وما هو حقيقيٌّ في هذه اللقطات ──────────────────────────────────────────
//
// **كلُّها.** `RootScreen` المشحونة و`AppLock` المشحون، ودورةُ الحياة تُدفع
// بـ`handleAppLifecycleStateChanged` كما يدفعها النظام. **ولا يُنتقى المعرضُ
// هنا** — لا معرضَ في `flutter test`؛ والمصوَّرُ هو أثرُ الغياب والعودة،
// وهو عينُ ما يقع حين يُفتح المعرض.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/app_lock.dart';
import 'package:aras/src/core/biometrics.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/lock.dart';
import 'package:aras/src/screens/root.dart';

/// حسّاسٌ يرفض — **وإلّا فتح القفلَ بنفسه فلم يُصوَّر شيء.**
class _Sensor implements Biometrics {
  const _Sensor();
  @override
  Future<bool> available() async => false;
  @override
  Future<bool> authenticate() async => false;
}

Future<void> _load(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(File(p).readAsBytes().then(ByteData.sublistView));
  }
  await loader.load();
}

Future<void> _loadFonts() async {
  await _load('IBMPlexSansArabic', [
    for (final w in ['400', '500', '600', '700'])
      'assets/fonts/IBMPlexSansArabic-$w.ttf',
  ]);
  await _load('NotoNaskhArabic', ['assets/fonts/NotoNaskhArabic-Regular.ttf']);
  final icons = File(
      '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) await _load('MaterialIcons', [icons.path]);
}

Future<void> _shoot(WidgetTester tester, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shot')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'demo@example.com'
  ..appUserId = 'a1'
  ..loading = false;

Widget _wrap(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (_, navigator) =>
          RepaintBoundary(key: const ValueKey('shot'), child: navigator!),
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

void main() {
  setUpAll(_loadFonts);
  setUp(() {
    // **ولا خزنةَ نظامٍ في `flutter test`** — فيُركَّب بديلٌ في الذاكرة.
    lockStorageOverride = {};
    biometricsOverride = const _Sensor();
  });
  tearDown(() {
    lockStorageOverride = null;
    biometricsOverride = null;
  });

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('**رحلةٌ إلى المعرض تُلقيه على شاشة الرمز**', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final lock = AppLock();
    await lockSetPin('1234');
    await lock.boot();
    // يفتح قفلَه كما يفتحه كلَّ صباح، فيدخل التطبيق.
    await lock.unlock('1234');

    await tester.pumpWidget(_wrap(RootScreen(session: _session(), lock: lock)));
    await settle(tester);

    expect(find.byType(LockScreen), findsNothing,
        reason: 'دخل مقفلاً — فلا معنى لما بعده');
    await _shoot(tester, '$out/lock-bug-before.png');

    // ── وهنا يُفتح المعرض: نافذةُ نظامٍ تُنزل التطبيقَ إلى الخلفيّة ──────
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);

    // **وهذا هو العطلُ بعينه.**
    expect(find.byType(LockScreen), findsOneWidget,
        reason: 'لم يقع العطلُ — فلعلّه أُصلح، فلا تُصوَّر صورةٌ تكذب');
    expect(lock.locked, isTrue);

    await _shoot(tester, '$out/lock-bug-after.png');
  });
}
