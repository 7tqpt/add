// **صورةٌ قبل التنفيذ.** بطاقةُ الحجز في «حجوزاتي» — ثلاثُ خلايا.
//
//   SHOTS=<مجلّد> flutter test tool/booking_card_proposal_test.dart
//
// ── ما هو مصوَّرٌ وما هو مرسوم ──────────────────────────────────────────────
//
// **الخليّةُ اليمنى مصوَّرةٌ من التطبيق**: `MyBookingsScreen` بعينها ببيانات
// وضع العرض، مقصوصةً على أوّل بطاقةِ حجز.
//
// **والوسطى واليسرى مرسومتان** — بعناصر التطبيق وثيمته، ومنها `BookingStages`
// و`PercentRing` بأعيانها لا رسمٌ يشبههما. لكنّهما **ليستا في الشجرة**:
// مقترحٌ يُعرض لا شاشةٌ تعمل.
//
// **وموضعُ الصورة فارغٌ في الثلاث** — انظر أدناه.
//
// ── والصورةُ تحتاج القاعدةَ كما احتاجتها في الخطّة ─────────────────────────
//
// `Booking` في `models.dart` **لا تحمل غلافَ خدمتها**، و`myBookings` تقرأ
// `bookings` وحدَها بلا ضمّ. فصورةُ القاعة في هذه البطاقة تحتاج عمودَ
// `cover_path` يُضمّ من `service_media` — كما احتاجته بطاقةُ الخطّة.
// وموضعُها في اللوحين مرسومٌ فارغاً ليُرى الشكلُ، ولا يُدَّعى أنّه يعمل.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/labels.dart';
import 'package:aras/src/screens/my_bookings.dart';
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
  await initializeDateFormatting('ar');
}

const _cw = 340.0;
const _ch = 560.0;

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'c@sdd.company'
  ..appUserId = 'demo-user'
  ..loading = false;

/// بطاقةُ الحجز على هيئة بطاقة الخطّة.
///
/// `keepStages` يُبقي مراحلَ الحجز تحت شريط الدفع.
class _Proposed extends StatelessWidget {
  const _Proposed({required this.booking, required this.keepStages});
  final Booking booking;
  final bool keepStages;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final ratio = b.totalPrice > 0 ? (b.paidAmount / b.totalPrice).clamp(0.0, 1.0) : 0.0;
    final days = daysUntil(b.eventDate);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.hairline),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 152,
              child: Row(
                children: [
                  Expanded(
                    flex: 58,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(b.serviceTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink)),
                          const SizedBox(height: 3),
                          Muted(b.providerName, size: 11.5),
                          const SizedBox(height: 7),
                          _Pill(b.eventTime == null
                              ? formatDate(b.eventDate)
                              : '${formatDate(b.eventDate)} · ${formatTime(b.eventTime)}'),
                          const SizedBox(height: 9),
                          _Countdown(countdownLabel(days)),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 42,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          color: AppColors.surface2,
                          child: const Center(
                            child: Icon(Icons.photo_camera_back_outlined,
                                color: AppColors.muted),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 8,
                          left: 8,
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                bookingStatusLabel(b.status),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: bookingStatusColor(b.status)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.hairline),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.payments_outlined,
                          size: 15, color: AppColors.muted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${formatMoney(b.paidAmount)} من ${formatMoney(b.totalPrice)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: ratio.toDouble(),
                            minHeight: 8,
                            backgroundColor: AppColors.surface2,
                            valueColor:
                                const AlwaysStoppedAnimation(AppColors.accent),
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      PercentRing(
                        value: ratio.toDouble(),
                        label: '${(ratio * 100).round()}٪',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Muted(
                      b.paidAmount >= b.totalPrice
                          ? 'سُدّد كاملاً'
                          : 'بقي ${formatMoney(b.totalPrice - b.paidAmount)}',
                      size: 11,
                    ),
                  ),
                  if (keepStages) ...[
                    const SizedBox(height: Space.md),
                    BookingStages(stages: bookingStages(b)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.muted),
            const SizedBox(width: 5),
            Flexible(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted)),
            ),
          ],
        ),
      );
}

class _Countdown extends StatelessWidget {
  const _Countdown(this.text);
  final String text;

  static final _digits = RegExp(r'\d+');

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    var at = 0;
    for (final m in _digits.allMatches(text)) {
      if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
      spans.add(TextSpan(
          text: m[0],
          style: const TextStyle(
              fontSize: 24, height: 1.1, fontWeight: FontWeight.w700)));
      at = m.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return Text.rich(
      TextSpan(children: spans),
      style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gold),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

Widget _cell(String title, String note, Widget child, {Color? tone}) => Container(
      width: _cw,
      height: _ch,
      color: AppColors.page,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: tone ?? AppColors.ink,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 3),
                Text(note,
                    style: TextStyle(
                        fontSize: 10.5,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('لوحُ مقترح بطاقة الحجز', (tester) async {
    tester.view.physicalSize = const Size(1040, 560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);

    final b = demoBookings.first;

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // **والسقّالةُ ليست زينة**: بلا `Scaffold` لا يسري `fontFamily` من
      // الثيمة على النصّ المرسوم، فتخرج الأرقامُ مربّعاتٍ سوداء.
      home: Scaffold(
        backgroundColor: AppColors.page,
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: RepaintBoundary(
            key: const ValueKey('board'),
            child: Row(
              children: [
                _cell(
                  'اليومَ — مصوَّرةٌ من التطبيق',
                  'عنوانٌ وشارةٌ وسهم، ثمّ المزوّدُ والتاريخُ ومبلغان ورقمُ '
                      'الحجز، ثمّ مراحلُ الحجز.',
                  ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      maxHeight: 1800,
                      child: SizedBox(
                        width: _cw,
                        height: 1800,
                        child: Transform.translate(
                          // تُمرَّر فوق بطاقة الملخّص إلى أوّل بطاقة حجز.
                          offset: const Offset(0, -560),
                          child: MyBookingsScreen(session: _session()),
                        ),
                      ),
                    ),
                  ),
                ),
                _cell(
                  '(أ) كالخطّة، والمراحلُ باقية — مرسومة',
                  'صورةٌ وشارةٌ، والتاريخُ في قرص، والعدُّ التنازليُّ ذهبيّ، '
                      'وشريطُ الدفع بحلقته — ثمّ مراحلُ الحجز تحتها.',
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: _Proposed(booking: b, keepStages: true),
                  ),
                  tone: AppColors.accent,
                ),
                _cell(
                  '(ب) كالخطّة، وتُشال المراحل — مرسومة',
                  'الشكلُ نفسُه بلا شريط المراحل — بطاقةٌ أقصرُ، وحالةُ الحجز '
                      'في شارة الصورة وحدَها.',
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: _Proposed(booking: b, keepStages: false),
                  ),
                  tone: AppColors.accentDeep,
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // **ويُسأل عمّا ظهر قبل أن يُصوَّر.**
    expect(find.text(b.serviceTitle), findsWidgets,
        reason: 'الشاشةُ الحقيقيّةُ لم تُبنَ — فاللوحُ يقابل فراغاً');

    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('board')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$out/booking-card-proposal.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });

    expect(tester.takeException(), isNull, reason: 'فاض اللوح');
  });
}
