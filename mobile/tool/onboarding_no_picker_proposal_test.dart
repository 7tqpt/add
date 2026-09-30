// **مقترحُ حذفِ «من أنت؟»** من «أكمل ملفك» — قبل أن يُلمس `lib/`.
//
//   SHOTS=<مجلّد> flutter test tool/onboarding_no_picker_proposal_test.dart
//
// **الأولى الشاشةُ الحقيقيّة** (`OnboardingScreen`) كما سيراها كلُّ جديدٍ
// بعد الحذف — نموذجُ الاسم والجوال والمحافظة، وهو هو اليوم بعد الاختيار.
// **والثانيةُ مرسومةٌ في الراسم** بثيمة التطبيق وخطوطه: النموذجُ نفسُه وفيه
// حقلٌ رابعٌ «أنا» يحفظ عروساً أو عريساً.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

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
  await initializeDateFormatting('ar');
}

Widget _app(Widget home) => MaterialApp(
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
        child: RepaintBoundary(key: const ValueKey('shot'), child: home),
      ),
    );

Future<void> _shoot(WidgetTester tester, String name) async {
  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
  Directory(out).createSync(recursive: true);
  await tester.runAsync(() async {
    final image = await tester
        .renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')))
        .toImage(pixelRatio: 2.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

/// (ب) — مرسوم: النموذجُ نفسُه وفيه «أنا» منسدلةً فوق الاسم.
class _FormWithRole extends StatelessWidget {
  const _FormWithRole();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('أكمل ملفك')),
        body: ListView(
          padding: const EdgeInsets.all(Space.lg),
          children: [
            AppCard(
              children: [
                const SectionTitle('أهلاً بك'),
                const SizedBox(height: Space.sm),
                const Text(
                  'عرّفنا بنفسك لنكمل حجوزاتك ونتواصل معك عند الحاجة.',
                  style: TextStyle(height: 1.7),
                ),
                const SizedBox(height: Space.lg),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'أنا',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  hint: const Text('عروس أو عريس — اختياريّ',
                      style: TextStyle(color: AppColors.muted)),
                  items: const [
                    DropdownMenuItem(value: 'bride', child: Text('عروس')),
                    DropdownMenuItem(value: 'groom', child: Text('عريس')),
                  ],
                  onChanged: (_) {},
                ),
                const SizedBox(height: Space.md),
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'الاسم الكامل',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                ),
                const SizedBox(height: Space.md),
                const TextField(
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'رقم الجوال',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                ),
                const SizedBox(height: Space.md),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'المحافظة',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  hint: const Text('اختر محافظتك',
                      style: TextStyle(color: AppColors.muted)),
                  items: const [],
                  onChanged: (_) {},
                ),
                const SizedBox(height: Space.lg),
                FilledButton(onPressed: () {}, child: const Text('متابعة')),
              ],
            ),
            const SizedBox(height: Space.md),
            TextButton(onPressed: () {}, child: const Text('تسجيل الخروج')),
          ],
        ),
      );
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('(أ) الشاشةُ الحقيقيّةُ بعد الحذف', (tester) async {
    tester.view.physicalSize = const Size(392, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // (وكانت تُملأ هنا `signUpIntent` لتُتخطّى الصفحة قبل حذفها؛ وبعده
    // يفتح النموذجُ مباشرةً فلا حاجةَ إليها.)
    final session = Session()
      ..userId = 'u9'
      ..email = 'new@sdd.company'
      ..loading = false;

    await tester.pumpWidget(_app(OnboardingScreen(session: session)));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await _shoot(tester, 'onboarding-a');
    expect(tester.takeException(), isNull);
  });

  testWidgets('(ب) مرسوم: وفيه «أنا»', (tester) async {
    tester.view.physicalSize = const Size(392, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const _FormWithRole()));
    await tester.pumpAndSettle();
    await _shoot(tester, 'onboarding-b');
    expect(tester.takeException(), isNull);
  });
}
