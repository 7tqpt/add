// **مقترحٌ لا تنفيذ.** شاشةُ تفصيلِ الحجز.
//
//   SHOTS=<مجلّد> flutter test tool/booking_detail_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «(٢) ابنِ شاشةَ تفصيلِ حجزٍ كاملة: الخطواتُ والمبالغُ والعنوانُ والأزرار».
//
// وسببُها أنّ بطاقةَ «حجوزاتي» لا تُفتح بالضغط، ولا وجهةَ لها أصلاً: هي
// تحمل أفعالَها أزراراً في أسفلها.
//
// ── وسؤالان يقرّرهما هو ───────────────────────────────────────────────────
//
//   ١. **أين تقع الأزرار؟** في آخر الصفحة كما هي اليوم في البطاقة، أم في
//     شريطٍ ثابتٍ أسفلَ الشاشة لا ينزل مع القائمة — فالدفعُ في متناول
//     الإبهام مهما طالت الصفحة.
//   ٢. **وماذا يبقى في البطاقة؟** إن بقيت أزرارُها فالفعلُ في موضعين،
//     وإن نُقلت صارت البطاقةُ ملخّصاً هادئاً يُفتح.
//
// ── وما فيه حقيقيٌّ وما هو مرسوم ─────────────────────────────────────────
//
// **حقيقيّ:** `BookingStages` بمراحلها المحسوبةِ من حجزٍ حقيقيّ
// (`bookingStages`)، و`HeroCard` و`AppCard` و`StatusBadge` و`Muted`
// و`SectionTitle` وأزرارُ الثيمة — كلُّها بثيمة التطبيق.
//
// **ومرسومٌ يُقال:** الشاشةُ نفسُها لا وجودَ لها بعد، فهذه هيئتُها مبنيّةً
// من ودجتات الكِت — لا لقطةٌ لشاشةٍ قائمة.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/i18n.dart';
import 'package:aras/src/core/geo.dart';
import 'package:aras/src/screens/labels.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/ui/booking_stages.dart';
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
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// حجزٌ حقيقيُّ الشكل — ومنه تُحسب المراحلُ بالدالّة المشحونة.
final _booking = Booking(
  id: 'b1',
  reference: 'BK-2026-000318',
  userName: 'أحمد الشرعبي',
  providerName: 'قاعة التاج الملكي',
  serviceTitle: 'قاعة التاج — باقة شاملة',
  eventDate: '2026-11-28',
  eventTime: '20:00',
  address: 'حيّ السنينة — صنعاء، جوار مسجد النور',
  guestsCount: 400,
  status: BookingStatus.confirmed,
  totalPrice: 850000,
  depositAmount: 255000,
  paidAmount: 255000,
  couponCode: 'FARHATI10',
  discountAmount: 50000,
  point: GeoPoint(15.35, 44.20),
  createdAt: '2026-09-01T10:00:00Z',
);

Widget _row(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.muted),
          const SizedBox(width: Space.sm),
          SizedBox(width: 78, child: Muted(label, size: 12)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13.5, height: 1.6, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );

Widget _money(String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Muted(label, size: 12.5)),
          Text(
            value,
            style: TextStyle(
              fontSize: strong ? 15 : 13.5,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              color: strong ? AppColors.accent : AppColors.ink,
            ),
          ),
        ],
      ),
    );

/// الرأسُ النبيذيُّ — الخدمةُ والمزوّدُ والحالةُ والرقم.
Widget _head() => HeroCard(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _booking.serviceTitle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentInk,
                ),
              ),
            ),
            const SizedBox(width: Space.sm),
            StatusBadge(
              bookingStatusLabel(_booking.status),
              color: bookingStatusColor(_booking.status),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _booking.providerName,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.accentInk.withValues(alpha: 0.82),
          ),
        ),
        const SizedBox(height: Space.md),
        Row(
          children: [
            Text(
              '${formatDate(_booking.eventDate)} · ${formatTime(_booking.eventTime)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.accentInk,
              ),
            ),
            const Spacer(),
            Text(
              _booking.reference,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.accentInk.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ],
    );

