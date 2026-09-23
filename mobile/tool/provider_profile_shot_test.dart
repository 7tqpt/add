// **تصويرُ الشاشة الحقيقيّة** — «الملف الشخصيّ» لمقدّم الخدمة.
//
//   SHOTS=<مجلّد> flutter test tool/provider_profile_shot_test.dart
//
// ── ولماذا تُصوَّر هذه بالذات ──────────────────────────────────────────────
//
// نزعُ أعمدة `service_providers` عن `anon` و`authenticated` يقطع الطريقَ
// الذي كانت تقرأ به هذه الشاشةُ **أرباحَها وسببَ رفضها** — فتمرّ الآن
// بدالّة `api_my_provider()`.
//
// **ولا شيءَ فيها يجب أن يتغيّر.** وهذا هو الخطر: تبديلُ طريقٍ إلى البيانات
// لا يُرى في `flutter analyze` ولا في اختبارٍ يسأل الشيفرةَ عن نفسها —
// يُرى حين يفتح صاحبُ القاعة شاشتَه فيجد «٠ ريال» مكانَ أرباحه.
//
// فتُصوَّر قبل التعديل وبعده، وتُقابل الصورتان.
//
// ── وما هو مصوَّرٌ وما هو مرسوم ─────────────────────────────────────────────
//
// **مصوَّرةٌ كلُّها**: `ProviderProfileScreen` المدفوعةُ بعينها، ببيانات وضع
// العرض — وهي المسارُ نفسُه الذي يقرأ القاعدةَ الحقيقيّة، غير أنّ مصدرَه
// `demo.dart` بدل الشبكة. ولا شيءَ في هذا اللوح مرسومٌ بالألوان.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/provider_profile.dart';

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

Future<void> _shoot(WidgetTester tester, Finder of, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(of);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

const _label = TextStyle(fontFamily: brandFont, fontFamilyFallback: arabicFallback);

const _pw = 380.0;
const _ph = 760.0;

Session _provider() => Session()
  ..userId = 'u1'
  ..email = 'hall@sdd.company'
  ..appUserId = 'a1'
  ..providerId = 'demo-provider'
  ..loading = false;

/// مزوّدٌ موثَّقٌ له أرباحٌ — وهي الأرقامُ التي يمرّ طريقُها بالدالّة الجديدة.
void _seed() {
  demoProviderId = 'demo-provider';
  demoProviderProfile = ProviderProfile(
    id: 'demo-provider',
    businessName: 'قاعة اللؤلؤة للأفراح',
    fullName: 'أحمد الشرعبي',
    governorate: 'صنعاء',
    bio: 'قاعة أفراح تتّسع لأربعمئة ضيف، بإضاءة وصوت وتنسيق كامل.',
    logoPath: '',
    status: 'verified',
    rating: 4.6,
    reviewsCount: 38,
    completedBookings: 52,
    totalEarnings: 7350000,
    rejectionReason: '',
  );
}

Widget _wrap(Widget child) => RepaintBoundary(
      key: const ValueKey('shot'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // **و`Scaffold` لازمٌ هنا لا زينة**: الشاشةُ فيها `InkWell`، و`Ink`
        // بلا `Material` فوقه يرمي عند البناء فتخرج اللقطةُ ناقصةً بلا أن
        // يُقال لماذا.
        home: Scaffold(
          backgroundColor: AppColors.surface,
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              color: AppColors.surface,
              padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الملفُّ الشخصيُّ لمقدّم الخدمة',
                    style: _label.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent)),
                const SizedBox(height: 2),
                Text(
                  'مصوَّرةٌ من الشيفرة المدفوعة. و«إجمالي الأرباح» هو الرقمُ الذي '
                  'تبدّل طريقُه إلى القاعدة — ويجب ألّا يتبدّل هو.',
                  style: _label.copyWith(
                      fontSize: 11.5, color: AppColors.muted, height: 1.5),
                ),
                const SizedBox(height: 14),
                Container(
                  width: _pw,
                  height: _ph,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF3A3A3A), width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: child,
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('لقطةُ ملفّ مقدّم الخدمة', (tester) async {
    tester.view.physicalSize = const Size(440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    _seed();

    await tester.pumpWidget(_wrap(
      SizedBox(width: _pw, height: _ph, child: ProviderProfileScreen(session: _provider())),
    ));
    // **ولا `pumpAndSettle`**: الشاشةُ تقرأ بـ`FutureBuilder` بمهلةِ عرضٍ
    // مصطنعة، والانتظارُ اللانهائيُّ يعلّق الراسم.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    // **ولا يُصدَّق أنّ اللقطةَ وقعت: تُسأل الشجرة.**
    expect(find.byType(ProviderProfileScreen), findsOneWidget);
    expect(find.text('إجمالي الأرباح'), findsOneWidget,
        reason: 'صفُّ الأرباح غائبٌ — فلا شيءَ يُقاس عليه');
    expect(find.textContaining('7,350,000'), findsOneWidget,
        reason: 'الرقمُ لم يصل الشاشة');
    expect(tester.takeException(), isNull, reason: 'فاضت الشاشة');

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);
    final name = Platform.environment['SHOT_NAME'] ?? 'provider-profile';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/$name.png');
  });
}
