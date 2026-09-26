// **صورةٌ قبل التنفيذ.** بطاقةُ الحجز على تصميم صاحب المنصّة — أربعُ خلايا.
//
//   SHOTS=<مجلّد> COVER=<صورة> \
//     flutter test tool/booking_card_redesign_proposal_test.dart
//
// ── ما هو مصوَّرٌ وما هو مرسوم ──────────────────────────────────────────────
//
// **الخليّةُ الأولى مصوَّرةٌ من التطبيق**: `BookingCard` المشحونةُ بعينها.
//
// **والثلاثُ الباقياتُ مرسومةٌ هنا** — ليست في الشجرة. وهي مبنيّةٌ بثيمة
// التطبيق وألوانه ودوالِّ صيغه (`formatDate`، `formatMoney`،
// `bookingStatusLabel`)، وبعناصرَ حقيقيّةٍ حيث أمكن (`BookingStages`،
// `PercentRing`) — لا صناديقَ ملوّنةً تشبهها.
//
// ── وعرضُ الرسم عرضُ الجوال الحقيقيّ ────────────────────────────────────────
//
// **وهذا أهمُّ ما في اللوح.** تصميمُه مرسومٌ على عرضٍ عريض، وصفُّ الحقائق
// فيه أربعةُ أعمدة. وعلى جوالٍ عرضُه ٣٦٠ بكسلاً يصير العمودُ الواحدُ نحوَ
// ثمانين — و«24 أكتوبر 2026» لا يسعها. فرُسمت الخلايا على ٣٦٠ لا على عرض
// التصميم، **ليُرى الضيقُ إن وقع** لا ليُخبَّأ.
//
// **والصورةُ في الغلاف مركَّبةٌ بخوارزميّة** (`make_sample_cover.py`) — لا
// صورةُ عرسٍ حقيقيّة، ولا حقَّ لأحدٍ فيها.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/i18n.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/api.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/labels.dart';
import 'package:aras/src/screens/my_bookings.dart';
import 'package:aras/src/ui/booking_stages.dart';
import 'package:aras/src/ui/kit.dart';
import 'package:aras/src/ui/media.dart';

// ── الخطوط ───────────────────────────────────────────────────────────────────
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

// ── شبكةٌ مركَّبة تردّ صورةً واحدة ───────────────────────────────────────────
class _OneImageHttp extends HttpOverrides {
  _OneImageHttp(this.bytes);
  final Uint8List bytes;

  @override
  HttpClient createHttpClient(SecurityContext? context) => _Client(bytes);
}

class _Client implements HttpClient {
  _Client(this.bytes);
  final Uint8List bytes;

  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(bytes);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _Request(bytes);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Request implements HttpClientRequest {
  _Request(this.bytes);
  final Uint8List bytes;

  @override
  final HttpHeaders headers = _Headers();

  @override
  Future<HttpClientResponse> close() async => _Response(bytes);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Headers implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Response implements HttpClientResponse {
  _Response(this.bytes);
  final Uint8List bytes;

  @override
  int get statusCode => 200;

  @override
  int get contentLength => bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(bytes).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _settleImages(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }
}

// ── قطعُ البطاقة المقترحة — **مرسومةٌ هنا، ليست في الشجرة** ─────────────────

/// شارةُ الحالة: قرصٌ بلون الحالة من `bookingStatusColor` لا بلونٍ مخترع.
class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final c = bookingStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 14, color: c),
          const SizedBox(width: 5),
          Text(
            bookingStatusLabel(status),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: c,
              fontFamilyFallback: arabicFallback,
            ),
          ),
        ],
      ),
    );
  }
}

/// حقيقةٌ واحدة: أيقونةٌ ذهبيّةٌ وعنوانٌ باهتٌ فوق، وقيمةٌ تحت.
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: AppColors.gold),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.muted,
                    fontFamilyFallback: arabicFallback,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              fontFamilyFallback: arabicFallback,
            ),
          ),
        ],
      );
}

class _VLine extends StatelessWidget {
  const _VLine();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 34, color: AppColors.hairline);
}

/// زرّا الذيل: «عرض الحجز» مملوءٌ و«تواصل مع المزوّد» محدَّد.
class _Actions extends StatelessWidget {
  const _Actions();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chevron_right,
                      size: 17, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    tr('عرض الحجز'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamilyFallback: arabicFallback,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent, width: 1.2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded,
                      size: 15, color: AppColors.accent),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      tr('تواصل مع المزوّد'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                        fontFamilyFallback: arabicFallback,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}

/// رأسُ البطاقة المقترحة: غلافٌ صغيرٌ وعنوانٌ ومزوّدٌ وشارةُ حالة.
class _Head extends StatelessWidget {
  const _Head({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 74,
            height: 58,
            child: ColoredBox(
              color: AppColors.surface2,
              child: MediaThumb(
                url: Api.mediaUrl(b.coverPath),
                icon: Icons.photo_camera_back_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                b.serviceTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  fontFamilyFallback: arabicFallback,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.storefront_outlined,
                      size: 13, color: AppColors.gold),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      b.providerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.gold,
                        fontFamilyFallback: arabicFallback,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _StatusChip(b.status),
      ],
    );
  }
}

/// البطاقةُ المقترحة — و`facts` هو محلُّ الخلاف بين الخلايا.
class _Proposed extends StatelessWidget {
  const _Proposed({
    required this.booking,
    required this.facts,
    this.paid = false,
    this.stages = false,
  });

