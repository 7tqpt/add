// **عطبٌ ومُقترَحُ إصلاحه.** غلافُ صفحة الخدمة لا يُضغط.
//
//   FACES=<مجلّد> SHOTS=<مجلّد> flutter test tool/service_cover_tap_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما شكا منه ─────────────────────────────────────────────────────────────
//
// «صورة غير قابلة للضغط هنا» — ومعها لقطةُ صفحة الخدمة وغلافُها في أعلاها.
//
// ── والعطبُ مقيسٌ لا مقدَّر ────────────────────────────────────────────────
//
// في `service_detail.dart` الغلافُ `Hero` حول `SizedBox` حول `MediaThumb`
// أو `_Gallery` — **ولا مستمعَ ضغطٍ في شيءٍ منها**. وصورُ معرض المزوّد
// تُفتح بالضغط منذ جولةٍ سابقة، وشعارُه وغلافُه كذلك؛ فهذه وحدَها بقيت.
//
// ── والمقترحُ: تُفتح كما تُفتح أخواتُها ──────────────────────────────────
//
// `openPhoto` هي التي تُفتح بها صورُ المعرض والشعارُ والغلاف — ملءَ الشاشة،
// تُكبَّر بالإصبعين. فتُوصل بالغلاف هنا. **وإن كان معرضاً مقلَّباً فُتحت
// الصورةُ المعروضةُ الآن لا أوّلُ الصور** — من قلّب إلى الثالثة وضغط يريد
// الثالثة.
//
// ── وما في اللوحة حقيقيٌّ وما هو مرسوم ───────────────────────────────────
//
// **حقيقيّ:** `PhotoViewScreen` المشحونةُ نفسُها — وهي ما سيُفتح — مفتوحةً
// على صورةٍ بالحجم الذي تُفتح به. و`MediaThumb` بثيمة التطبيق.
//
// **ومرسومٌ يُقال:** الصورةُ نفسُها مصنوعةٌ بسكربت (لا صورةَ خدمةٍ حقيقيّةَ
// في الشجرة)، **والشبكةُ مركَّبة**: لا شبكةَ في `flutter test` فيُبدَّل
// `debugNetworkImageHttpClientProvider`.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/i18n.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/ui/kit.dart';
import 'package:aras/src/ui/media.dart';
import 'package:aras/src/ui/photo_view.dart';

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

// ── شبكةٌ مصطنعة ─────────────────────────────────────────────────────────────
late List<int> _bytes;

class _Client implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(url);
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Request implements HttpClientRequest {
  _Request(this.uri);
  @override
  final Uri uri;
  @override
  final HttpHeaders headers = _Headers();
  @override
  Future<HttpClientResponse> close() async => _Response(_bytes);
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Headers implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Response implements HttpClientResponse {
  _Response(this.bytes);
  final List<int> bytes;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(bytes).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

Future<void> _shoot(WidgetTester tester, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shot')));
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

const _url = 'https://x.invalid/a.png';

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

Future<void> _precache(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final image in tester.widgetList<Image>(find.byType(Image))) {
      await precacheImage(image.image, tester.element(find.byType(Image).first));
    }
  });
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    final dir = Platform.environment['FACES'] ?? '';
    if (dir.isEmpty) {
      throw StateError('FACES=<مجلّد> لازمة — ولا صورةَ تُعرض بلا صورة');
    }
    _bytes = File('$dir/a.png').readAsBytesSync();
    debugNetworkImageHttpClientProvider = () => _Client();
  });

  tearDownAll(() => debugNetworkImageHttpClientProvider = null);

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('اليومَ — الغلافُ ساكن', (tester) async {
    tester.view.physicalSize = const Size(1080, 1400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(Scaffold(
      appBar: AppBar(title: Text(tr('تفاصيل الخدمة'))),
      body: Column(
        children: [
          // **بلا مستمعِ ضغط** — كما هو اليوم بحرفه.
          const SizedBox(
            height: 220,
            width: double.infinity,
            child: MediaThumb(url: _url),
          ),
          const SizedBox(height: Space.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Muted(tr('تُضغط فلا يقع شيء — ولا علامةَ تقول ذلك')),
          ),
        ],
      ),
    )));
    await _precache(tester);

    expect(find.byType(GestureDetector), findsNothing,
        reason: 'ثَمّ مستمعُ ضغطٍ — فلا عطبَ يُصوَّر');
    await _shoot(tester, '$out/cover-tap-today.png');
  });

  testWidgets('المقترحُ — ما يفتحه الضغط', (tester) async {
    tester.view.physicalSize = const Size(1080, 1400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // **وهذه `PhotoViewScreen` المشحونةُ نفسُها** — لا رسمٌ يشبهها.
    await tester.pumpWidget(_wrap(const PhotoViewScreen(url: _url)));
    await _precache(tester);

    expect(find.byType(InteractiveViewer), findsOneWidget,
        reason: 'العارضُ بلا تكبيرٍ بالإصبعين');
    await _shoot(tester, '$out/cover-tap-viewer.png');
  });
}
