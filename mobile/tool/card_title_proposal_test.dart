// **مقترحٌ لا تنفيذ.** «العنوان خلّه ملون نبيذ في بطاقة وخط أبيض… كذا لك في
// الطلبات نفس شيء» — يُعرض قبل أن يُلمَس `lib/`.
//
//   SHOTS=<مجلّد> flutter test tool/card_title_proposal_test.dart
//
// ── ما هو مصوَّرٌ وما هو مرسوم ───────────────────────────────────────────────
//
// **خليّتا «اليوم» مصوَّرتان من الشيفرة المدفوعة** — `ServicesScreen`
// و`RequestsScreen` بعينهما ببياناتٍ من وضع العرض.
//
// **والستُّ الباقيةُ مرسومةٌ ويُقال** — لم يُنفَّذ شيءٌ بعد. لكنّها مبنيّةٌ
// بالبطاقة نفسِها (`Card` بثيمة التطبيق) وألوانِه (`AppColors.accent`
// و`accentDeep` و`accentInk`)، لا بصناديقَ ملوَّنةٍ تشبهها.
//
// ── والشارةُ هي العقدة ──────────────────────────────────────────────────────
//
// `StatusBadge` يرسم «معروضة» بأخضرَ على شفّاف. وأخضرُ على نبيذيٍّ لا
// يُقرأ — ‎١٫٧:١‎. فكلُّ خيارٍ يُدخل الشارةَ في الشريط يُعيد صبغَها أبيضَ،
// وذلك يُفقدها معناها اللونيَّ: «معروضة» و«موقوفة» تصيران بلونٍ واحد.
// وخيارٌ واحدٌ يُبقيها خارجَه بلونها.
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
import 'package:aras/src/screens/services.dart';
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

// ── أشكالُ العنوان الثلاثة ──────────────────────────────────────────────────

/// شارةٌ بيضاءُ لتُقرأ على النبيذيّ — وهي ثمنُ إدخالها في الشريط.
Widget _whiteBadge(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.accentInk),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.accentInk,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

/// (أ) شريطٌ نبيذيٌّ يعلو البطاقةَ من حافةٍ إلى حافة، والشارةُ داخلَه.
Widget _bandA(String title, String badge) => Container(
      width: double.infinity,
      color: AppColors.accent,
      padding: const EdgeInsets.symmetric(
          horizontal: Space.lg, vertical: Space.sm + 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.accentInk,
              ),
            ),
          ),
          const SizedBox(width: Space.sm),
          _whiteBadge(badge),
        ],
      ),
    );

/// (ب) قُرصٌ نبيذيٌّ يحضن العنوانَ وحدَه، والشارةُ باقيةٌ بلونها.
Widget _pillB(String title, String badge, Color badgeColor) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.accentInk,
              ),
            ),
          ),
        ),
        const SizedBox(width: Space.sm),
        StatusBadge(badge, color: badgeColor),
      ],
    );

/// (ج) شريطٌ نبيذيٌّ بعرض السطر داخلَ حشوة البطاقة، والشارةُ داخلَه.
Widget _barC(String title, String badge) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.accentInk,
              ),
            ),
          ),
          const SizedBox(width: Space.sm),
          _whiteBadge(badge),
        ],
      ),
    );

// ── بطاقةٌ مرسومةٌ على شكل المشحونة ─────────────────────────────────────────

/// بطاقةٌ عنوانُها شريطٌ من حافةٍ إلى حافة — تحتاج `Card` بقصٍّ لا `AppCard`.
Widget _bleedCard({required Widget band, required List<Widget> body}) => Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          band,
          Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: body,
            ),
          ),
        ],
      ),
    );

/// جسدُ بطاقة الخدمة — منسوخٌ من `services.dart` لا مخترَع.
List<Widget> _serviceBody() => [
      Muted(tr('قاعة التاج التاريخية')),
      const SizedBox(height: Space.sm),
      const Text(
        '10,000 ر.ي – 100,000 ر.ي · يوم',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
        ),
      ),
      const SizedBox(height: Space.xs),
      Muted(trf('العربون {0}٪', ['30']), size: 11),
      const SizedBox(height: Space.md),
      Row(
        children: [
          Expanded(
              child: OutlinedButton(onPressed: () {}, child: Text(tr('تعديل')))),
          const SizedBox(width: Space.sm),
          Expanded(
              child: OutlinedButton(onPressed: () {}, child: Text(tr('إيقاف')))),
        ],
      ),
      const SizedBox(height: Space.sm),
      FilledButton.tonalIcon(
        onPressed: () {},
        icon: const Icon(Icons.perm_media_outlined, size: 19),
        label: Text(tr('الصور والمقاطع')),
      ),
      const SizedBox(height: Space.sm),
      FilledButton.icon(
        onPressed: () {},
        style: FilledButton.styleFrom(backgroundColor: AppColors.critical),
        icon: const Icon(Icons.delete_outline, size: 19),
        label: Text(tr('حذف الخدمة')),
      ),
    ];

