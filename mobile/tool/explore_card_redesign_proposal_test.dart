// **مقترحُ بطاقةِ الخدمة في «استكشف»** — وجهان، قبل أن يُلمس `lib/`.
//
//   COVER=<صورة> SHOTS=<مجلّد> flutter test tool/explore_card_redesign_proposal_test.dart
//
// **وهذا مرسومٌ في الراسم لا في التطبيق**: البطاقتان تحتهما مبنيّتان هنا،
// لا في `lib/src/ui/service_card.dart`. لكنّ ما رُسم منهما حقيقيّ: ثيمةُ
// التطبيق (`buildTheme()`) وخطوطُه وألوانُه وعناصرُه (`Rating`،
// `VerifiedMark`، `MediaThumb`)، وبياناتُ وضع العرض نفسُها. فما يُرى هنا هو
// ما سيخرج إن قيل «نفّذ».
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
import 'package:aras/src/ui/kit.dart';
import 'package:aras/src/ui/media.dart';
import 'package:aras/src/ui/service_card.dart';

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

String _price(ServiceItem s) => s.priceTo == null
    ? formatMoney(s.price)
    : '${formatMoney(s.price)} – ${formatMoney(s.priceTo!)}';

/// أرقامٌ عربيّةٌ هنديّة — مرسومةٌ في الراسم ليُرى الفرق، والتطبيقُ اليوم
/// يكتب ‎850,000‎ لا ‎٨٥٠٬٠٠٠‎.
String _arabicDigits(String s) => s
    .replaceAllMapped(
        RegExp(r'[0-9]'), (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 48 + 0x0660))
    .replaceAll(',', '٬');

/// سطرُ المزوّد كما في تصميمه: متجرٌ واسمٌ وعلامةٌ ثمّ خطٌّ فاصلٌ ثمّ دبّوسٌ
/// ومحافظة — **ولا قسمَ فيه**، فقد أسقطه من الصورة.
class _Provider extends StatelessWidget {
  const _Provider(this.s);
  final ServiceItem s;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(Icons.storefront_outlined, size: 15, color: AppColors.accent),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              s.providerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ),
          if (s.providerVerified) ...[
            const SizedBox(width: 4),
            const VerifiedMark(size: 15),
          ],
          const SizedBox(width: Space.sm),
          Container(width: 1, height: 13, color: AppColors.hairline),
          const SizedBox(width: Space.sm),
          const Icon(Icons.place_outlined, size: 14, color: AppColors.muted),
          const SizedBox(width: 3),
          Flexible(child: Muted(s.providerGovernorate)),
        ],
      );
}

/// قرصُ القلب فوق الغلاف — أبيضُ شفيفٌ ليُقرأ على أيّ صورة.
class _HeartDisc extends StatelessWidget {
  const _HeartDisc({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.all(Space.sm),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(6),
        child: Icon(
          on ? Icons.favorite : Icons.favorite_border,
          size: 19,
          color: on ? AppColors.accent : AppColors.muted,
        ),
      );
}

/// ── (أ) تصميمُ صاحب المنصّة: غلافٌ بعرض البطاقة وزرٌّ بعرضها ──────────────
class _CardA extends StatelessWidget {
  const _CardA(this.s, {this.favourite = false, this.arabicDigits = false});
  final ServiceItem s;
  final bool favourite;

  /// أرقامٌ عربيّةٌ هنديّة كما في صورته — والتطبيقُ اليوم لاتينيّة.
  final bool arabicDigits;

