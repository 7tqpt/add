// **مقترحٌ لا تنفيذ.** صورةُ العميل في «آراء العملاء».
//
//   FACES=<مجلّد> SHOTS=<مجلّد> flutter test tool/review_avatar_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «أريد آراء العملاء صورة تظهر» — ومعها لقطةٌ فيها رأيٌ عليه حرفُ «ا».
//
// ── ولماذا هي حروفٌ اليوم — وليست عطباً في الشاشة ─────────────────────────
//
// `class Review` في `models.dart` ليس فيها حقلُ صورةٍ أصلاً، و`providerReviews`
// تطلب خمسةَ أعمدةٍ فقط: `id, user_name, rating, comment, created_at`.
// و`ProviderAvatar` تُعطى الاسمَ وحدَه بلا `imageUrl` — فترسم الحرف.
//
// **ولو أُضيف العمودُ لما وصل**: صورةُ العميل في `app_users.avatar_path`،
// وسياستُها صريحةٌ — «العميل يرى ويعدّل حسابه هو، لا يرى حسابات غيره
// إطلاقاً». فصفحةُ المزوّد يفتحها غيرُ صاحب الرأي أبداً.
//
// **وهي حالةُ صورة المحادثات بعينها**، وطريقُها هو الذي أقرّه من قبل:
// دالّةٌ `security definer` تُسمّي أعمدتَها ولا تُخرج بريداً ولا جوّالاً،
// وحدُّها شرطٌ واحدٌ في `where`.
//
// ── وما في هذه اللوحة حقيقيٌّ وما هو مرسوم ────────────────────────────────
//
// **حقيقيّ:** `AppCard` و`ProviderAvatar` و`Rating` و`Muted` بثيمة التطبيق،
// والآراءُ من `demoReviewsOf('p2')` بنصّها.
//
// **ومرسومٌ يُقال:** صفُّ الرأي مُعادُ البناء — `_Reviews` صنفٌ خاصٌّ داخل
// `provider_public.dart` لا يُستورد. وهو نفسُه سطراً بسطر.
//
// **ومرسومةٌ أيضاً وجوهُ العملاء**: لا صورةَ عميلٍ حقيقيّةَ في الشجرة، فهذه
// أشكالٌ مصنوعةٌ تقوم مقامَها لتُرى الصورةُ في القرص.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/i18n.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
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
//
// **ولا يكفي `HttpOverrides.global`:** حزمةُ الاختبار تلفّ جسمَ الاختبار في
// `HttpOverrides.runZoned` بعميلها الذي يردّ ‎400‎، والنطاقُ أولى من العامّ.
// فيُبدَّل `debugNetworkImageHttpClientProvider` — وهو البابُ الذي فتحته
// فلاتر لهذا بعينه.
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
        home: Scaffold(
          backgroundColor: AppColors.surface2,
          body: Directionality(textDirection: TextDirection.rtl, child: child),
        ),
      ),
    );

/// صفُّ الرأي كما هو في `provider_public.dart` — **مُعادُ البناء** لأنّ
/// `_Reviews` صنفٌ خاصٌّ لا يُستورد. والودجتاتُ فيه هي المشحونةُ بحرفها.
Widget _card(Review r, {String? photo, required double size}) => AppCard(
      children: [
        Row(
          children: [
            ProviderAvatar(name: r.userName, imageUrl: photo, size: size),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(
                r.userName.isEmpty ? tr('عميل') : r.userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
            Rating(r.rating),
          ],
        ),
        if (r.comment.isNotEmpty) ...[
          const SizedBox(height: Space.sm),
          Text(r.comment, style: const TextStyle(height: 1.7, fontSize: 13.5)),
        ],
        const SizedBox(height: Space.xs),
        Muted(formatDate(r.createdAt), size: 11),
      ],
    );

/// و(ج): الصورةُ أكبرُ والاسمُ والتاريخُ مصفوفان بجانبها.
Widget _stacked(Review r, {String? photo}) => AppCard(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProviderAvatar(name: r.userName, imageUrl: photo, size: 44),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.userName.isEmpty ? tr('عميل') : r.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Muted(formatDate(r.createdAt), size: 11),
                ],
              ),
            ),
            Rating(r.rating),
          ],
        ),
        if (r.comment.isNotEmpty) ...[
          const SizedBox(height: Space.sm),
          Text(r.comment, style: const TextStyle(height: 1.7, fontSize: 13.5)),
        ],
      ],
    );

