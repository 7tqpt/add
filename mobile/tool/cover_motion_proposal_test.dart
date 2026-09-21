// **مقترحٌ لا تنفيذ.** غلافُ صفحة الخدمة: لماذا هو ثابتٌ وكيف يتحرّك.
//
//   COVER=<صورة> SHOTS=<مجلّد> flutter test tool/cover_motion_proposal_test.dart
//   ثمّ:  python3 tool/make_gif.py <مجلّد> cover.gif
//
// يُخرج **إطاراً إطاراً** لا لقطةً واحدة: المطلوبُ حركةٌ لا صورة، وسؤالُ
// صاحب المنصّة نفسُه عن الحركة — «ليش صورة ثابتة؟ أريدها ما تكون ثابتة».
//
// ── وقولُه يحتمل معنيين، فيُعرض كلاهما ─────────────────────────────────────
//
// **الأوّل — ثابتةُ الموضع:** وهو ما تقوله الشيفرة بالحرف. الشاشةُ
// `Column` فيها الغلافُ بارتفاعٍ ثابتٍ (٢٣٠) ثمّ `Expanded` فيه القائمة.
// أي أنّ الغلافَ **خارجَ الممرَّر**: يُمرَّر المحتوى تحته وهو لا يتزحزح
// مهما مُرِّر. وهذا هو المعنى الحرفيُّ لـ«ثابتة».
//
// **والثاني — ساكنةٌ لا حياةَ فيها:** صورةٌ واحدةٌ لا تتحرّك ولا تتبدّل.
//
// فالخلايا: اليومَ كما هو، ثمّ (أ) و(ب) للمعنى الأوّل، و(ج) للثاني.
//
// ── ما هو مصوَّرٌ وما هو مرسوم ─────────────────────────────────────────────
//
// **خليّةُ «اليوم» مصوَّرةٌ من الشيفرة المدفوعة**: `ServiceDetailScreen`
// بعينها، وقائمتُها تُسحب سحباً حقيقيّاً في كلّ إطار. فما يُرى من ثباتِ
// الغلاف ثباتُه هو لا رسمٌ يشبهه.
//
// **والثلاثُ الأُخَر مرسومةٌ ويُقال** — غيرُ منفَّذةٍ بعد. لكنّها مبنيّةٌ
// بعناصر التطبيق وثيمته (`AppCard`، `KeyValue`، `AppColors`)، والصورةُ
// فيها صورةُ الغلاف نفسُها.
//
// **وصورةُ الغلاف مركَّبةٌ بخوارزميّة** (`make_sample_cover.py`) لا مأخوذةٌ
// من الشبكة ولا من خدمةٍ حقيقيّة — ولا شبكةَ في `flutter test` أصلاً،
// فتُركَّب بـ`HttpOverrides` تردّ بايتاتِ صورةٍ واحدة.
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
import 'package:aras/src/ui/kit.dart';

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

const _label = TextStyle(fontFamily: brandFont, fontFamilyFallback: arabicFallback);

// **والجوّالُ يُرسم بمقاسه الحقيقيّ ثمّ يُصغَّر كلُّه.** رسمُ الشاشة في
// صندوقٍ ضيّقٍ يفيض صفوفَها ويكسر تخطيطَها، فيُقرأ اللوحُ عيباً ليس فيها.
// فتُبنى عند ٣٦٠×٦٠٠ — مقاسُ جوّالٍ — ويُصغَّر الناتج.
const _pw = 360.0;
const _ph = 600.0;
const _scale = 0.62;
const _cover = 230.0; // ارتفاعُ الغلاف نفسُه في `ServiceDetailScreen`

late final Uint8List _coverBytes;

Widget _photo({double scale = 1, double shift = 0}) => ClipRect(
      child: Transform.translate(
        offset: Offset(0, shift),
        child: Transform.scale(
          scale: scale,
          child: Image.memory(_coverBytes, fit: BoxFit.cover, width: double.infinity),
        ),
      ),
    );

