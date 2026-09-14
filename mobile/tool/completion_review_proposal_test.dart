// **مقترحٌ لا تنفيذ.** رحلةُ «تأكيد التنفيذ» كما طلبها صاحبُ المنصّة:
//
//   «(ب) خلّه قابل للضغط وعند ضغط يروح للمستحقات.
//    عند ضغط على تأكيد التنفيذ لون أخضر وتظهر له هل أنت متأكد نعم أو لا،
//    وترسل للإدارة لمراجعات تنفيذ الحجز عشان يطلع له تم تنفيذ الحجز.
//    قبل تنفيذ يطلع له مراجعات الإدارة.»
//
//   SHOTS=<مجلّد> flutter test tool/completion_review_proposal_test.dart
//
// ── ما هو مصوَّرٌ وما هو مرسوم ───────────────────────────────────────────────
//
// **خليّةُ «اليوم» مصوَّرةٌ من الشيفرة المدفوعة** — `RequestsScreen` بعينها
// بحجزٍ مؤكَّدٍ من وضع العرض.
//
// **والأربعُ الباقيةُ مرسومةٌ ويُقال** — لم يُنفَّذ شيءٌ بعد، ولا الحوارُ
// حوارٌ حقيقيٌّ يُفتح. لكنّها مبنيّةٌ ببطاقة التطبيق وأزراره وألوانِه
// المقيسة، لا بصناديقَ تشبهها.
//
// ── وما يتغيّر تحت الجلد، ليُقرأ قبل أن يُختار ───────────────────────────────
//
// اليومَ: يضغط المزوّد «تأكيد التنفيذ» فيصير الحجزُ `completed` **في
// اللحظة**، وتزيد مستحقّاتُه، ويُفتح للعميل بابُ التقييم.
//
// وبالمقترح: يصير بينهما **بابُ الإدارة**. والمزوّدُ لا يملك أن يُتمّ حجزَه
// بنفسه — وهذا هو مقصودُ الطلب: **مالٌ لا يُحتسب إلّا بعد أن يراه إنسان.**
// وثمنُه أنّ مستحقّاتِ المزوّد تتأخّر إلى أن يراجع المسؤول، وأنّ بابَ
// التقييم عند العميل يتأخّر معها.
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

// ── قطعُ القاع ──────────────────────────────────────────────────────────────

/// (١) «تأكيد التنفيذ» أخضرُ ممتلئ — وزرُّ المراسلة تحته كما هو اليوم.
///
/// **ويُرسم معه لا بدونه:** بطاقةٌ مرسومةٌ تُسقط زرّاً موجوداً في الشاشة
/// تجعل المقارنةَ كاذبة — يُرى الفرقُ حيث لا فرق.
Widget _greenConfirm() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: () {},
          style: FilledButton.styleFrom(backgroundColor: AppColors.good),
          child: Text(tr('تأكيد التنفيذ')),
        ),
        const SizedBox(height: Space.sm),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.forum_outlined, size: 19),
          label: Text(trf('راسل {0}', ['هدى المقطري'])),
        ),
      ],
    );

/// (٣) «قيد مراجعة الإدارة» — شريطٌ كهرمانيٌّ مصبوغ، وبابُ المراسلة باقٍ.
Widget _underReview() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: Tint.chip),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_top, size: 20, color: AppColors.warning),
              const SizedBox(width: Space.sm),
              Flexible(
                child: Text(
                  tr('قيد مراجعة الإدارة'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.sm),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.forum_outlined, size: 19),
          label: Text(trf('راسل {0}', ['هدى المقطري'])),
        ),
      ],
    );

/// (٤) «تم تنفيذ الحجز» — وقد صار يُضغط ويقود إلى «مستحقّاتي».
///
/// **والسهمُ هو ما يقول إنّه باب.** شريطٌ يُضغط بلا علامةٍ تدلّ عليه لا
/// يعرفه أحد، فيبقى الطريقُ إلى المستحقّات مقفولاً وهو مفتوح.
Widget _doneTappable() => Material(
      color: AppColors.good.withValues(alpha: Tint.chip),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              const Icon(Icons.check_circle, size: 20, color: AppColors.good),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  tr('تم تنفيذ الحجز'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.good,
                  ),
                ),
              ),
              Text(
                tr('مستحقّاتي'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.good,
                ),
              ),
              const Icon(Icons.chevron_left, size: 20, color: AppColors.good),
            ],
          ),
        ),
      ),
    );