Widget _head(String number, String name, String note) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                number,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  fontFamilyFallback: arabicFallback,
                ),
              ),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    fontFamilyFallback: arabicFallback,
                  ),
                ),
              ),
            ],
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
        ],
      ),
    );

const _faces = ['a.png', 'b.png', 'c.png'];
String _url(int i) => 'https://x.invalid/${_faces[i]}';

void main() {
  setUpAll(() async {
    await _loadFonts();
    // بدونها يرمي أوّل تاريخٍ يُعرض `LocaleDataException`.
    await initFormatting();
    final dir = Platform.environment['FACES'] ?? '';
    if (dir.isEmpty) {
      throw StateError('FACES=<مجلّد> لازمة — ولا صورةَ تُعرض بلا صورة');
    }
    _images = {
      for (final f in _faces) f: File('$dir/$f').readAsBytesSync(),
    };
    debugNetworkImageHttpClientProvider = () => _Client();
  });

  tearDownAll(() => debugNetworkImageHttpClientProvider = null);

  testWidgets('اللوح', (tester) async {
    tester.view.physicalSize = const Size(1080, 3400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final rows = demoReviewsOf('p2');
    expect(rows.length, greaterThanOrEqualTo(2), reason: 'لا آراءَ تُعرض');

    // **والثالثُ بلا صورة** — من لم يرفع صورتَه يبقى حرفاً، وهذا يجب أن يُرى
    // في اللوحة لا أن يُوعد به.
    const noPhoto = Review(
      id: 'r-none',
      userName: 'سالم الحَداد',
      rating: 4,
      comment: 'خدمةٌ طيّبة — ولم يرفع صاحبُ هذا الرأي صورةً لحسابه.',
      createdAt: '2026-06-02T10:00:00Z',
    );

    await tester.pumpWidget(_wrap(ListView(
      padding: const EdgeInsets.only(bottom: Space.lg),
      children: [
        _head('اليوم:', 'حرفٌ في قرصٍ نبيذيّ', 'وهو ما شكا منه — الصورةُ لا تصل أصلاً'),
        for (final r in rows.take(2))
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
            child: _card(r, size: 30),
          ),
        _head('(أ)', 'الصورةُ مكانَ الحرف بقياسه', 'أقلُّ تغييرٍ — القرصُ ٣٠ كما هو'),
        for (var i = 0; i < 2; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
            child: _card(rows[i], photo: _url(i), size: 30),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
          child: _card(noPhoto, size: 30),
        ),
        _head('(ب)', 'الصورةُ أكبرَ — ٤٠', 'تُرى الوجوهُ، والصفُّ يتنفّس'),
        for (var i = 0; i < 2; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
            child: _card(rows[i], photo: _url(i), size: 40),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
          child: _card(noPhoto, size: 40),
        ),
        _head('(ج)', 'الصورةُ ٤٤ والتاريخُ تحت الاسم', 'كبطاقات التقييم في التطبيقات الحديثة'),
        for (var i = 0; i < 2; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
            child: _stacked(rows[i], photo: _url(i)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
          child: _stacked(noPhoto),
        ),
      ],
    )));

    // **و`pumpAndSettle` لا تُنزِل صورةً.** الوقتُ في الاختبار مصنوع، وفكُّ
    // ترميز الصورة عملٌ حقيقيٌّ خارجَه — فيُفتح `runAsync` ليجري.
    await tester.runAsync(() async {
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        await precacheImage(image.image, tester.element(find.byType(Image).first));
      }
    });
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'فاض اللوحُ عن الشاشة');

    // **ولا يُصدَّق أنّ الصورَ وصلت لأنّ الحزمةَ خضراء.** القرصُ الساقطُ إلى
    // الحرف مساحةٌ مصمتةٌ بلون واحد، فتُقاس صورةٌ واحدةٌ من اللوحة: لو كانت
    // مصمتةً فاللقطةُ تكذب وتُقال حرفاً وتُعرض صورةً.
    expect(find.byType(Image), findsNWidgets(6),
        reason: 'عددُ الصور في اللوحة تبدّل');

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/review-avatar.png');
  });
}
