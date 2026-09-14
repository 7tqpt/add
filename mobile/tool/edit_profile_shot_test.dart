// **تصويرُ ما صار.** لا مقترحَ ولا رسمٌ يشبه: `EditProfileScreen` بعينها من
// الشيفرة المدفوعة، في أربع حالاتٍ تُفتح كلُّها بالضغط الحقيقيّ لا بالرسم.
//
//   SHOTS=<مجلّد> flutter test tool/edit_profile_shot_test.dart
//
// ── والعيوبُ الأربعةُ التي عولجت ────────────────────────────────────────────
//
// **١) «حفظ التعديلات» حيٌّ أبداً** — يُضغط ولم يتغيّر شيء، فيُرسَل طلبٌ
//    إلى الخادم بلا سبب. ولا شيءَ في الشاشة يقول «عندك تعديلٌ لم يُحفظ».
//
// **٢) والخروجُ يمحو ما كُتب صمتاً** — يعدّل اسمَه ثمّ يضغط سهمَ الرجوع،
//    فيذهب ما كتب ولا يُسأل.
//
// **٣) والخطأُ يظهر في القاع لا عند حقله** — «اكتب اسمك كاملاً» سطرٌ أحمرُ
//    فوق زرّ الحفظ، وحقلُ الاسم سليمُ المظهر. فمن رآه لا يعرف أيّ حقلٍ
//    يُصلح، وقد يكون خارجَ الشاشة أصلاً.
//
// **٤) وبطاقةُ البريد تأخذ مساحةَ بطاقةِ التعديل كلِّها** — عنوانٌ وشارةٌ
//    وبريدٌ وثلاثةُ أسطرٍ خافتة، لحقيقةٍ **لا تُعدَّل**. فيزاحم ما لا يُلمَس
//    ما جاء المستخدمُ ليلمسه.
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
import 'package:aras/src/screens/edit_profile.dart';
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

Future<void> _shoot(WidgetTester tester, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shot')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(milliseconds: 400));
}

Session _user() => Session()
  ..userId = 'u1'
  ..email = 'ayman9v9@example.com'
  ..appUserId = 'a1'
  ..loading = false
  ..phoneGate = const PhoneGate(
      required_: true, verified: true, phone: '+967779700561');

// ── لوحُ العرض ───────────────────────────────────────────────────────────────
class _Sheet extends StatelessWidget {
  const _Sheet({required this.cells});
  final List<({String label, String sub, Widget screen})> cells;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFE9E1DB),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final cell in cells)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(
                    width: 340,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2, right: 2),
                          child: Text(cell.label,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                                fontFamilyFallback: arabicFallback,
                              )),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, right: 2),
                          child: Text(cell.sub,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: AppColors.muted,
                                fontFamilyFallback: arabicFallback,
                              )),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(height: 780, child: cell.screen),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

/// **وحدُّ الرسم خارجَ `home`** — الحواراتُ تُدفع في ملّاح `MaterialApp`.
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
      builder: (_, navigator) =>
          RepaintBoundary(key: const ValueKey('shot'), child: navigator!),
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

/// شاشةٌ واحدةٌ تُفتح وتُصوَّر — ولكلِّ لقطةٍ نافذتُها فلا تتلوّث الحالات.
Future<Widget> _open(WidgetTester tester) async {
  await tester.pumpWidget(_wrap(EditProfileScreen(session: _user())));
  await _settle(tester);
  return const SizedBox.shrink();
}

void main() {
  setUpAll(_loadFonts);
  setUp(demoResetProfile);

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  Future<void> shoot(WidgetTester tester, String name) async {
    tester.view.physicalSize = const Size(1080, 2100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await _shoot(tester, '$out/$name');
  }

  testWidgets('١) مطفأٌ ولم يتغيّر شيء', (tester) async {
    tester.view.physicalSize = const Size(1080, 2100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await _open(tester);

    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('save-profile')))
            .onPressed,
        isNull);
    await shoot(tester, 'edit-profile-clean.png');
  });

  testWidgets('٢) وبعد التعديل: شارةٌ وزرٌّ حيّ', (tester) async {
    tester.view.physicalSize = const Size(1080, 2100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await _open(tester);

    await tester.enterText(find.byType(TextField).first, 'أيمن محمد الشرعبي');
    await _settle(tester);
    expect(find.text('تعديلٌ لم يُحفظ'), findsOneWidget);
    await shoot(tester, 'edit-profile-dirty.png');
  });

  testWidgets('٣) والخطأُ عند حقله', (tester) async {
    tester.view.physicalSize = const Size(1080, 2100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await _open(tester);

    await tester.enterText(find.byType(TextField).first, 'ع');
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('save-profile')));
    await _settle(tester);
    await shoot(tester, 'edit-profile-error.png');
  });

  testWidgets('٤) والخروجُ يسأل', (tester) async {
    tester.view.physicalSize = const Size(1080, 2100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await _open(tester);

    await tester.enterText(find.byType(TextField).first, 'اسمٌ آخر');
    await _settle(tester);
    tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await _settle(tester);

    expect(find.text('تخرج ولم تحفظ؟'), findsOneWidget);
    await shoot(tester, 'edit-profile-leave.png');
  });
}
