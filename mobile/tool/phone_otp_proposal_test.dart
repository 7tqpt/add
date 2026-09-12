// **مقترحٌ لا تنفيذ.** «تحقّقٌ من رقم الجوال برمزٍ على واتساب، مرّةً واحدة»
// — يُعرض على صاحب المنصّة قبل أن يُلمَس `lib/`.
//
//   SHOTS=<مجلّد> flutter test tool/phone_otp_proposal_test.dart
//
// **والشاشةُ مبنيّةٌ بعناصر التطبيق وثيمته** — `AppCard` و`FilledButton`
// وحقلُ الرمز بمقاسه ومباعدته كما هو في `auth.dart` اليوم، فما يُرى هو ما
// سيصير. ولا شعارَ واتساب: هو علامةٌ مسجّلةٌ لا نملكها، والاسمُ يكفي.
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
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// **ومتحكّمان خارج `build` يُتلَفان في الختام.**
///
/// كتبتُهما أوّلَ مرّة داخل `build` — `TextEditingController(text: …)` يُخلَق
/// عند كلّ بناءٍ ولا يُتلَف — فوقف التشغيلُ بعد اللقطة الأولى ولم يُخرج
/// الثانية. والشاشةُ المعروضةُ لا تتغيّر بهذا: هو تدبيرُ الراسم لا تصميمُها.
final _empty = TextEditingController();
final _filled = TextEditingController(text: '418027');

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

/// شاشةُ التحقّق المقترحة.
///
/// وحقلُ الرمز بمقاس `auth.dart` ومباعدته نفسِها: `22` و`letterSpacing: 8`
/// و`------` نصّاً إرشاديّاً — فمن أكّد بريده يعرف الشكلَ قبل أن يقرأ.
class _VerifyScreen extends StatelessWidget {
  const _VerifyScreen({required this.filled, required this.cooldown});

  /// أرقامٌ مكتوبةٌ في الحقل — لتُرى الحالتان: فارغٌ وممتلئ.
  final bool filled;

  /// ثوانٍ باقيةٌ قبل أن يُتاح «أعد الإرسال».
  final int cooldown;

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
                'أرسلنا رمزاً على واتساب إلى ‎+967 771 234 567‎. اكتبه هنا.',
                style: const TextStyle(height: 1.8),
              ),
              const SizedBox(height: Space.lg),
              TextField(
                controller: filled ? _filled : _empty,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, letterSpacing: 8),
                decoration: InputDecoration(
                  labelText: tr('رمز التأكيد'),
                  hintText: '------',
                ),
              ),
              const SizedBox(height: Space.lg),
              FilledButton(
                onPressed: filled ? () {} : null,
                child: Text(tr('تأكيد الرقم')),
              ),
              TextButton(
                onPressed: cooldown == 0 ? () {} : null,
                child: Text(cooldown == 0
                    ? 'لم يصلني — أعد الإرسال'
                    : 'أعد الإرسال بعد $cooldown ثانية'),
              ),
              const SizedBox(height: Space.xs),
              Muted('الرقم يُستعمل لتأكيد حجوزاتك والتواصل معك، ولا يُؤكَّد مرّةً ثانية.'),
            ],
          ),
          const SizedBox(height: Space.md),
          TextButton(
            onPressed: () {},
            child: Text(tr('رقمي خطأ — ارجع وبدّله')),
          ),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(_loadFonts);
  tearDownAll(() {
    _empty.dispose();
    _filled.dispose();
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  // **ولا `pumpAndSettle` هنا.** الشاشةُ فيها حقلُ نصّ، ومؤشّرُ الكتابة
  // ينبض أبداً — فمن انتظر سكونَ الإطارات انتظر ما لا يسكن. وقد تعلّق أوّلُ
  // تشغيلٍ عند الشاشة الثانية ولم يُخرج لقطتَها.
  //
  // وإطارانِ يكفيان: لا صورةَ شبكةٍ تُنتظر ولا انتقالَ يُطوى.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('بانتظار الرمز', (tester) async {
    phone(tester);
    await tester.pumpWidget(
        _wrap(const _VerifyScreen(filled: false, cooldown: 45)));
    await settle(tester);

    // **وزرُّ التأكيد مطفأٌ قبل أن يُكتب الرمز.** زرٌّ يُضغط فيردّه الخادمُ
    // بخطأٍ أسوأُ من زرٍّ يقول إنّه غيرُ جاهز.
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'تأكيد الرقم'));
    expect(button.onPressed, isNull);
    // **و«أعد الإرسال» محجوبٌ بمهلة:** كلُّ إرسالٍ رسالةٌ مدفوعةٌ على
    // واتساب، ومن يضغط عشراً يدفع صاحبُ المنصّة عشراً.
    expect(find.textContaining('أعد الإرسال بعد'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/otp-waiting.png');
  });

  testWidgets('والرمزُ مكتوب', (tester) async {
    phone(tester);
    await tester
        .pumpWidget(_wrap(const _VerifyScreen(filled: true, cooldown: 0)));
    await settle(tester);

    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'تأكيد الرقم'));
    expect(button.onPressed, isNotNull);
    expect(find.text('لم يصلني — أعد الإرسال'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/otp-filled.png');
  });
}
