// **صورةٌ قبل التنفيذ.** خيطُ اللُّحمة في بطاقة ملخّص «حجوزاتي».
//
//   SHOTS=<مجلّد> COVER=<صورة> flutter test tool/summary_seam_proposal_test.dart
//
// ── المأخذ ───────────────────────────────────────────────────────────────────
//
// `_FadedCover` تُلاشي الغلافَ بلوحٍ من لون البطاقة فوقه: من `_brand.first`
// صلباً إلى الشفافيّة. ولونُ البطاقة تحتَه **متدرّجٌ قُطريّاً** — فاللونُ
// الصلبُ لا يطابق ما تحته إلّا في ركنٍ واحد، فيقع **خيطٌ رأسيٌّ** عند حدّ
// اللوحين يُرى في الحالين: بغلافٍ وبلا غلاف.
//
// ── ما هو مصوَّرٌ وما هو مرسوم ──────────────────────────────────────────────
//
// **(أ) مصوَّرةٌ كما هي اليوم**: `BookingsSummaryCard` المشحونة بغلاف.
//
// **(ب) نصفُها مصوَّرٌ ونصفُها مرسوم**: البطاقةُ تحتَها هي المشحونةُ بعينها
// (بلا غلافٍ فلا لوحَ تلاشٍ فيها)، ومرسومٌ فوقها **غلافٌ يتلاشى بشفافيّته
// هو** لا بلوحٍ فوقه — `ShaderMask` بـ`BlendMode.dstIn`. فيظهر تدرّجُ
// البطاقة من تحت الصورة كما هو، ولا حدَّ يُرى.
//
// وهو في الشيفرة سطران في `_FadedCover`: يُشال لوحُ التلاشي، ويُلفّ
// `MediaThumb` بـ`ShaderMask`.
//
// **والصورةُ مركَّبةٌ بخوارزميّة** (`make_sample_cover.py`) — لا صورةَ قاعةٍ
// حقيقيّة.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/api.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/my_bookings.dart';
import 'package:aras/src/ui/media.dart';

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

/// **الخليّةُ (ب) — مرسومةٌ فوقَ بطاقةٍ حقيقيّة.**
///
/// البطاقةُ تحتُ هي `BookingsSummaryCard` بملخّصٍ بلا غلاف، والغلافُ فوقها
/// يتلاشى بشفافيّته لا بلوحٍ من لونٍ صلب.
class _Seamless extends StatelessWidget {
  const _Seamless({required this.summary});
  final BookingsSummary summary;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            BookingsSummaryCard(summary: summary),
            PositionedDirectional(
              top: 0,
              bottom: 0,
              end: 0,
              start: 0,
              child: FractionallySizedBox(
                alignment: AlignmentDirectional.centerEnd,
                widthFactor: 0.52,
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => const LinearGradient(
                    begin: AlignmentDirectional.centerStart,
                    end: AlignmentDirectional.centerEnd,
                    colors: [Color(0x00FFFFFF), Color(0xCCFFFFFF)],
                    stops: [0.0, 0.72],
                  ).createShader(rect,
                      textDirection: Directionality.of(context)),
                  child: const MediaThumb(
                    url: 'https://example.invalid/p2/s2/mandi.jpg',
                    icon: Icons.photo_camera_back_outlined,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, right: 2),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                fontFamilyFallback: arabicFallback,
              ),
            ),
          ),
          child,
        ],
      );
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('خيطُ اللُّحمة — (أ) اليوم و(ب) بلا خيط', (tester) async {
    tester.view.physicalSize = const Size(400, 520);
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

    final bare = BookingsSummary.of(demoBookings);
    final withCover = BookingsSummary.of([
      for (final b in demoBookings)
        b.id == bare.next!.id ? b.withCover('p2/s2/mandi.jpg') : b,
    ]);

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
            backgroundColor: const Color(0xFFF3ECE7),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Cell(
                    label: '(أ) اليوم — لوحُ تلاشٍ فوق الصورة',
                    child: BookingsSummaryCard(summary: withCover),
                  ),
                  const SizedBox(height: 18),
                  _Cell(
                    label: '(ب) الصورةُ تتلاشى بشفافيّتها — لا خيط',
                    child: _Seamless(summary: bare),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await _settleImages(tester);

    expect(find.byType(MediaThumb), findsNWidgets(2),
        reason: 'إحدى الخليّتين بلا صورة — فالمقارنةُ لغيرها');

    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('board')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.5);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$out/summary-seam.png').writeAsBytesSync(png!.buffer.asUint8List());
    });

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'فاض اللوح');
  });
}