  String _n(String s) => arabicDigits ? _arabicDigits(s) : s;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 168,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: MediaThumb(url: Api.mediaUrl(s.coverPath)),
                  ),
                  Align(
                    alignment: AlignmentDirectional.topEnd,
                    child: _HeartDisc(on: favourite),
                  ),
                  if (s.providerIsFeatured)
                    Align(
                      alignment: AlignmentDirectional.topStart,
                      child: Padding(
                        padding: const EdgeInsets.all(Space.sm),
                        child: StatusBadge(tr('مميّز'), color: AppColors.warning),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 7),
                  _Provider(s),
                  const SizedBox(height: Space.md),
                  // السعرُ يمينًا والتقييمُ يسارًا في سطرٍ واحد — كما في صورته.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          _n(_price(s)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      if (s.providerRating > 0)
                        Rating(s.providerRating, count: s.providerReviewsCount, size: 13),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Muted(_n(trf('العربون {0}٪', ['${s.depositPercent}'])), size: 12),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(Space.md),
              child: FilledButton(
                onPressed: () {},
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr('عرض التفاصيل'),
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    // **و`arrow_forward_ios` لا `chevron_left`:** هذا يتقلّب مع
                    // اتجاه الشاشة من نفسِه، وذاك ممنوعٌ في الشجرة.
                    const Icon(Icons.arrow_forward_ios, size: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

/// ── (ب) الوسط: غلافٌ مربّعٌ كما هو اليوم، وزرٌّ بعرض البطاقة ───────────────
class _CardB extends StatelessWidget {
  const _CardB(this.s, {this.favourite = false});
  final ServiceItem s;
  final bool favourite;

  @override
  Widget build(BuildContext context) => AppCard(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: MediaThumb(url: Api.mediaUrl(s.coverPath)),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            s.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        Icon(
                          favourite ? Icons.favorite : Icons.favorite_border,
                          size: 20,
                          color: favourite ? AppColors.accent : AppColors.muted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    _Provider(s),
                    const SizedBox(height: Space.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _price(s),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                        if (s.providerRating > 0)
                          Rating(s.providerRating, count: s.providerReviewsCount),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Muted(trf('العربون {0}٪ · {1}', ['${s.depositPercent}', s.unit]), size: 11.5),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
            ),
            child: Text(
              tr('عرض التفاصيل'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
}

/// ── (ج) ما هو اليوم، للمقارنة — بطاقةُ التطبيق نفسُها ─────────────────────
class _CardToday extends StatelessWidget {
  const _CardToday(this.s, {this.favourite = false});
  final ServiceItem s;
  final bool favourite;

  @override
  Widget build(BuildContext context) => ServiceListCard(
        item: s,
        onOpen: () {},
        isFavourite: favourite,
        onToggleFavourite: () {},
        onOpenProvider: () {},
      );
}

Widget _page(String title, List<Widget> cards) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(Space.lg),
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: Space.md),
            for (final c in cards) ...[c, const SizedBox(height: Space.md)],
          ],
        ),
      ),
    );

Future<void> _shoot(WidgetTester tester, String name, Widget page,
    {double height = 1700}) async {
  tester.view.physicalSize = Size(392, height);
  tester.view.devicePixelRatio = 1.0;

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
  Directory(out).createSync(recursive: true);

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
    home: RepaintBoundary(key: const ValueKey('shot'), child: page),
  ));
  await tester.pumpAndSettle();
  // **والصورةُ تُفكّ على خيطٍ آخر فتحتاج زمناً حقيقيّاً.**
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });

  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'فاضت الصفحة');
}

void main() {
  setUpAll(_loadFonts);

  setUp(() {
    final cover = Platform.environment['COVER'];
    if (cover != null && File(cover).existsSync()) {
      HttpOverrides.global = _OneImageHttp(File(cover).readAsBytesSync());
      Api.mediaUrlOverride = (path) => 'https://example.invalid/$path';
    }
  });

  tearDown(() {
    HttpOverrides.global = null;
    Api.mediaUrlOverride = null;
  });

  final three = demoServices.take(3).toList();

  testWidgets('(أ) غلافٌ بعرض البطاقة', (tester) async {
    addTearDown(tester.view.reset);
    await _shoot(
      tester,
      'card-a',
      _page('(أ) تصميمُك — الأولى بأرقامٍ لاتينيّة كما التطبيقُ اليوم، '
          'والثانيةُ بأرقامٍ عربيّةٍ كما في صورتك، والثالثةُ خدمةٌ بلا غلاف', [
        _CardA(three[0], favourite: true),
        _CardA(three[1], arabicDigits: true),
        _CardA(three[2]),
      ]),
      height: 2300,
    );
  });

  testWidgets('(ب) غلافٌ مربّعٌ وزرٌّ بعرض البطاقة', (tester) async {
    addTearDown(tester.view.reset);
    await _shoot(
      tester,
      'card-b',
      _page('(ب) الوسط: الغلافُ مربّعٌ كما هو، والزرُّ يُضاف',
          [for (final s in three) _CardB(s, favourite: s.id == 's1')]),
      height: 1400,
    );
  });

  testWidgets('(ج) ما هو اليوم', (tester) async {
    addTearDown(tester.view.reset);
    await _shoot(
      tester,
      'card-today',
      _page('(ج) ما هو اليوم — للمقارنة',
          [for (final s in three) _CardToday(s, favourite: s.id == 's1')]),
      height: 1200,
    );
  });
}
