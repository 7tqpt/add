// راسمُ فيديو للغلاف بعد التنفيذ — ليس اختباراً، ولا يُدرج في الحزمة.
//
//   COVER=<صورة> SHOTS=<مجلّد> flutter test tool/cover_scrolls_shot_test.dart
//   ثمّ:  python3 tool/make_gif.py <مجلّد> cover-after.gif 0.6
//
// **ولا شيءَ فيه مرسوم.** المصوَّرُ `ServiceDetailScreen` المدفوعةُ وحدَها،
// ملءَ الإطار، وقائمتُها تُسحب بإصبعٍ لا تُرفع. فما يُرى من مشي الغلاف
// مشيُه هو.
//
// **وصورةُ الغلاف وحدَها مركَّبةٌ بخوارزميّة** (`make_sample_cover.py`): لا
// شبكةَ في `flutter test`، فتُركَّب بـ`HttpOverrides` تردّ بايتاتِ صورةٍ
// واحدة — وبلا صورةٍ يخرج الغلافُ سطحاً باهتاً لا يُرى مشيُه.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/api.dart';
import 'package:aras/src/screens/service_detail.dart';

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
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _Request(bytes);
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
      Stream<List<int>>.value(bytes)
          .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
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

Future<void> _settleImages(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }
}

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

late final Uint8List _coverBytes;

const _frames = 30;

void main() {
  setUpAll(() async {
    await _loadFonts();
    final path = Platform.environment['COVER'] ?? '';
    if (path.isEmpty || !File(path).existsSync()) {
      throw StateError('COVER=<صورة> لازمة — ولا غلافَ يُرى بلا صورة');
    }
    // **ولا يكفي `HttpOverrides.global`**: حزمةُ الاختبار تلفّ جسمَ
    // الاختبار في نطاقٍ له `HttpOverrides` خاصٌّ يردّ بأربعمئة، فيغلب.
    // فيُبدَّل معه بابُ الصور نفسُه. (وهو درسٌ مكتوبٌ في
    // `review_avatar_proposal_test.dart`.)
    _coverBytes = File(path).readAsBytesSync();
    HttpOverrides.global = _OneImageHttp(_coverBytes);
    Api.mediaUrlOverride = (p) => 'https://example.test/$p';
  });

  tearDownAll(() {
    HttpOverrides.global = null;
    Api.mediaUrlOverride = null;
  });

  testWidgets('الغلافُ يمشي مع المحتوى', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    // **ويُوضع داخلَ جسم الاختبار ويُرفع في آخره.** حزمةُ الاختبار تتفقّد
    // متغيّرات تنقيح الرسم **بعد الجسم وقبل `tearDown`**، فترمي إن بقي
    // واحدٌ مضبوطاً. والصورةُ تكون قد فُكَّت وخُبِّئت قبل ذلك.
    debugNetworkImageHttpClientProvider = () => _Client(_coverBytes);
    addTearDown(() => debugNetworkImageHttpClientProvider = null);

    await tester.pumpWidget(_wrap(const ServiceDetailScreen(
      serviceId: 's1',
      coverPath: 'p1/s1/cover.jpg',
    )));
    // ولا `pumpAndSettle`: دوّارُ الانتظار لا يقف حتى تصل البيانات.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await _settleImages(tester);

    final list = find.byType(ListView).first;
    expect(find.byKey(const ValueKey('service-cover-tap')), findsOneWidget,
        reason: 'لا غلافَ يُصوَّر');

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    // **إصبعٌ ممسكةٌ لا سحبةٌ في كلّ إطار**: سحبةٌ قصيرةٌ دون عتبة اللمس
    // تُقرأ ضغطةً فتفتح عارضَ الصور فوق الشاشة.
    final gesture = await tester.startGesture(tester.getCenter(list));
    for (var i = 0; i < _frames; i++) {
      if (i > 0) await gesture.moveBy(const Offset(0, -16));
      await tester.pump(const Duration(milliseconds: 40));
      await _shoot(tester, find.byKey(const ValueKey('shot')),
          '$out/frame_${i.toString().padLeft(3, '0')}.png');
    }
    await gesture.up();
    await tester.pump();

    expect(tester.takeException(), isNull, reason: 'فاضت الشاشة');
    debugNetworkImageHttpClientProvider = null;
  });
}