/// جسدُ بطاقةِ الحجز — منسوخٌ من `requests.dart` لا مخترَع.
List<Widget> _body(BookingStatus badge, Widget tail) => [
      CardTitleBar('خيمة الأفراح', badge: bookingStatusLabel(badge)),
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

Widget _page(BookingStatus badge, Widget tail, {Widget? over}) => ColoredBox(
      color: AppColors.page,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [AppCard(children: _body(badge, tail))],
            ),
          ),
          if (over != null) ...[
            const Positioned.fill(child: ColoredBox(color: Color(0x8A000000))),
            Positioned.fill(child: Center(child: over)),
          ],
        ],
      ),
    );

/// (٢) السؤال — مرسومٌ على شكل حوار التطبيق، ولا يُفتح فعلاً.
///
/// **وزرُّ «نعم» أخضرُ لا أحمر:** `confirmDanger` المشحونةُ تصبغ زرَّ
/// التأكيد بالأحمر لأنّها للحذف. وهذا ليس حذفاً بل ختمُ عملٍ تمّ.
Widget _askDialog() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('تأكيد التنفيذ'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: Space.md),
              Text(
                tr('هل أنت متأكّد أنّ الحجز نُفِّذ؟ يُرسَل إلى الإدارة '
                    'للمراجعة، وتُحتسب مستحقّاتك بعد موافقتها.'),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: AppColors.ink2,
                ),
              ),
              const SizedBox(height: Space.lg),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(onPressed: () {}, child: Text(tr('لا'))),
              ),
              FilledButton(
                onPressed: () {},
                style: FilledButton.styleFrom(backgroundColor: AppColors.good),
                child: Text(tr('نعم، نُفِّذ')),
              ),
            ],
          ),
        ),
      ),
    );

// ── لوحُ العرض ───────────────────────────────────────────────────────────────
class _Sheet extends StatelessWidget {
  const _Sheet({required this.cells});
  final List<({String label, String sub, Widget screen})> cells;

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
                    width: 340,
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
                          child: SizedBox(height: 560, child: cell.screen),
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
            .subtract(const Duration(days: 2))
            .toIso8601String()
            .substring(0, 10),
        eventTime: '20:00',
        address: 'شارع الستين — صنعاء',
        guestsCount: 350,
        status: BookingStatus.confirmed,
        totalPrice: 480000,
        depositAmount: 144000,
        paidAmount: 480000,
      ),
    ];
  });

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('اللوح', (tester) async {
    tester.view.physicalSize = const Size(5500, 2050);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(_Sheet(cells: [
      (
        label: 'اليوم — زرٌّ محايدٌ ولا سؤال',
        sub: 'مصوَّرةٌ من الشيفرة المدفوعة: RequestsScreen بعينها.\n'
            'ولمسةٌ واحدةٌ تُتمّ الحجزَ وتزيد المستحقّات في اللحظة.',
        screen: RequestsScreen(session: _provider()),
      ),
      (
        label: '١) الزرُّ أخضر',
        sub: 'ختمُ عملٍ تمّ لا خطرٌ يُحذَّر منه — مرسومة',
        screen: _page(BookingStatus.confirmed, _greenConfirm()),
      ),
      (
        label: '٢) ثمّ السؤال',
        sub: 'ويقول ما سيقع: تُرسَل للإدارة، والمستحقّاتُ بعد موافقتها — مرسومة',
        screen: _page(BookingStatus.confirmed, _greenConfirm(),
            over: _askDialog()),
      ),
      (
        label: '٣) قيد مراجعة الإدارة',
        sub: 'ما بين الضغط والموافقة — والحجزُ ما زال «مؤكّد» عند العميل.\n'
            'وبابُ المراسلة باقٍ فالعملُ لم يُختم بعد — مرسومة',
        screen: _page(BookingStatus.confirmed, _underReview()),
      ),
      (
        label: '٤) بعد موافقة الإدارة',
        sub: 'الشريطُ الأخضرُ صار باباً إلى «مستحقّاتي» — والسهمُ يقول ذلك.\n'
            'وبلا سهمٍ لا يعرف أحدٌ أنّه يُضغط — مرسومة',
        screen: _page(BookingStatus.completed, _doneTappable()),
      ),
    ])));
    await _settle(tester);

    // **ولا يُصدَّق أنّ الشاشةَ الحقيقيّةَ بُنيت: تُسأل الشجرة.**
    expect(find.byType(RequestsScreen), findsOneWidget);
    expect(find.text('تأكيد التنفيذ'), findsNWidgets(4));
    expect(find.text('قيد مراجعة الإدارة'), findsOneWidget);
    expect(find.text('تم تنفيذ الحجز'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _shoot(tester, '$out/completion-review.png');
  });
}
