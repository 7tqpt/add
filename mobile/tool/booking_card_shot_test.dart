// **تصويرُ ما صار.** بطاقةُ الحجز في «حجوزاتي» بعد أن صارت كبطاقة الخطّة.
//
//   SHOTS=<مجلّد> flutter test tool/booking_card_shot_test.dart
//
// لا شيءَ هنا مرسوم: `MyBookingsScreen` بعينها ببيانات وضع العرض. وموضعُ
// الصورة فارغٌ لأنّ لا شبكةَ في `flutter test` — وهو ما يراه من فتحها بلا
// اتّصال، لا نقصٌ في البطاقة.
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
import 'package:aras/src/data/api.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/my_bookings.dart';

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

  testWidgets('لقطةُ بطاقة الحجز', (tester) async {
    tester.view.physicalSize = const Size(400, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);

    // **والشبكةُ وحدَها مركَّبة** — بدونها يخرج موضعُ الغلاف فارغاً، وهو حالُ
    // من فتحها بلا اتّصالٍ لا نقصٌ في البطاقة.
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
          child: SizedBox(
            width: 330,
            height: 700,
            child: Scaffold(body: MyBookingsScreen(session: _session())),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // تُمرَّر فوق بطاقة الملخّص إلى أوّل بطاقة حجز.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -150));
    await tester.pumpAndSettle();
    await _settleImages(tester);
    // ولا مؤقّتَ معلّقٌ عند انتهاء الاختبار: `demoDelay` ثلثُ ثانية.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // **ويُسأل عمّا ظهر قبل أن يُصوَّر.**
    expect(find.byType(BookingCard), findsWidgets,
        reason: 'لا بطاقةَ حجزٍ في المشهد — فاللقطةُ لغيرها');

    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('one')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$out/booking-card.png').writeAsBytesSync(png!.buffer.asUint8List());
    });

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'فاضت الشاشة');
  });
}
