// **مقترحٌ لا تنفيذ.** نافذةُ الإقلاع الأصليّة — البياضُ قبل أن يقلع Flutter.
//
//   SHOTS=<مجلّد> flutter test tool/native_splash_proposal_test.dart
//
// ── ما شكا منه ─────────────────────────────────────────────────────────────
//
// «عند ضغط على التطبيق بداية الإقلاع يطلع أبيض» — ومعها لقطةٌ لشاشةٍ بيضاءَ
// ليس فيها إلّا شريطا النظام.
//
// ── وسببُه مقيسٌ لا مقدَّر ─────────────────────────────────────────────────
//
// في `android/app/src/main/res/` ملفّان بالاسم نفسِه:
//
//   drawable/launch_background.xml      →  @color/brand_page   (كريمُ العلامة)
//   drawable-v21/launch_background.xml  →  ?android:colorBackground
//
// و**كلُّ جوّالٍ حديثٍ يأخذ `drawable-v21`** (أندرويد ٥ فما فوق، أي منذ
// ٢٠١٤). و`?android:colorBackground` في `Theme.Light.NoTitleBar` **أبيض**.
// فالكريمُ الذي في الملفّ الأوّل لا يراه أحد، والذي يُرى بياضُ النظام.
//
// وتلك النافذةُ تبقى قائمةً حتى يرسم Flutter أوّلَ إطار — و`main()` تنتظر
// قبله: `initFormatting` و`loadLocale` و`initSupabase` و`session.boot()`
// و`appLock.boot()`. فعلى شبكةٍ بطيئةٍ يطول البياضُ ثوانيَ.
//
// ── وما يفتح عليه بعدها نبيذيٌّ غامق ──────────────────────────────────────
//
// `BootScreen` تدرّجٌ نبيذيٌّ وعليه العلامةُ و«فرحتي» بيضاءَ. فالقفزةُ من
// بياضٍ كاملٍ إلى نبيذيٍّ غامقٍ ومضةٌ تُرى في كلّ فتحة.
//
// ── ما هو مصوَّرٌ وما هو مرسوم ─────────────────────────────────────────────
//
// **الخليّةُ الأخيرة مصوَّرةٌ من الشيفرة المدفوعة**: `BootScreen` بعينها.
//
// **والأربعُ الأُوَل مرسومةٌ ويُقال.** نافذةُ الإقلاع يرسمها **أندرويد قبل
// أن يقلع محرّك Flutter**، فلا سبيلَ إلى تصويرها من داخل `flutter test`
// أصلاً — ولا من داخل التطبيق. لكنّ المرسومَ ليس تخميناً: الألوانُ من
// `AppColors` نفسِها التي تكتب `colors.xml`، والعلامةُ ملفُّ الحزمة
// `assets/brand/app_mark.png` بعينه، والنسبةُ نسبةُ جوّالٍ حقيقيّ.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/welcome.dart';

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

/// الصورُ تُفكّ ترميزَها خارجَ خيط الاختبار فتحتاج زمناً حقيقيّاً — وبلا
/// هذا تخرج اللوحةُ بلا علامةٍ ويُقرأ المقترحُ كذباً.
Future<void> _settleImages(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// **والخطُّ يُسمّى في كلّ شرحٍ صراحةً.** خرج اللوحُ أوّلَ مرّةٍ وشروحُه
/// مربّعاتٍ بيضاءَ بينما نصُّ `BootScreen` سليم: النصُّ خارجَ `Scaffold`
/// لا يرث خطَّ الثيمة في هذه البيئة. وهو العيبُ الذي تحذّر منه القاعدة.
const _label = TextStyle(
  fontFamily: brandFont,
  fontFamilyFallback: arabicFallback,
);

/// الأيقونةُ الكاملةُ بأرضيّتها — تُقرأ من القرص لا بـ`Image.asset`:
/// المعلَنُ في `pubspec.yaml` هو `app_mark.png` وحدَه.
final _fullIcon = File('assets/brand/app_icon.png').readAsBytesSync();

// ── الجوّالُ المرسوم ────────────────────────────────────────────────────────

const _w = 250.0;
const _h = 520.0;

/// شريطا النظام — ليسا منّا، لكنّ وجودَهما يجعل اللوحَ يُقرأ جوّالاً.
Widget _chrome({required Color ink, required Widget body}) => Column(
      children: [
        SizedBox(
          height: 18,
          child: Row(
            children: [
              const SizedBox(width: 10),
              Icon(Icons.battery_full, size: 10, color: ink.withValues(alpha: 0.55)),
              const Spacer(),
              Icon(Icons.wifi, size: 10, color: ink.withValues(alpha: 0.55)),
              const SizedBox(width: 10),
            ],
          ),
        ),
        Expanded(child: body),
        SizedBox(
          height: 26,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Icon(Icons.menu, size: 11, color: ink.withValues(alpha: 0.45)),
                Icon(Icons.circle_outlined, size: 11, color: ink.withValues(alpha: 0.45)),
                Icon(Icons.chevron_right, size: 13, color: ink.withValues(alpha: 0.45)),
              ],
            ),
          ),
        ),
      ],
    );

