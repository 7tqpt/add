// **مقترحٌ لا تنفيذ.** «بعد تأكيد تنفيذ شيل أيقون راسل هدى، خلّه أيقون لون
// أخضر و«تم تنفيذ الحجز»» — يُعرض قبل أن يُلمَس `lib/`.
//
//   SHOTS=<مجلّد> flutter test tool/completed_row_proposal_test.dart
//
// ── ما هو مصوَّرٌ وما هو مرسوم ───────────────────────────────────────────────
//
// **خليّةُ «اليوم» مصوَّرةٌ من الشيفرة المدفوعة** — `RequestsScreen` بعينها
// بحجزٍ منفَّذٍ من وضع العرض، وفيها زرُّ «راسل هدى المقطري» كما هو اليوم.
//
// **والثلاثُ الباقيةُ مرسومةٌ ويُقال** — لم يُنفَّذ شيءٌ بعد. لكنّها مبنيّةٌ
// ببطاقة التطبيق نفسِها وأخضرِه المقيس (`AppColors.good`).
//
// ── وما يُفقده هذا التغيير، ليُقال قبل أن يُختار ─────────────────────────────
//
// زرُّ المراسلة اليومَ على **كلّ** حجزٍ مهما كانت حاله، وفي `requests.dart`
// سطرٌ يشرح لماذا. وإزالتُه بعد التنفيذ تقطع البابَ بين المزوّد والعميل في
// أكثر وقتٍ يُحتاج فيه: العربونُ يُسترجَع، وشيءٌ نُسي في القاعة، وتقييمٌ
// يُسأل عنه. **والمحادثةُ تبقى في «الرسائل»** — لكنّها تبعد خطوتين.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/i18n.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/labels.dart';
import 'package:aras/src/screens/requests.dart';
import 'package:aras/src/ui/kit.dart';

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
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(milliseconds: 400));
}

Session _provider() => Session()
  ..userId = 'u1'
  ..email = 'hall@sdd.company'
  ..appUserId = 'a1'
  ..providerId = 'demo-provider'
  ..loading = false;

// ── الأشكالُ الثلاثة ────────────────────────────────────────────────────────

/// (أ) سطرٌ أخضرُ بأيقونةٍ ونصّ — لا زرَّ ولا أرضيّة.
Widget _rowA() => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, size: 20, color: AppColors.good),
        const SizedBox(width: Space.sm),
        Text(
          tr('تم تنفيذ الحجز'),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.good,
          ),
        ),
      ],
    );

/// (ب) شريطٌ أخضرُ خفيفُ الصبغة بعرض البطاقة.
Widget _barB() => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.good.withValues(alpha: Tint.chip),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 20, color: AppColors.good),
          const SizedBox(width: Space.sm),
          Text(
            tr('تم تنفيذ الحجز'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.good,
            ),
          ),
        ],
      ),
    );

/// (ج) زرٌّ أخضرُ محاطٌ لا يُضغط — بشكل «تأكيد التنفيذ» الذي كان مكانه.
Widget _buttonC() => Container(
      width: double.infinity,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.good),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 19, color: AppColors.good),
          const SizedBox(width: Space.sm),
          Text(
            tr('تم تنفيذ الحجز'),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.good,
            ),
          ),
        ],
      ),
    );

/// جسدُ بطاقةِ حجزٍ منفَّذٍ — منسوخٌ من `requests.dart` لا مخترَع.
List<Widget> _body(Widget tail) => [
      CardTitleBar('خيمة الأفراح',
          badge: bookingStatusLabel(BookingStatus.completed)),
      const SizedBox(height: Space.sm),
      Muted('هدى المقطري · ٣٥٠ ضيفاً'),
      const SizedBox(height: Space.sm),
      const Text('٥ نوفمبر ٢٠٢٦ · ٨:٠٠ م',
          style: TextStyle(fontSize: 14, color: AppColors.ink2)),
      const SizedBox(height: Space.xs),
      Muted('شارع الستين — صنعاء'),
      const SizedBox(height: Space.sm),
      const Text(
        '480,000 ر.ي',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
        ),
      ),
      const SizedBox(height: Space.md),
      tail,
    ];

Widget _page(Widget tail) => ColoredBox(
      color: AppColors.page,
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [AppCard(children: _body(tail))],
        ),
      ),
    );

// ── لوحُ العرض ───────────────────────────────────────────────────────────────
class _Sheet extends StatelessWidget {
  const _Sheet({required this.cells});
  final List<({String label, String sub, Widget screen})> cells;

  static const double _w = 340;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFE9E1DB),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final cell in cells)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(
                    width: _w,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2, right: 2),
                          child: Text(
                            cell.label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                              fontFamilyFallback: arabicFallback,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, right: 2),
                          child: Text(
                            cell.sub,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: AppColors.muted,
                              fontFamilyFallback: arabicFallback,
                            ),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(height: 520, child: cell.screen),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

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
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: RepaintBoundary(key: const ValueKey('shot'), child: child),
      ),
    );

void main() {
  setUpAll(_loadFonts);

  setUp(() {
    demoProviderRequests = [
      Booking(
        id: 'r2',
        reference: 'BK-2026-000524',
        userName: 'هدى المقطري',
        providerName: 'قاعة التاج',
        serviceTitle: 'خيمة الأفراح',
        eventDate: DateTime.now()
            .subtract(const Duration(days: 12))
            .toIso8601String()
            .substring(0, 10),
        eventTime: '20:00',
        address: 'شارع الستين — صنعاء',
        guestsCount: 350,
        status: BookingStatus.completed,
        totalPrice: 480000,
        depositAmount: 144000,
        paidAmount: 480000,
      ),
    ];
  });

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('اللوح', (tester) async {
    tester.view.physicalSize = const Size(4400, 1900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(_Sheet(cells: [
      (
        label: 'اليوم — وزرُّ المراسلة باقٍ',
        sub: 'مصوَّرةٌ من الشيفرة المدفوعة: RequestsScreen بعينها',
        screen: RequestsScreen(session: _provider()),
      ),
      (
        label: '(أ) سطرٌ أخضرُ بأيقونة',
        sub: 'أهدؤها — خبرٌ لا زرّ، وهو ما طلبتَه حرفاً (مرسومة)',
        screen: _page(_rowA()),
      ),
      (
        label: '(ب) شريطٌ أخضرُ مصبوغ',
        sub: 'يملأ مكانَ الزرّ فلا تبدو البطاقةُ ناقصة (مرسومة)',
        screen: _page(_barB()),
      ),
      (
        label: '(ج) زرٌّ أخضرُ محاطٌ لا يُضغط',
        sub: 'بشكل «تأكيد التنفيذ» الذي كان مكانه — ويُغري باللمس (مرسومة)',
        screen: _page(_buttonC()),
      ),
    ])));
    await _settle(tester);

    // **ولا يُصدَّق أنّ الشاشةَ الحقيقيّةَ بُنيت: تُسأل الشجرة.**
    expect(find.byType(RequestsScreen), findsOneWidget);
    expect(find.text('راسل هدى المقطري'), findsOneWidget);
    expect(find.text('تم تنفيذ الحجز'), findsNWidgets(3));
    expect(tester.takeException(), isNull);

    await _shoot(tester, '$out/completed-row.png');
  });
}