/// جسدُ بطاقة الطلب — منسوخٌ من `requests.dart`.
List<Widget> _requestBody() => [
      Muted('سالم باحميد · ٣٥٠ ضيفاً'),
      const SizedBox(height: Space.sm),
      const Text('١٤ أكتوبر ٢٠٢٦ · ٨:٠٠ م',
          style: TextStyle(fontSize: 14, color: AppColors.ink2)),
      const SizedBox(height: Space.xs),
      Muted('شارع الستين — صنعاء'),
      const SizedBox(height: Space.sm),
      const Text(
        '700,000 ر.ي',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
        ),
      ),
      const SizedBox(height: Space.md),
      Row(
        children: [
          Expanded(child: FilledButton(onPressed: () {}, child: Text(tr('قبول')))),
          const SizedBox(width: Space.sm),
          Expanded(
              child: OutlinedButton(onPressed: () {}, child: Text(tr('اعتذار')))),
        ],
      ),
    ];

Widget _page(Widget child) => ColoredBox(
      color: AppColors.page,
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(mainAxisSize: MainAxisSize.min, children: [child]),
      ),
    );

// ── لوحُ العرض ───────────────────────────────────────────────────────────────
class _Sheet extends StatelessWidget {
  const _Sheet({required this.rows});
  final List<List<({String label, String sub, Widget screen})>> rows;

  static const double _w = 330;
  static const double _h = 560;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFE9E1DB),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final row in rows)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final cell in row)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: SizedBox(
                          width: _w,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 2, right: 2),
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
                                padding:
                                    const EdgeInsets.only(bottom: 8, right: 2),
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
                                child:
                                    SizedBox(height: _h, child: cell.screen),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
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
    demoMyServices = [
      const MyService(
        id: 's1',
        title: 'قاعة التاج',
        description: 'قاعة التاج التاريخية',
        price: 10000,
        priceTo: 100000,
        unit: 'يوم',
        depositPercent: 30,
        categoryId: 'c1',
        isActive: true,
      ),
    ];
    demoProviderRequests = [
      Booking(
        id: 'r1',
        reference: 'BK-2026-000511',
        userName: 'سالم باحميد',
        providerName: 'قاعة التاج',
        serviceTitle: 'قاعة التاج',
        eventDate: DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String()
            .substring(0, 10),
        eventTime: '20:00',
        address: 'شارع الستين — صنعاء',
        guestsCount: 350,
        status: BookingStatus.pendingProvider,
        totalPrice: 700000,
        depositAmount: 210000,
        paidAmount: 0,
      ),
    ];
  });

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('اللوح', (tester) async {
    tester.view.physicalSize = const Size(4300, 3920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final pending = bookingStatusLabel(BookingStatus.pendingProvider);
    final pendingColor = bookingStatusColor(BookingStatus.pendingProvider);

    await tester.pumpWidget(_wrap(_Sheet(rows: [
      // ── صفُّ «خدماتي» ──────────────────────────────────────────────────
      [
        (
          label: 'خدماتي اليوم',
          sub: 'مصوَّرةٌ من الشيفرة المدفوعة: ServicesScreen بعينها',
          screen: ServicesScreen(session: _provider()),
        ),
        (
          label: '(أ) شريطٌ من حافةٍ إلى حافة',
          sub: 'رأسُ البطاقة كلِّه نبيذيّ — والشارةُ بيضاءُ داخلَه (مرسومة)',
          screen: _page(_bleedCard(
            band: _bandA('قاعة التاج', tr('معروضة')),
            body: _serviceBody(),
          )),
        ),
        (
          label: '(ب) قُرصٌ حول العنوان وحدَه',
          sub: 'أخفُّها — والشارةُ تبقى خضراءَ بمعناها (مرسومة)',
          screen: _page(AppCard(children: [
            _pillB('قاعة التاج', tr('معروضة'), AppColors.good),
            const SizedBox(height: Space.xs),
            ..._serviceBody(),
          ])),
        ),
        (
          label: '(ج) شريطٌ داخلَ الحشوة',
          sub: 'بعرض السطر لا البطاقة — والشارةُ بيضاءُ داخلَه (مرسومة)',
          screen: _page(AppCard(children: [
            _barC('قاعة التاج', tr('معروضة')),
            const SizedBox(height: Space.sm),
            ..._serviceBody(),
          ])),
        ),
      ],
      // ── صفُّ «الطلبات» ─────────────────────────────────────────────────
      [
        (
          label: 'الطلبات اليوم',
          sub: 'مصوَّرةٌ من الشيفرة المدفوعة: RequestsScreen بعينها',
          screen: RequestsScreen(session: _provider()),
        ),
        (
          label: '(أ) في الطلبات',
          sub: 'مرسومة',
          screen: _page(_bleedCard(
            band: _bandA('قاعة التاج', pending),
            body: _requestBody(),
          )),
        ),
        (
          label: '(ب) في الطلبات',
          sub: 'مرسومة — والشارةُ تبقى بلون حالتها',
          screen: _page(AppCard(children: [
            _pillB('قاعة التاج', pending, pendingColor),
            const SizedBox(height: Space.xs),
            ..._requestBody(),
          ])),
        ),
        (
          label: '(ج) في الطلبات',
          sub: 'مرسومة',
          screen: _page(AppCard(children: [
            _barC('قاعة التاج', pending),
            const SizedBox(height: Space.sm),
            ..._requestBody(),
          ])),
        ),
      ],
    ])));
    await _settle(tester);

    // **ولا يُصدَّق أنّ الشاشتين الحقيقيّتين بُنيتا: تُسأل الشجرة.**
    expect(find.byType(ServicesScreen), findsOneWidget);
    expect(find.byType(RequestsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _shoot(tester, '$out/card-title.png');
  });
}
