// **مقترحٌ لا تنفيذ.** نصُّ المثال في حقل «الاسم الكامل» عند التسجيل.
//
//   SHOTS=<مجلّد> flutter test tool/name_hint_proposal_test.dart
//
// ── ما شكا منه ─────────────────────────────────────────────────────────────
//
// «عند تسجيل حساب جديد، الاسم الكامل — في التكست، شيل النصّ الموجود».
//
// ── والحقلُ فارغٌ، والذي يُرى عنوانُه ─────────────────────────────────────
//
// `_name` في `onboarding.dart` يُنشأ فارغاً ولا يُكتب فيه شيء.
//
// **وظننتُ أوّلَ الأمر أنّ المرئيَّ مثالُ `hintText: tr('محمد الصنعاني')`
// — وكان ظنّاً خاطئاً، صحّحته اللقطة.** فـ`TextField` في ماتيريال لا
// يُظهر المثالَ إلّا بعد أن يطفوَ العنوانُ إلى أعلى (عند اللمس أو الكتابة).
// وقبل ذلك المرئيُّ هو **العنوان** `labelText: tr('الاسم الكامل')` قابعاً
// داخلَ الصندوق. وهو النصُّ الذي يشكو منه.
//
// ولولا أنّ اللوحَ يصوّر الشاشةَ الحقيقيّةَ لَشِلتُ المثالَ ولَبقي ما يراه
// كما هو — ولَقيل «لم يتنفّذ».
//
// ── ما هو مصوَّرٌ وما هو مرسوم ─────────────────────────────────────────────
//
// **خليّةُ «اليوم» مصوَّرةٌ**: `OnboardingScreen` المدفوعةُ بعينها.
//
// **وخليّةُ «بعد» مرسومةٌ ويُقال** — غيرُ منفَّذةٍ بعد. وهي الحقولُ نفسُها
// بثيمة التطبيق (`buildTheme()`)، لا صناديقُ مرسومةٌ بالألوان.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/onboarding.dart';
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

Future<void> _shoot(WidgetTester tester, Finder of, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(of);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

const _label = TextStyle(fontFamily: brandFont, fontFamilyFallback: arabicFallback);

const _pw = 360.0;
const _ph = 560.0;
const _scale = 0.78;

Session _fresh() => Session()
  ..userId = 'u1'
  ..email = 'new@sdd.company'
  ..loading = false;

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
        const SizedBox(height: 10),
        SizedBox(
          width: _pw * _scale,
          child: Text(caption,
              textAlign: TextAlign.center,
              style: _label.copyWith(
                  fontSize: 16, fontWeight: FontWeight.w700, color: captionColour)),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: _pw * _scale,
          child: Text(note,
              textAlign: TextAlign.center,
              style: _label.copyWith(fontSize: 12, color: AppColors.muted, height: 1.45)),
        ),
      ],
    );

/// أشكالُ الحقل الثلاثة — الحقولُ نفسُها بثيمة التطبيق لا صناديقُ مرسومة.
enum _Shape {
  /// عنوانٌ فوقَ الصندوق، والصندوقُ فارغٌ تماماً.
  labelAbove,

  /// مثالٌ باهتٌ داخلَ الصندوق يختفي بأوّل حرف.
  hintOnly,

  /// لا عنوانَ ولا مثال.
  bare,
}

Widget _field(_Shape shape, {required String label, required String hint}) {
  final box = TextField(
    decoration: InputDecoration(
      hintText: shape == _Shape.hintOnly ? hint : null,
    ),
  );
  if (shape != _Shape.labelAbove) return box;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: Muted(label, size: 12),
      ),
      const SizedBox(height: 5),
      box,
    ],
  );
}

