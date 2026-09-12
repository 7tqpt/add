// **مقترحٌ لا تنفيذ.** «المحافظة في «خطة جديدة» منسدلةٌ لا جدارَ شرائح» —
// يُعرض على صاحب المنصّة قبل أن يُلمَس `lib/`.
//
//   SHOTS=<مجلّد> flutter test tool/plan_governorate_proposal_test.dart
//
// **واللقطةُ الأولى حقيقيّةٌ مصوَّرة:** `PlanEditorScreen` نفسُها كما هي على
// الفرع، بعشرين شريحةً تدفع زرَّ «إنشاء الخطة» إلى أسفل الشاشة.
// **والثانيةُ هي هي والفرقُ حقلُ المحافظة وحدَه:** رُكّب فيه
// `DropdownButtonFormField` الذي صار في «أكمل ملفك» بثيمة التطبيق — فما
// يُرى هو ما سيصير لا رسمٌ يشبهه.
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
import 'package:aras/src/screens/plan_editor.dart';
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

/// **و`runAsync` هو الفرقُ بين راسمٍ يخرج وراسمٍ يتعلّق** — `toImage` يطلب
/// رسماً حقيقيّاً من المحرّك، وذلك يحتاج زمناً حقيقيّاً لا زمنَ الاختبار.
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

/// المقترح — **نسخةُ الشاشة القائمة وحقلُ المحافظة مبدَّل**.
class _Proposed extends StatelessWidget {
  const _Proposed();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('خطة جديدة'))),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          AppCard(
            children: [
              TextField(
                controller: TextEditingController(text: tr('خطة العرس')),
                decoration: InputDecoration(
                  labelText: tr('اسم الخطة'),
                  hintText: tr('عرس أحمد ومريم'),
                ),
              ),
              const SizedBox(height: Space.md),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.calendar_today_outlined, size: 20),
                label: Text(tr('اختر تاريخ العرس')),
              ),
              const SizedBox(height: Space.md),
              TextField(
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: tr('عدد الضيوف')),
              ),
              const SizedBox(height: Space.md),
              TextField(
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: tr('الميزانية (ر.ي)'),
                  hintText: '2000000',
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
                hint: Text(tr('اختر محافظة العرس'),
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
              FilledButton(onPressed: () {}, child: Text(tr('إنشاء الخطة'))),
            ],
          ),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(_loadFonts);

  /// جوالٌ بمقاس جوال — والسؤالُ هو **هل يُرى النموذجُ كلُّه بلا تمرير**،
  /// وشاشةٌ أطولُ من الحقيقة تُجيب بنعمٍ كاذبة.
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('الشاشةُ بعد التنفيذ', (tester) async {
    phone(tester);
    await tester.pumpWidget(_wrap(PlanEditorScreen(session: _session())));
    await settle(tester);

    // **وصارت هذه هي الحقيقةَ لا المقترح.** اختار صاحبُ المنصّة (أ)،
    // فسقط الجدارُ وقامت المنسدلة. **والمقيسُ شجرةُ العناصر لا الصورة.**
    expect(find.byType(PickChip), findsNothing);
    expect(find.byKey(const ValueKey('plan-governorate-field')), findsOneWidget);
    expect(find.text('اختر محافظة العرس'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/plan-done.png');
  });

  testWidgets('المقترح — منسدلة', (tester) async {
    phone(tester);
    await tester.pumpWidget(_wrap(const _Proposed()));
    await settle(tester);

    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.byType(PickChip), findsNothing);
    expect(find.text('اختر محافظة العرس'), findsOneWidget);
    // والزرُّ يُرى في الشاشة نفسِها — وهو المقصود.
    expect(find.widgetWithText(FilledButton, 'إنشاء الخطة'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/plan-proposed.png');
  });
}
