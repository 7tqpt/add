// **مقترحٌ لا تنفيذ.** «المحافظة في «أكمل ملفك» منسدلةٌ لا جدارَ شرائح» —
// يُعرض على صاحب المنصّة قبل أن يُلمَس `lib/`.
//
//   SHOTS=<مجلّد> flutter test tool/onboarding_proposal_test.dart
//
// **واليمينُ شاشةٌ حقيقيّةٌ مصوَّرة** — `OnboardingScreen` نفسُها كما هي على
// الفرع. **واليسارُ هي هي**، والفرقُ حقلُ المحافظة وحده: رُكّب فيه
// `DropdownButtonFormField` الذي في «تقديم خدمة» بثيمة التطبيق، فما يُرى
// هو ما سيصير لا رسمٌ يشبهه.
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
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

Session _session() => Session()
  ..userId = 'u1'
  ..appUserId = null
  ..loading = false;

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

/// النموذجُ المقترح — **نسخةُ الشاشة القائمة وحقلُها مبدَّل**.
///
/// ولا يُستنسخ النموذجُ كلُّه من `onboarding.dart`: ما يُقاس هو الحقلُ في
/// محيطه، فالبقيّةُ نصوصُها ومسافاتُها هي هي.
class _Proposed extends StatelessWidget {
  const _Proposed();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('أكمل ملفك'))),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          AppCard(
            children: [
              SectionTitle(tr('أهلاً بك')),
              const SizedBox(height: Space.sm),
              Text(tr('عرّفنا بنفسك لنكمل حجوزاتك ونتواصل معك عند الحاجة.'),
                  style: const TextStyle(height: 1.7)),
              const SizedBox(height: Space.lg),
              TextField(
                decoration: InputDecoration(
                  labelText: tr('الاسم الكامل'),
                  hintText: tr('محمد الصنعاني'),
                ),
              ),
              const SizedBox(height: Space.md),
              TextField(
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: tr('رقم الجوال'),
                  hintText: '+967 7XX XXX XXX',
                ),
              ),
              const SizedBox(height: Space.md),
              DropdownButtonFormField<String>(
                initialValue: null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr('المحافظة'),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
                hint: Text(tr('اختر محافظتك'),
                    style: const TextStyle(color: AppColors.muted)),
                items: [
                  for (final g in demoGovernorates)
                    DropdownMenuItem<String>(
                        value: g.name,
                        child: Text(g.name, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (_) {},
              ),
              const SizedBox(height: Space.lg),
              FilledButton(onPressed: () {}, child: Text(tr('متابعة'))),
            ],
          ),
          const SizedBox(height: Space.md),
          TextButton(onPressed: () {}, child: Text(tr('تسجيل الخروج'))),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(_loadFonts);

  /// جوالٌ بمقاس جوال — لا لوحٌ طويل: ما يُسأل عنه هو **هل يُرى النموذجُ كلُّه
  /// بلا تمرير**، وشاشةٌ أطولُ من الحقيقة تُجيب بنعمٍ كاذبة.
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('القائم — جدارُ شرائح', (tester) async {
    phone(tester);
    await tester.pumpWidget(_wrap(OnboardingScreen(session: _session())));
    await settle(tester);

    // **والنموذجُ خطوةٌ ثانيةٌ لا أولى.** الشاشةُ تسأل أوّلاً «عروس أم عريس
    // أم مقدّم خدمة»، فلا حقلَ قبل الجواب — وأوّلُ تشغيلٍ خرج بلقطةٍ واحدةٍ
    // لأنّي صوّرتُ الخطوةَ الأولى وسألتُها عن شرائحَ ليست فيها.
    await tester.tap(find.text('أنا عروس'));
    await settle(tester);

    // ولا يُصدَّق أنّ الشاشةَ رُسمت: يُسأل الجدارُ عن نفسه.
    expect(find.text('أكمل ملفك'), findsOneWidget);
    expect(find.byType(PickChip), findsWidgets);
    expect(tester.takeException(), isNull);
    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/onboard-now.png');
  });

  testWidgets('المقترح — منسدلة', (tester) async {
    phone(tester);
    await tester.pumpWidget(_wrap(const _Proposed()));
    await settle(tester);

    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.byType(PickChip), findsNothing);
    expect(find.text('اختر محافظتك'), findsOneWidget);
    // والزرُّ يُرى في الشاشة نفسِها — وهو المقصود.
    expect(find.widgetWithText(FilledButton, 'متابعة'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _shoot(tester, find.byKey(const ValueKey('shot')),
        '$out/onboard-proposed.png');
  });
}
