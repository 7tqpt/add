// **تصويرُ ما صار.** تبويبُ «التقييمات» في صفحة المزوّد بعد التنفيذ.
//
//   FACES=<مجلّد> SHOTS=<مجلّد> flutter test tool/review_avatar_shot_test.dart
//
// ── وهذه الشاشةُ الحقيقيّةُ لا رسمٌ يشبهها ─────────────────────────────────
//
// `PublicProviderScreen` نفسُها تُبنى وتُفتح على تبويب «التقييمات»، فما في
// اللقطة هو `_Reviews` المشحونةُ بحرفها — لا صفٌّ مُعادُ البناء كما في
// `review_avatar_proposal_test.dart`.
//
// ── وما رُكِّب فيها رُكِّب لأنّ البيئةَ تنقصه ─────────────────────────────
//
//   ١. `Api.avatarUrlOverride` — لا سلّةَ في `flutter test`، فتعود
//      `avatarUrl` بـ`null` أبداً ويبقى الحرفُ مهما صحّت الشيفرة.
//   ٢. `debugNetworkImageHttpClientProvider` — ولا شبكةَ أيضاً. ولا يكفي
//      `HttpOverrides.global`: حزمةُ الاختبار تلفّ الجسمَ في `runZoned`
//      بعميلٍ يردّ ‎400‎، والنطاقُ أولى من العامّ.
//   ٣. **ووجوهُ العملاء أشكالٌ مصنوعةٌ تُولَّد بسكربت** — لا صورةَ عميلٍ
//      حقيقيّةَ في الشجرة. والمسارُ الذي تصل به هو مسارُ بيانات العرض بعينه.
//
// وصاحبُ الرأي الثالثُ («خالد الحداد») بلا صورةٍ في بيانات العرض — فيبقى
// حرفُه في اللقطة، وذلك مقصود.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/api.dart';
import 'package:aras/src/screens/provider_public.dart';
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

// ── شبكةٌ مصطنعة ─────────────────────────────────────────────────────────────
late Map<String, List<int>> _images;

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
  Future<HttpClientResponse> close() async =>
      _Response(_images[uri.pathSegments.last] ?? _images.values.first);
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

Future<void> _shoot(WidgetTester tester, Finder of, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(of);
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
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

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// مساراتُ بيانات العرض — وهي التي تصل `avatarUrl` فعلاً.
const _faces = {
  'demo-u1': 'a.png',
  'demo-u2': 'b.png',
};

void main() {
  setUpAll(() async {
    await _loadFonts();
    await initFormatting();
    final dir = Platform.environment['FACES'] ?? '';
    if (dir.isEmpty) {
      throw StateError('FACES=<مجلّد> لازمة — ولا صورةَ تُعرض بلا صورة');
    }
    _images = {
      for (final f in _faces.values) f: File('$dir/$f').readAsBytesSync(),
    };
    debugNetworkImageHttpClientProvider = () => _Client();
    // المسارُ في بيانات العرض `demo-u1/avatar.jpg` — فيُترجَم إلى وجهٍ مصنوع.
    Api.avatarUrlOverride = (path) =>
        'https://x.invalid/${_faces[path.split('/').first] ?? 'a.png'}';
  });

  tearDownAll(() {
    debugNetworkImageHttpClientProvider = null;
    Api.avatarUrlOverride = null;
  });

  testWidgets('تبويبُ التقييمات', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const PublicProviderScreen(providerId: 'p1')));
    await _settle(tester);
    await tester.tap(find.text('التقييمات'));
    await _settle(tester);

    // **و`pumpAndSettle` لا تُنزِل صورةً.** الوقتُ في الاختبار مصنوع، وفكُّ
    // ترميز الصورة عملٌ حقيقيٌّ خارجَه — فيُفتح `runAsync` ليجري.
    await tester.runAsync(() async {
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        await precacheImage(image.image, tester.element(find.byType(Image).first));
      }
    });
    await _settle(tester);

    expect(find.text('آراء العملاء'), findsOneWidget, reason: 'التبويبُ لم يُفتح');
    // **ولا يُصدَّق أنّ الصورَ وصلت لأنّ الحزمةَ خضراء**: القرصُ يرسم حرفاً
    // بلا شكوى حين يكون الرابطُ فارغاً — واللقطةُ تخرج حروفاً وأنا أحسبها
    // صوراً. فتُعدّ الأقراصُ التي وصلها رابطٌ فعلاً.
    expect(
      tester.widgetList<ProviderAvatar>(find.byType(ProviderAvatar))
          .where((a) => (a.imageUrl ?? '').isNotEmpty)
          .length,
      greaterThanOrEqualTo(2),
      reason: 'لا صورةَ وصلت قرصاً — واللقطةُ تكذب',
    );

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/review-avatar-done.png');
  });
}