/// محتوى الصفحة المرسوم — بطاقاتُ التطبيق نفسُها.
List<Widget> _cards() => [
      AppCard(children: [
        const Text('قاعة التاج',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
        const SizedBox(height: 6),
        Muted('قاعة التاج التاريخيّة', size: 11),
      ]),
      const SizedBox(height: 10),
      AppCard(children: [
        SectionTitle('السعر'),
        const SizedBox(height: 4),
        KeyValue('السعر', '10,000 – 100,000 ر.ي'),
        KeyValue('الوحدة', 'يوم'),
        KeyValue('العربون 30٪', '3,000 ر.ي'),
      ]),
      const SizedBox(height: 10),
      AppCard(children: [
        SectionTitle('التفاصيل'),
        const SizedBox(height: 4),
        Muted('قاعةٌ واسعةٌ تتّسع لأربعمئة ضيف، وموقفُ سيّاراتٍ خاصّ.', size: 11),
      ]),
    ];

/// إطارُ الجوّال مع شرحه.
Widget _panel({
  required String caption,
  required String note,
  required Color captionColour,
  required Widget screen,
}) =>
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _pw * _scale,
          height: _ph * _scale,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF3A3A3A), width: 3),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(width: _pw, height: _ph, child: screen),
          ),
        ),
        const SizedBox(height: 9),
        SizedBox(
          width: _pw * _scale,
          child: Text(caption,
              textAlign: TextAlign.center,
              style: _label.copyWith(
                  fontSize: 15, fontWeight: FontWeight.w700, color: captionColour)),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: _pw * _scale,
          child: Text(note,
              textAlign: TextAlign.center,
              style: _label.copyWith(fontSize: 11, color: AppColors.muted, height: 1.45)),
        ),
      ],
    );

/// عمودٌ يُزاح إلى أعلى بلا أن يفيض — الفيضُ يرسم شريطاً أصفرَ يُقرأ عطباً.
Widget _lifted(double up, List<Widget> children) => ClipRect(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        maxHeight: double.infinity,
        child: Transform.translate(
          offset: Offset(0, -up),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    );

/// (أ) الغلافُ داخلَ القائمة — يمشي معها ويخرج.
Widget _scrollsAway(double t) => Container(
      color: AppColors.page,
      child: _lifted(300 * t, [
        SizedBox(height: _cover, child: _photo()),
        Padding(padding: const EdgeInsets.all(14), child: Column(children: _cards())),
      ]),
    );

/// (ب) الغلافُ يتقلّص إلى شريطِ عنوان.
Widget _collapses(double t) {
  final h = _cover - (_cover - 72) * t;
  return Container(
    color: AppColors.page,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: h,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _photo(),
              // ستارةٌ تغمق مع التقلّص ليُقرأ الاسمُ على الصورة.
              Container(color: Colors.black.withValues(alpha: 0.10 + 0.40 * t)),
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Text('قاعة التاج',
                      style: _label.copyWith(
                          fontSize: 15 + 5 * (1 - t),
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _lifted(120 * t, [
            Padding(padding: const EdgeInsets.all(14), child: Column(children: _cards())),
          ]),
        ),
      ],
    ),
  );
}

/// (ج) الغلافُ ثابتُ الموضع والصورةُ تحيا فيه — تكبيرٌ ومَشْيٌ بطيئان.
Widget _breathes(double t) {
  // ذهابٌ وإيابٌ لا قفزةَ في آخره: الحركةُ دائرةٌ تعود من حيث بدأت.
  final v = (1 - (2 * t - 1).abs());
  return Container(
    color: AppColors.page,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: _cover, child: _photo(scale: 1 + 0.12 * v, shift: -10 * v)),
        Expanded(
          child: _lifted(120 * t, [
            Padding(padding: const EdgeInsets.all(14), child: Column(children: _cards())),
          ]),
        ),
      ],
    ),
  );
}

/// لوحُ الخلايا — الحقيقيّةُ تُمرَّر بيدها، والمرسوماتُ بـ[t].
class _Board extends StatelessWidget {
  const _Board({required this.t, required this.live});
  final double t;
  final Widget live;

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.surface,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('غلافُ صفحة الخدمة — لماذا هو ثابت، وكيف يتحرّك',
                style: _label.copyWith(
                    fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.accent)),
            const SizedBox(height: 3),
            Text(
              'اليمنى مصوَّرةٌ من الشيفرة المدفوعة وقائمتُها تُسحب سحباً حقيقيّاً. '
              'والثلاثُ الأُخَر مرسومةٌ — غيرُ منفَّذةٍ بعد — بعناصر التطبيق وثيمته. '
              'وصورةُ الغلاف مركَّبةٌ بخوارزميّة لا مأخوذةٌ من خدمةٍ حقيقيّة.',
              style: _label.copyWith(fontSize: 11.5, color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _panel(
                  caption: 'اليوم',
                  note: 'الغلافُ خارجَ الممرَّر: المحتوى يمشي\nتحته وهو لا يتزحزح.',
                  captionColour: AppColors.ink,
                  screen: live,
                ),
                const SizedBox(width: 26),
                _panel(
                  caption: '(أ) يمشي مع المحتوى',
                  note: 'يدخل القائمةَ نفسَها فيخرج بالتمرير،\nوتتّسع الشاشةُ للتفاصيل.',
                  captionColour: AppColors.accent,
                  screen: _scrollsAway(t),
                ),
                const SizedBox(width: 18),
                _panel(
                  caption: '(ب) يتقلّص إلى شريط',
                  note: 'ينكمش مع التمرير ويصير شريطَ عنوانٍ\nيبقى فيه الاسم. وهو عُرفُ التطبيقات.',
                  captionColour: AppColors.accent,
                  screen: _collapses(t),
                ),
                const SizedBox(width: 18),
                _panel(
                  caption: '(ج) يبقى ويتنفّس',
                  note: 'يبقى في موضعه والصورةُ تكبر وتمشي\nببطءٍ فيه — حركةٌ لا تنقل شيئاً.',
                  captionColour: AppColors.accent,
                  screen: _breathes(t),
                ),
              ],
            ),
          ],
        ),
      );
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
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(backgroundColor: AppColors.surface, body: child),
        ),
      ),
    );

