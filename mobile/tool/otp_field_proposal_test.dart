// **مقترحٌ لا تنفيذ.** حقلُ رمز التأكيد: أربعُ خاناتٍ لا ستّ.
//
//   SHOTS=<مجلّد> flutter test tool/otp_field_proposal_test.dart
//
// وأصلُه أنّ صاحبَ المنصّة أخرج رسالةَ واتساب الواصلة وفيها **رمزٌ من أربع
// خانات**، والحقلُ يعرض `------` — ستَّ شُرَطٍ تقول للعين «اكتب ستّاً».
//
// **واللقطةُ الأولى حقيقيّةٌ مصوَّرة:** `VerifyPhoneScreen` نفسُها في وضع
// العرض، تُضغط فيها «أرسل الرمز» فتنتقل إلى خطوة الكتابة.
// **والثانيةُ مرسومةٌ** — بطاقةٌ بثيمة التطبيق وحقلٌ حقيقيٌّ، والفرقُ
// الشاهدُ وحدَه. ولا تُصوَّر الشاشةُ الثانيةُ من `lib/` لأنّ `lib/` لا
// يُلمس قبل أن يُعرض ويُسأل.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/i18n.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/verify_phone.dart';
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

/// **و`runAsync` هو الفرقُ بين راسمٍ يخرج وراسمٍ يتعلّق.**
///
/// `toImage` يطلب من المحرّك أن يرسم فعلاً، وذلك يحتاج زمناً حقيقيّاً لا
/// زمنَ الاختبار المُصطنَع. فبلا `runAsync` قد تُكتب الصورةُ ثمّ لا ينتهي
/// المسار أبداً. وقد تعلّق ثلاثةُ راسمين في هذه الشجرة قبله، وظُنّ السببُ
/// نبضَ مؤشّر الكتابة — **وليس هو**: الحدُّ الأدنى (حقلُ نصٍّ وحدَه، بلا
/// مؤقّتٍ ولا خطوطٍ ولا شاشة) يتعلّق بلا `runAsync` ويخرج به.
Future<void> _shoot(WidgetTester tester, Finder of, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(of);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Session _session() => Session()
  ..userId = 'u1'
  ..appUserId = 'demo-user'
  ..loading = false
  ..phoneGate = PhoneGate(
    required_: true,
    verified: false,
    phone: '+967781447184',
  );

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

/// المقترح — **حقلٌ حقيقيٌّ بثيمة التطبيق، والفرقُ في الشاهد والحدّ**.
class _Proposed extends StatelessWidget {
  const _Proposed();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('تأكيد رقمك'))),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          AppCard(
            children: [
              SectionTitle(tr('رقمك يؤكَّد مرّةً واحدة')),
              const SizedBox(height: Space.sm),
              Text(
                'أرسلنا رمزاً على واتساب إلى +967781447184. اكتبه هنا.',
                style: const TextStyle(height: 1.8),
              ),
              const SizedBox(height: Space.lg),
              TextField(
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
                maxLength: 4,
                style: const TextStyle(fontSize: 22, letterSpacing: 8),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: tr('رمز التأكيد'),
                  hintText: '----',
                  counterText: '',
                ),
              ),
              const SizedBox(height: Space.md),
              FilledButton(onPressed: () {}, child: Text(tr('تأكيد الرقم'))),
            ],
          ),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(_loadFonts);
  setUp(resetDemoPhoneGate);
  tearDown(resetDemoPhoneGate);

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  // **ولا `pumpAndSettle`:** في الشاشة حقلُ نصّ، ومؤشّرُ الكتابة ينبض فلا
  // تسكن الإطاراتُ أبداً. وقد تعلّق ثلاثةُ راسمين قبله بهذا بعينه.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('القائم — ستُّ شُرَط', (tester) async {
    phone(tester);
    await tester.pumpWidget(_wrap(VerifyPhoneScreen(session: _session())));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('otp-action')));
    await settle(tester);

    expect(find.byKey(const ValueKey('otp-field')), findsOneWidget);
    final field = tester.widget<TextField>(find.byKey(const ValueKey('otp-field')));
    // **وهذا هو المقيس لا الصورة:** الشاهدُ ستُّ شُرَطٍ والرمزُ أربعُ خانات.
    expect(field.decoration!.hintText, '------');
    expect(field.maxLength, isNull);
    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/otp-now.png');

    // **والشاشةُ تُهدَم قبل الخروج.** فيها `Timer.periodic` لعدّاد إعادة
    // الإرسال، و`flutter test` ينتظر المؤقّتاتِ المعلّقةَ فلا ينتهي أبداً —
    // وقد خرجت اللقطةُ وبقي الراسمُ معلّقاً حتى قُتل. و`dispose` يُلغي
    // المؤقّت، ولا يُنادى إلّا إذا خرجت الشاشةُ من الشجرة.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('المقترح — أربعُ شُرَط', (tester) async {
    phone(tester);
    await tester.pumpWidget(_wrap(const _Proposed()));
    await settle(tester);

    expect(find.text('----'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/otp-proposed.png');
  });
}
