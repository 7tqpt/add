// **تصويرُ ما صار.** بطاقةُ ملخّص «حجوزاتي» على التصميم الذي أرسله صاحبُ
// المنصّة.
//
//   SHOTS=<مجلّد> COVER=<صورة> flutter test tool/bookings_summary_shot_test.dart
//
// ── ما هو مصوَّرٌ وما هو مركَّب ──────────────────────────────────────────────
//
// **البطاقةُ نفسُها مصوَّرةٌ لا مرسومة**: `MyBookingsScreen` بعينها ببيانات
// وضع العرض، مقصوصةً على صدر الشاشة — فيُرى الملخّصُ وتحتَه أوّلُ بطاقةِ حجز.
//
// **والمركَّبُ شيئان، وكلاهما شبكةٌ لا شاشة:**
//
//   ١. `Api.mediaUrlOverride` — لأنّ `Api.mediaUrl` تردّ `null` حين لا تُضبط
//      أسرارُ القاعدة، فلا تُبنى `Image` أصلاً ويخرج لوحُ الغلاف تدرّجاً
//      هادئاً. وذلك حالُ من لا غلافَ لحجزه، لا حالُ من له غلاف.
//   ٢. `HttpOverrides` يردّ بايتاتِ صورةٍ واحدة — وإلّا سقطت `Image.network`
//      إلى `errorBuilder`.
//
// **والصورةُ في اللوح مركَّبةٌ بخوارزميّة** (`make_sample_cover.py`) — لا
// مأخوذةٌ من الشبكة ولا صورةُ قاعةٍ حقيقيّة. وعلى الجهاز موضعُها غلافُ
// **أقرب حجزٍ قادم** من القاعدة.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/api.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/my_bookings.dart';
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

/// **والصورةُ تُفكّ على خيطٍ آخر فتحتاج زمناً حقيقيّاً.**
Future<void> _settleImages(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'c@sdd.company'
  ..appUserId = 'demo-user'
  ..loading = false;

void main() {
  setUpAll(_loadFonts);

  testWidgets('لقطةُ بطاقة الملخّص', (tester) async {
    tester.view.physicalSize = const Size(360, 520);
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
          key: const ValueKey('one'),
          child: Scaffold(body: MyBookingsScreen(session: _session())),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await _settleImages(tester);

    // **ويُسأل عمّا ظهر قبل أن يُصوَّر.**
    expect(find.byType(BookingsSummaryCard), findsOneWidget,
        reason: 'لا بطاقةَ ملخّصٍ في المشهد — فاللقطةُ لغيرها');
    expect(find.byType(BookingCard), findsWidgets,
        reason: 'لا بطاقةَ حجزٍ تحتها — فالسياقُ ناقص');

    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('one')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.5);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$out/bookings-summary.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'فاضت الشاشة');
  });

  // **ولوحُ الغلاف.** في بيانات العرض أقربُ حجزٍ لخدمةٍ بلا صور، فيخرج لوحُ
  // الغلاف تدرّجاً هادئاً — وهو حالٌ صحيحةٌ لكنّها ليست الحالَ كلَّها. فهنا
  // **البطاقةُ نفسُها** (`BookingsSummaryCard` المشحونة، لا رسمٌ يشبهها)
  // مرّتين: أقربُ حجزٍ بغلاف، وأقربُ حجزٍ بلا غلاف.
  testWidgets('لقطةُ البطاقة بغلافٍ وبلا غلاف', (tester) async {
    tester.view.physicalSize = const Size(380, 460);
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
          key: const ValueKey('two'),
          child: Scaffold(
            backgroundColor: const Color(0xFFF3ECE7),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BookingsSummaryCard(summary: withCover),
                  const SizedBox(height: 22),
                  BookingsSummaryCard(summary: bare),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await _settleImages(tester);

    expect(find.byType(BookingsSummaryCard), findsNWidgets(2));
    expect(find.byType(MediaThumb), findsOneWidget,
        reason: 'لوحُ الغلاف لم يبنِ صورةً — فالعلويّةُ لا تُري غلافاً');

    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('two')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.5);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$out/bookings-summary-cover.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'فاضت الشاشة');
  });
}