const _frames = 36;

void main() {
  setUpAll(() async {
    await _loadFonts();
    final path = Platform.environment['COVER'] ?? '';
    if (path.isEmpty || !File(path).existsSync()) {
      throw StateError('COVER=<صورة> لازمة — ولا غلافَ يُعرض بلا صورة');
    }
    _coverBytes = File(path).readAsBytesSync();
    HttpOverrides.global = _OneImageHttp(_coverBytes);
    Api.mediaUrlOverride = (p) => 'https://example.test/$p';
  });

  tearDownAll(() {
    HttpOverrides.global = null;
    Api.mediaUrlOverride = null;
  });

  testWidgets('لوحُ حركة الغلاف', (tester) async {
    tester.view.physicalSize = const Size(1240, 560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // **الخليّةُ الحيّةُ تُبنى مرّةً ولا تُعاد**: لو أُعيد بناؤها كلَّ إطارٍ
    // لَعاد تمريرُها إلى الصفر، ولَقيل «الغلافُ ثابتٌ» وهو لم يُمرَّر شيء.
    final live = MediaQuery(
      data: const MediaQueryData(size: Size(_pw, _ph)),
      child: const ServiceDetailScreen(serviceId: 's1', coverPath: 'p1/s1/one.jpg'),
    );
    final t = ValueNotifier<double>(0);

    await tester.pumpWidget(_wrap(ValueListenableBuilder<double>(
      valueListenable: t,
      builder: (context, v, _) => _Board(t: v, live: live),
    )));
    // ولا `pumpAndSettle`: في الشاشة الحقيقيّة دوّارُ انتظارٍ يدور بلا
    // انقطاعٍ حتى تصل البيانات، فلا تسكن الشجرةُ أبداً.
    // وبيانات العرض تصل بعد ٣٠٠ جزءٍ من الثانية، وكلُّ وصولٍ يحتاج إطاراً
    // بعده ليُبنى — فتُدفع الساعةُ مرّاتٍ لا مرّةً.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await _settleImages(tester);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await _settleImages(tester);

    // ولا يُصدَّق أنّ اللوحَ رُسم: تُسأل الشجرة.
    expect(find.byType(ServiceDetailScreen), findsOneWidget, reason: 'الخليّةُ الحيّةُ غائبة');
    expect(find.text('قاعة التاج'), findsWidgets);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    final list = find.descendant(
      of: find.byType(ServiceDetailScreen),
      matching: find.byType(ListView),
    );
    // **والقائمةُ الحقيقيّةُ تُسحب سحباً**: هي وحدَها تقول أيتحرّك الغلافُ
    // أم لا، ولا يُقاس ذلك برسمٍ من عندي.
    //
    // **وإصبعٌ واحدةٌ لا تُرفع، لا سحبةٌ في كلّ إطار.** `drag` بسبعة بكسلاتٍ
    // دون عتبة اللمس، فتُقرأ **ضغطةً** — فُتح بها ملفُّ المزوّد وملأ اللوحَ
    // كلَّه قبل أن أفهم. والإصبعُ الممسكةُ تتجاوز العتبةَ ثمّ تمرّر، ولا
    // تُقرأ ضغطةً أبداً لأنّها لا تُرفع.
    final gesture = await tester.startGesture(tester.getCenter(list.first));
    for (var i = 0; i < _frames; i++) {
      final v = i / (_frames - 1);
      t.value = v;
      if (i > 0) await gesture.moveBy(const Offset(0, -9));
      await tester.pump(const Duration(milliseconds: 40));
      await _shoot(tester, find.byKey(const ValueKey('shot')),
          '$out/frame_${i.toString().padLeft(3, '0')}.png');
    }
    await gesture.up();
    await tester.pump();
    // ولا يُفتح شيءٌ فوق الشاشة: لو قُرئت الإصبعُ ضغطةً لَفُتح ملفُّ المزوّد.
    expect(find.byType(ServiceDetailScreen), findsOneWidget,
        reason: 'فُتحت شاشةٌ فوق الحيّة — قُرئ السحبُ ضغطة');
    expect(tester.takeException(), isNull, reason: 'فاض اللوح');
  });
}