Widget _after(_Shape shape) => Container(
      color: AppColors.page,
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: AppCard(
          children: [
            SectionTitle('أهلاً بك'),
            const SizedBox(height: Space.sm),
            const Text('عرّفنا بنفسك لنكمل حجوزاتك ونتواصل معك عند الحاجة.',
                style: TextStyle(height: 1.7)),
            const SizedBox(height: Space.lg),
            _field(shape, label: 'الاسم الكامل', hint: 'محمد الصنعاني'),
            const SizedBox(height: Space.md),
            _field(shape, label: 'رقم الجوال', hint: '+967 7XX XXX XXX'),
          ],
        ),
      ),
    );

Widget _board(Widget live) => Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('حقلُ «الاسم الكامل» عند التسجيل',
              style: _label.copyWith(
                  fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.accent)),
          const SizedBox(height: 3),
          Text(
            'الحقلُ فارغٌ فعلاً، والذي يُرى فيه عنوانُه «الاسم الكامل» — يطفو إلى أعلى '
            'عند الكتابة. واليمنى مصوَّرةٌ من الشيفرة المدفوعة، والثلاثُ الأُخَر مرسومة.',
            style: _label.copyWith(fontSize: 12, color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _panel(
                caption: 'اليوم',
                note: 'العنوانُ داخلَ الصندوق، ويطفو\nإلى أعلى عند الكتابة.',
                captionColour: AppColors.ink,
                screen: live,
              ),
              const SizedBox(width: 20),
              _panel(
                caption: '(أ) العنوانُ فوقَ الصندوق',
                note: 'الصندوقُ فارغٌ تماماً، والعنوانُ\nسطرٌ فوقه لا يتحرّك.',
                captionColour: AppColors.accent,
                screen: _after(_Shape.labelAbove),
              ),
              const SizedBox(width: 16),
              _panel(
                caption: '(ب) مثالٌ باهتٌ بدل العنوان',
                note: '«محمد الصنعاني» يختفي بأوّل حرف.\nأخفُّ، ويذهب العنوانُ مع الكتابة.',
                captionColour: AppColors.accent,
                screen: _after(_Shape.hintOnly),
              ),
              const SizedBox(width: 16),
              _panel(
                caption: '(ج) صندوقٌ فارغٌ تماماً',
                note: 'لا عنوانَ ولا مثال — وثلاثةُ\nصناديقَ فارغةٍ لا يُعرف ما يُكتب فيها.',
                captionColour: AppColors.accent,
                screen: _after(_Shape.bare),
              ),
            ],
          ),
        ],
      ),
    );

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

void main() {
  setUpAll(_loadFonts);

  testWidgets('لوحُ حقل الاسم', (tester) async {
    tester.view.physicalSize = const Size(1260, 660);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final live = SizedBox(
      width: _pw,
      height: _ph,
      child: OnboardingScreen(session: _fresh()),
    );

    await tester.pumpWidget(_wrap(_board(live)));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    // **ولا يُصدَّق أنّ اللوحَ رُسم: تُسأل الشجرة.**
    expect(find.byType(OnboardingScreen), findsOneWidget, reason: 'الخليّةُ الحيّةُ غائبة');
    // **وشاشةُ التسجيل خطوتان**: تُختار الصفةُ أوّلاً («أنا عروس»)، ثمّ
    // تظهر بطاقةُ «أهلاً بك» وفيها الاسمُ والجوال. فتُضغط الأولى وإلّا
    // صُوِّرت شاشةٌ غيرُ المقصودة.
    await tester.tap(find.descendant(
      of: find.byType(OnboardingScreen),
      matching: find.text('أنا عروس'),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    // المثالُ في الحيّةِ وحدَها — والمرسومتان بلا مثالٍ في الاسم.
    // العنوانُ في الحيّةِ و(أ) وحدَهما — و(ب) و(ج) بلا عنوان.
    expect(find.text('الاسم الكامل'), findsNWidgets(2),
        reason: 'العنوانُ غائبٌ عن الشاشة الحيّة — فلا شيءَ يُصوَّر');
    expect(tester.takeException(), isNull, reason: 'فاض اللوح');

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/name-hint.png');
  });
}
