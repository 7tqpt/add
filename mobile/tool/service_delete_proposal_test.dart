// **مقترحٌ لا تنفيذ.** «ضيف لي زرّ حذف في البطاقة المعروضة تحت الصور
// والمقاطع» — يُعرض قبل أن يُلمَس `lib/`.
//
//   SHOTS=<مجلّد> flutter test tool/service_delete_proposal_test.dart
//
// ── ما هو مصوَّرٌ وما هو مرسوم ───────────────────────────────────────────────
//
// **الخليّةُ الأولى مصوَّرةٌ من الشيفرة المدفوعة** — `ServicesScreen` بعينها
// بخدمةٍ من وضع العرض. وهي البطاقةُ كما هي اليومَ: «تعديل» و«إيقاف»
// و«الصور والمقاطع» ولا حذف.
//
// **والخلايا الثلاثُ الباقيةُ مرسومةٌ ويُقال** — الزرُّ غيرُ منفَّذٍ بعد.
// لكنّها مبنيّةٌ ببطاقة التطبيق نفسِها (`AppCard`) وأزراره وألوانه
// (`AppColors.critical`)، لا بصناديقَ ملوَّنة.
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

Future<void> _shoot(WidgetTester tester, Finder of, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(of);
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

/// بطاقةٌ مرسومةٌ على شكل البطاقة المشحونة، وفيها زرُّ الحذف المقترح.
///
/// **وأعلى البطاقة منسوخٌ من الشاشة لا مخترَع:** الشارةُ والاسمُ والسعرُ
/// والعربونُ وصفُّ «تعديل/إيقاف» و«الصور والمقاطع» — كي يُقارَن الزرُّ
/// الجديدُ بما فوقه لا بفراغ.
class _Card extends StatelessWidget {
  const _Card({required this.delete});

  /// زرُّ الحذف المقترح — أو `null` فلا حذف.
  final Widget? delete;

  @override
  Widget build(BuildContext context) => AppCard(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: SectionTitle(tr('قاعة التاج'))),
              const SizedBox(width: Space.sm),
              StatusBadge(tr('معروضة'), color: AppColors.good),
            ],
          ),
          const SizedBox(height: Space.xs),
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
                child: OutlinedButton(
                    onPressed: () {}, child: Text(tr('تعديل'))),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: OutlinedButton(
                    onPressed: () {}, child: Text(tr('إيقاف'))),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          FilledButton.tonalIcon(
            onPressed: () {},
            icon: const Icon(Icons.perm_media_outlined, size: 19),
            label: Text(tr('الصور والمقاطع')),
          ),
          if (delete != null) ...[
            const SizedBox(height: Space.sm),
            delete!,
          ],
        ],
      );
}

/// (أ) زرٌّ محاطٌ بلون الخطر، بعرض البطاقة.
final _optionA = OutlinedButton.icon(
  onPressed: () {},
  style: OutlinedButton.styleFrom(
    foregroundColor: AppColors.critical,
    side: const BorderSide(color: AppColors.critical),
  ),
  icon: const Icon(Icons.delete_outline, size: 19),
  label: Text(tr('حذف الخدمة')),
);

/// (ب) سطرٌ نصّيٌّ خافتٌ في القاع.
final _optionB = TextButton.icon(
  onPressed: () {},
  style: TextButton.styleFrom(foregroundColor: AppColors.critical),
  icon: const Icon(Icons.delete_outline, size: 18),
  label: Text(tr('حذف الخدمة')),
);

/// (ج) زرٌّ ممتلئٌ بلون الخطر.
final _optionC = FilledButton.icon(
  onPressed: () {},
  style: FilledButton.styleFrom(backgroundColor: AppColors.critical),
  icon: const Icon(Icons.delete_outline, size: 19),
  label: Text(tr('حذف الخدمة')),
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
              for (var i = 0; i < cells.length; i++)
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
                            cells[i].label,
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
                            cells[i].sub,
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
                          child: SizedBox(
                            key: ValueKey('cell$i'),
                            height: 620,
                            child: cells[i].screen,
                          ),
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

Widget _page(Widget child) => ColoredBox(
      color: AppColors.page,
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(mainAxisSize: MainAxisSize.min, children: [child]),
      ),
    );

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
  });

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('اللوح', (tester) async {
    tester.view.physicalSize = const Size(4400, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(_Sheet(cells: [
      (
        label: 'اليوم — ولا حذف',
        sub: 'مصوَّرةٌ من الشيفرة المدفوعة: ServicesScreen بعينها',
        screen: ServicesScreen(session: _provider()),
      ),
      (
        label: '(أ) زرٌّ محاطٌ بلون الخطر',
        sub: 'يُرى ولا يُزاحم — مرسومة',
        screen: _page(_Card(delete: _optionA)),
      ),
      (
        label: '(ب) سطرٌ نصّيٌّ خافت',
        sub: 'أخفتُها — ومن يبحث عنه يجده — مرسومة',
        screen: _page(_Card(delete: _optionB)),
      ),
      (
        label: '(ج) زرٌّ ممتلئٌ أحمر',
        sub: 'أصرخُها — ويُزاحم «الصور والمقاطع» — مرسومة',
        screen: _page(_Card(delete: _optionC)),
      ),
    ])));
    await _settle(tester);

    // **ولا يُصدَّق أنّ البطاقةَ الحقيقيّةَ بُنيت: تُسأل الشجرة.**
    expect(find.byType(ServicesScreen), findsOneWidget);
    expect(find.text('الصور والمقاطع'), findsNWidgets(4));
    expect(find.text('حذف الخدمة'), findsNWidgets(3));
    expect(tester.takeException(), isNull);

    await _shoot(tester, find.byKey(const ValueKey('shot')),
        '$out/service-delete.png');
  });
}