  final Booking booking;
  final Widget facts;
  final bool paid;
  final bool stages;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final ratio = b.totalPrice > 0
        ? (b.paidAmount / b.totalPrice).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Head(booking: b),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.hairline),
          const SizedBox(height: 10),
          facts,
          const SizedBox(height: 12),
          if (paid) ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: AppColors.surface2,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  ),
                ),
                const SizedBox(width: Space.sm),
                PercentRing(
                  value: ratio,
                  label: trf('{0}٪', ['${(ratio * 100).round()}']),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (stages) ...[
            BookingStages(stages: bookingStages(b)),
            const SizedBox(height: 12),
          ],
          const _Actions(),
        ],
      ),
    );
  }
}

// ── صفوفُ الحقائق الثلاثة ───────────────────────────────────────────────────

Widget _factsOneRow(Booking b) => Row(
      children: [
        Expanded(
          child: _Fact(
            icon: Icons.calendar_today_rounded,
            label: tr('التاريخ'),
            value: formatDate(b.eventDate),
          ),
        ),
        const _VLine(),
        Expanded(
          child: _Fact(
            icon: Icons.schedule_rounded,
            label: tr('الوقت'),
            value: formatTime(b.eventTime),
          ),
        ),
        const _VLine(),
        Expanded(
          child: _Fact(
            icon: Icons.confirmation_number_outlined,
            label: tr('رقم الحجز'),
            value: b.reference,
          ),
        ),
        const _VLine(),
        Expanded(
          child: _Fact(
            icon: Icons.payments_outlined,
            label: tr('السعر'),
            value: formatMoney(b.totalPrice),
          ),
        ),
      ],
    );

Widget _factsTwoRows(Booking b) => Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Fact(
                icon: Icons.calendar_today_rounded,
                label: tr('التاريخ'),
                value: formatDate(b.eventDate),
              ),
            ),
            const _VLine(),
            Expanded(
              child: _Fact(
                icon: Icons.schedule_rounded,
                label: tr('الوقت'),
                value: formatTime(b.eventTime),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Divider(height: 1, color: AppColors.hairline),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _Fact(
                icon: Icons.confirmation_number_outlined,
                label: tr('رقم الحجز'),
                value: b.reference,
              ),
            ),
            const _VLine(),
            Expanded(
              child: _Fact(
                icon: Icons.payments_outlined,
                label: tr('السعر'),
                value: formatMoney(b.totalPrice),
              ),
            ),
          ],
        ),
      ],
    );

Widget _factsThree(Booking b) => Row(
      children: [
        Expanded(
          child: _Fact(
            icon: Icons.calendar_today_rounded,
            label: tr('التاريخ'),
            value: formatDate(b.eventDate),
          ),
        ),
        const _VLine(),
        Expanded(
          child: _Fact(
            icon: Icons.schedule_rounded,
            label: tr('الوقت'),
            value: formatTime(b.eventTime),
          ),
        ),
        const _VLine(),
        Expanded(
          child: _Fact(
            icon: Icons.payments_outlined,
            label: tr('السعر'),
            value: formatMoney(b.totalPrice),
          ),
        ),
      ],
    );

// ── اللوح ───────────────────────────────────────────────────────────────────
class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.note, required this.child});
  final String label;
  final String note;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                fontFamilyFallback: arabicFallback,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              note,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.muted,
                fontFamilyFallback: arabicFallback,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('لوحُ بطاقة الحجز المقترحة', (tester) async {
    tester.view.physicalSize = const Size(392, 1580);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);

    final cover = Platform.environment['COVER'];
    if (cover != null && File(cover).existsSync()) {
      HttpOverrides.global = _OneImageHttp(File(cover).readAsBytesSync());
      Api.mediaUrlOverride = (path) => 'https://example.invalid/$path';
    }
    addTearDown(() {
      HttpOverrides.global = null;
      Api.mediaUrlOverride = null;
    });

    // حجزٌ من بيانات العرض، بغلافٍ ليُرى موضعُ الصورة مشغولاً.
    final b = demoBookings.first.withCover('p2/s2/mandi.jpg');

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
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: RepaintBoundary(
          key: const ValueKey('board'),
          child: Scaffold(
            backgroundColor: AppColors.page,
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Cell(
                      label: 'الآن — البطاقةُ المشحونة',
                      note: 'مصوَّرةٌ من التطبيق، لا مرسومة',
                      child: BookingCard(booking: b),
                    ),
                    _Cell(
                      label: '(أ) تصميمُك حرفاً — أربعةُ حقولٍ في صفّ',
                      note: 'بلا شريطِ دفعٍ ولا مراحلَ ولا عدٍّ تنازليّ',
                      child: _Proposed(booking: b, facts: _factsOneRow(b)),
                    ),
                    _Cell(
                      label: '(ب) أربعةُ حقولٍ في صفّين',
                      note: 'العمودُ ضعفُ عرضِه، فلا يُقصّ تاريخٌ ولا رقم',
                      child: _Proposed(booking: b, facts: _factsTwoRows(b)),
                    ),
                    _Cell(
                      label: '(ج) ثلاثةُ حقولٍ + الدفعُ والمراحل',
                      note: 'رقمُ الحجز يعود إلى صفحة الحجز',
                      child: _Proposed(
                        booking: b,
                        facts: _factsThree(b),
                        paid: true,
                        stages: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await _settleImages(tester);

    // **ويُسأل عمّا ظهر قبل أن يُصوَّر.**
    expect(find.byType(BookingCard), findsOneWidget);
    expect(find.byType(_Proposed), findsNWidgets(3));

    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('board')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.5);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$out/booking-card-redesign.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });

    await tester.pumpAndSettle();
    // **ولا يُخبَّأ فيضٌ إن وقع**: الضيقُ في (أ) هو نصفُ السؤال.
    final overflow = tester.takeException();
    if (overflow != null) debugPrint('فيضٌ في اللوح: $overflow');
  });
}