Widget _panel({
  required String caption,
  required String note,
  required Widget screen,
}) =>
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _w,
          height: _h,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF3A3A3A), width: 3),
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: screen,
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: _w,
          child: Text(
            caption,
            textAlign: TextAlign.center,
            style: _label.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: _w,
          child: Text(
            note,
            textAlign: TextAlign.center,
            style: _label.copyWith(
                fontSize: 12, color: AppColors.muted, height: 1.45),
          ),
        ),
      ],
    );

/// الخلفيّةُ النبيذيّةُ نفسُها التي في `BrandBackdrop` — تدرّجٌ لا لونٌ مصمت.
///
/// **ولا تُستعمل `BrandBackdrop` هنا**: نافذةُ أندرويد لا تعرف التدرّجَ الذي
/// يرسمه Flutter، وما يُرسم في `launch_background.xml` لونٌ واحد. فيُرسم
/// المقترحُ بما سيُنفَّذ فعلاً لا بما هو أجمل.
Widget _wine({Widget? child}) => Container(
      color: AppColors.accentDeep,
      child: Center(child: child),
    );

Widget _mark(double size) => Image.asset(
      'assets/brand/app_mark.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
    );

Widget _board() => Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'نافذةُ الإقلاع — ما يُرى قبل أن يقلع التطبيق',
            style: _label.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'الأربعُ الأُوَل مرسومةٌ — نافذةُ الإقلاع يرسمها أندرويد قبل Flutter '
            'فلا تُصوَّر من داخل التطبيق. والأخيرةُ مصوَّرةٌ من الشيفرة المدفوعة.',
            style: _label.copyWith(fontSize: 13, color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _panel(
                caption: 'اليوم',
                note: 'بياضُ النظام.\nوالكريمُ المكتوبُ لا يراه جهازٌ حديث.',
                screen: _chrome(ink: Colors.black, body: Container(color: Colors.white)),
              ),
              const SizedBox(width: 20),
              _panel(
                caption: '(أ) نبيذيٌّ وحدَه',
                note: 'لونٌ واحدٌ بلا صورة — أهونُ تبديلٍ،\nولا خطرَ قصٍّ على أيّ مقاس.',
                screen: _chrome(ink: Colors.white, body: _wine()),
              ),
              const SizedBox(width: 20),
              _panel(
                caption: '(ب) نبيذيٌّ وعليه العلامة',
                note: 'العلامةُ في الوسط بقياس «فرحتي» نفسِه،\nفتبقى في مكانها حين يقلع التطبيق.',
                screen: _chrome(ink: Colors.white, body: _wine(child: _mark(96))),
              ),
              const SizedBox(width: 20),
              _panel(
                caption: '(ج) كريمٌ وعليه الأيقونة',
                note: 'أفتحُ وأهدأ — والأيقونةُ كاملةً بأرضيّتها:\nالعلامةُ وحدَها بيضاءُ فتختفي على الكريم.',
                screen: _chrome(
                  ink: Colors.black,
                  body: Container(
                    color: AppColors.page,
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.memory(_fullIcon,
                            width: 96, height: 96, filterQuality: FilterQuality.medium),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 30),
              _panel(
                caption: 'ثمّ يفتح على هذه',
                note: '`BootScreen` المدفوعة — مصوَّرةٌ لا مرسومة.\nوإليها يجب أن تصل النافذةُ بلا ومضة.',
                screen: const BootScreen(),
              ),
            ],
          ),
        ],
      ),
    );

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
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(backgroundColor: AppColors.surface, body: child),
        ),
      ),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('لوحُ نافذة الإقلاع', (tester) async {
    tester.view.physicalSize = const Size(1660, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(_board()));
    // ولا `pumpAndSettle`: في `BootScreen` مقودٌ يدور بلا انقطاع فلا تسكن.
    await tester.pump(const Duration(milliseconds: 900));
    await _settleImages(tester);
    await tester.pump(const Duration(milliseconds: 400));

    // **ولا يُصدَّق أنّ اللوحَ رُسم: تُسأل الشجرة.**
    expect(find.byType(BootScreen), findsOneWidget, reason: 'الخليّةُ المصوَّرةُ غائبة');
    // علامتان مرسومتان في (ب) و(ج)، وثالثةٌ داخلَ `BootScreen` الحقيقيّة.
    expect(find.byType(Image), findsNWidgets(3), reason: 'العلامةُ لم تُرسم');
    expect(find.text('فرحتي'), findsOneWidget, reason: 'اسمُ الشاشة المصوَّرة غائب');
    expect(find.text('اليوم'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'فاض اللوح');

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/splash-proposal.png');
  });
}
