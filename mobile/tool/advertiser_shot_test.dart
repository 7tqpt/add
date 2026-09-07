// راسمُ لقطاتٍ لاسم صاحب الإعلان — **ليس اختباراً.** يُشغَّل بيدٍ ليُرى
// الفرقُ قبل الدمج، ولا يُدرج في الحزمة (خارج `test/`).
//
//   flutter test tool/advertiser_shot_test.dart
//
// **والبطاقةُ المرسومةُ هي `BannerCard` نفسُها** — لا رسمٌ يشبهها. المستبدَلُ
// وحدَه هو الشبكةُ: حزمةُ الاختبار تردّ ‎400‎ على كلِّ طلب، فتُرسم كلُّ صورةٍ
// مربّعاً رمادياً ولا يُرى الستارُ ولا النصُّ عليه. فتُقدَّم هنا صورتان
// مصنوعتان محلّياً بديلاً عن صورتَي المعلِنَين.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/home.dart';

// ── خطوط ─────────────────────────────────────────────────────────────────────
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
// كلُّ طلبٍ يردّ بايتاتِ ملفٍّ محلّيٍّ بحسب اسم المسار.
//
// **ولا يكفي `HttpOverrides.global`:** حزمةُ الاختبار تلفّ جسمَ الاختبار في
// `HttpOverrides.runZoned` بعميلها الذي يردّ ‎400‎، والنطاقُ أولى من العامّ.
// فيُبدَّل `debugNetworkImageHttpClientProvider` — وهو البابُ الذي فتحته
// فلاتر لهذا بعينه.
late Map<String, List<int>> _images;

class _Client implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(url);
  // ولا تُرفَع: `NetworkImage` تضبط `autoUncompress` وغيرَها، وما لم يُنفَّذ
  // هنا لا أثرَ له في اللقطة.
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
  Future<HttpClientResponse> close() async {
    final key = uri.pathSegments.last;
    return _Response(_images[key] ?? _images.values.first);
  }

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

// ── اللوح ────────────────────────────────────────────────────────────────────
Future<void> _shoot(WidgetTester tester, Finder of, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(of);
  final image = await boundary.toImage(pixelRatio: 3.0);

  // **ولا يُصدَّق أنّ الصورَ وُصلت من غياب أيقونة العطب.** `MediaThumb`
  // ترسم في أثناء التحميل مستطيلاً مصمتاً بلون `surface2` — لا أيقونةَ فيه —
  // فتخرج اللقطةُ ستاراً على فراغٍ وأنا أحسبها صورة. فتُقرأ البكسلات:
  // صفٌّ أفقيٌّ في أعلى اللافتة الأولى، فوق الستار. المصمتُ فرقُه صفر.
  final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final w = image.width;
  final y = (140 * 3.0).round(); // أعلى اللافتة الأولى، فوق حيث يبدأ الستار
  var lo = 255, hi = 0;
  for (var x = (60 * 3.0).round(); x < w - 60 * 3; x += 7) {
    final v = raw!.getUint8((y * w + x) * 4); // القناة الحمراء تكفي
    if (v < lo) lo = v;
    if (v > hi) hi = v;
  }
  expect(hi - lo, greaterThan(12),
      reason: 'اللافتةُ مصمتةٌ — لم تصل الصورة، واللقطةُ تكذب');

  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
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

/// خليّةٌ: عنوانٌ فوقها، ولافتةٌ بمقاسها في التطبيق — ‎٣٦٠×١٩٦‎.
Widget _cell(String label, String note, Color noteColour, PromoBanner banner) =>
    Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                fontFamilyFallback: arabicFallback,
              )),
          const SizedBox(height: 2),
          Text(note,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: noteColour,
                fontFamilyFallback: arabicFallback,
              )),
          const SizedBox(height: 8),
          SizedBox(width: 360, height: 196, child: BannerCard(banner: banner)),
        ],
      ),
    );

void main() {
  setUpAll(() async {
    await _loadFonts();
    final dir = Platform.environment['SHOTS'] ?? '/tmp/shots';
    _images = {
      'hall.png': File('$dir/hall.png').readAsBytesSync(),
      'press.png': File('$dir/press.png').readAsBytesSync(),
    };
    debugNetworkImageHttpClientProvider = () => _Client();
  });

  testWidgets('اسمُ المعلِن', (tester) async {
    tester.view.physicalSize = const Size(1260, 2640);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(Material(
      color: const Color(0xFFE9E1DB),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cell(
              'مزوّدٌ مسجَّل',
              'الاسمُ من حسابه — لا يُكتب بيد',
              AppColors.muted,
              const PromoBanner(
                id: 'a#1',
                imageUrl: 'https://x.invalid/hall.png',
                headline: 'قاعةُ التاج — خصمُ ٢٠٪ لحجوزات رمضان',
                providerId: 'p1',
                providerName: 'قاعة التاج الملكي',
              ),
            ),
            _cell(
              'معلِنٌ لا حسابَ له — قبل',
              'وهذا الذي رأيتَه: صورةٌ لا تقول لمن هي',
              const Color(0xFF9B3B3B),
              const PromoBanner(
                id: 'b#1',
                imageUrl: 'https://x.invalid/press.png',
                headline: 'مطابعُ الصفوة — كروتُ أفراحٍ بخصم ٣٠٪',
              ),
            ),
            _cell(
              'معلِنٌ لا حسابَ له — بعد',
              'الاسمُ مكتوبٌ في حقل «اسم المعلِن» باللوحة',
              const Color(0xFF2E6B4F),
              const PromoBanner(
                id: 'c#1',
                imageUrl: 'https://x.invalid/press.png',
                headline: 'مطابعُ الصفوة — كروتُ أفراحٍ بخصم ٣٠٪',
                providerName: 'مطابع الصفوة',
              ),
            ),
          ],
        ),
      ),
    )));
    // **و`pumpAndSettle` لا تُنزِل صورةً.** الوقتُ في الاختبار مصنوع،
    // وفكُّ ترميز الصورة عملٌ حقيقيٌّ خارجَه — فيُفتح `runAsync` ليجري.
    await tester.runAsync(() async {
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        await precacheImage(image.image, tester.element(find.byType(Image).first));
      }
    });
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.image_outlined), findsNothing,
        reason: 'رُدَّت الصورُ بعطبٍ — واللقطةُ تقول إنّها وصلت');
    expect(find.text('مطابع الصفوة'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'فاض اللوحُ عن الشاشة');

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/advertiser.png');
  });
}