Widget _stages() => AppCard(
      children: [
        SectionTitle(tr('أين وصل حجزك')),
        const SizedBox(height: Space.md),
        BookingStages(stages: bookingStages(_booking)),
      ],
    );

Widget _amounts() => AppCard(
      children: [
        SectionTitle(tr('المبالغ')),
        const SizedBox(height: Space.md),
        _money(tr('إجمالي الخدمة'), formatMoney(_booking.totalPrice)),
        _money(
          trf('خصمُ الكود {0}', [_booking.couponCode]),
          '− ${formatMoney(_booking.discountAmount)}',
        ),
        _money(tr('العربون المطلوب'), formatMoney(_booking.depositAmount)),
        const Divider(height: Space.lg),
        _money(tr('المدفوع'), formatMoney(_booking.paidAmount), strong: true),
        _money(
          tr('المتبقّي عند التسليم'),
          formatMoney(_booking.totalPrice -
              _booking.discountAmount -
              _booking.paidAmount),
        ),
      ],
    );

Widget _details() => AppCard(
      children: [
        SectionTitle(tr('تفاصيل المناسبة')),
        const SizedBox(height: Space.md),
        _row(Icons.event_outlined, tr('التاريخ'),
            '${formatDate(_booking.eventDate)} · ${formatTime(_booking.eventTime)}'),
        _row(Icons.groups_outlined, tr('الضيوف'), '${_booking.guestsCount}'),
        _row(Icons.place_outlined, tr('العنوان'), _booking.address),
        _row(Icons.schedule_outlined, tr('حُجز في'),
            formatDate(_booking.createdAt.split('T').first)),
        const SizedBox(height: Space.xs),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.map_outlined, size: 18),
          label: Text(tr('افتح الموقع على الخريطة')),
        ),
      ],
    );

List<Widget> _actions() => [
      FilledButton(onPressed: () {}, child: Text(tr('ادفع المتبقّي'))),
      const SizedBox(height: Space.sm),
      OutlinedButton(onPressed: () {}, child: Text(tr('إلغاء الحجز'))),
      const SizedBox(height: Space.xs),
      TextButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.report_gmailerrorred_outlined, size: 19),
        style: TextButton.styleFrom(foregroundColor: AppColors.muted),
        label: Text(tr('عندي مشكلة في هذا الحجز')),
      ),
    ];

/// الشاشةُ المقترَحة — `stickyBar` يضع الأزرارَ في شريطٍ ثابتٍ أسفلَها.
Widget _screen({required bool stickyBar}) => Scaffold(
      backgroundColor: AppColors.surface2,
      appBar: AppBar(title: Text(tr('تفاصيل الحجز'))),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          _head(),
          const SizedBox(height: Space.md),
          _stages(),
          const SizedBox(height: Space.md),
          _amounts(),
          const SizedBox(height: Space.md),
          _details(),
          if (!stickyBar) ...[
            const SizedBox(height: Space.md),
            ..._actions(),
          ],
        ],
      ),
      bottomNavigationBar: !stickyBar
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.hairline)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Muted(tr('المتبقّي عند التسليم'), size: 12)),
                      Text(
                        formatMoney(_booking.totalPrice -
                            _booking.discountAmount -
                            _booking.paidAmount),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.sm),
                  FilledButton(onPressed: () {}, child: Text(tr('ادفع المتبقّي'))),
                ],
              ),
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
        home: Directionality(textDirection: TextDirection.rtl, child: child),
      ),
    );

void main() {
  setUpAll(() async {
    await _loadFonts();
    await initFormatting();
  });

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('(أ) الأزرارُ في آخر الصفحة', (tester) async {
    tester.view.physicalSize = const Size(1080, 2900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(_screen(stickyBar: false)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(BookingStages), findsOneWidget);
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/booking-detail-a.png');
  });

  testWidgets('(ب) شريطٌ ثابتٌ أسفلَ الشاشة', (tester) async {
    tester.view.physicalSize = const Size(1080, 2900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(_screen(stickyBar: true)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/booking-detail-b.png');
  });
}
