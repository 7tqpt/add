// **مقترحٌ لا تنفيذ.** شاشةُ الدخول على شكل التصميم الذي أرسله صاحبُ
// المنصّة — يُعرض عليه قبل أن يُلمَس `lib/`.
//
//   SHOTS=<مجلّد> flutter test tool/auth_proposal_test.dart
//
// **الأولى حقيقيّةٌ مصوَّرة:** `AuthScreen` نفسُها على وجه «الدخول».
// **والثانيةُ مرسومةٌ ويُقال إنّها مرسومة** — نسخةٌ بعناصر التطبيق الحقيقيّة
// وثيمته، على هيئة التصميم المرسَل.
//
// ── وما لا يُرسَم لأنّه ليس عندنا ───────────────────────────────────────────
//
// في التصميم شعارُ «فرحتي» مرسوماً بخطٍّ ذهبيّ. **ولا وجودَ له في المستودع**:
// لا صورةَ مجمّعةٌ في الحزمة أصلاً (`assets:` في `pubspec` معطَّلةٌ كلُّها)،
// وأصولُ العلامة في `assets/brand/` أيقوناتُ تطبيقٍ لا شعارُ سطر. فرُسم
// مكانَه ما في الشاشة اليوم — أيقونةٌ واسمٌ — بأبيضَ على الأرضيّة الحمراء.
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
import 'package:aras/src/screens/auth.dart';
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
Future<void> _shoot(WidgetTester tester, Finder of, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(of);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

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

/// المقترح — **مرسومٌ لا مصوَّر**، وعناصرُه حقيقيّةٌ بثيمة التطبيق.
class _Proposed extends StatelessWidget {
  const _Proposed();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.accent,
      body: Column(
        children: [
          // ── الرأسُ الأحمر ───────────────────────────────────────────────
          //
          // **وثُلثُ الشاشة لا نصفُها.** التصميمُ المرسَل من آيفونَ طويل،
          // ونصفُ الشاشة فيه يبقى للنموذج. وعلى جوالٍ قصيرٍ يدفع الرأسُ
          // النصفيُّ زرَّ «دخول» تحت لوحة المفاتيح.
          SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.celebration_outlined,
                      size: 44, color: AppColors.accentInk),
                  const SizedBox(height: Space.sm),
                  Text(
                    tr('فرحتي'),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentInk,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── النموذجُ على ورقةٍ بيضاء ────────────────────────────────────
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(
                  Space.lg, Space.xl, Space.lg, Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr('دخول الحساب'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink),
                  ),
                  const SizedBox(height: Space.lg),
                  TextField(
                    textDirection: TextDirection.ltr,
                    decoration:
                        InputDecoration(labelText: tr('البريد الإلكتروني')),
                  ),
                  const SizedBox(height: Space.md),
                  TextField(
                    obscureText: true,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(labelText: tr('كلمة المرور')),
                  ),
                  const SizedBox(height: Space.xs),
                  // ── صفُّ «نسيت» و«تذكرني» ─────────────────────────────
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {},
                        child: Text(tr('نسيت كلمة المرور')),
                      ),
                      const Spacer(),
                      Text(tr('تذكّرني'),
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.ink2)),
                      Checkbox(value: true, onChanged: (_) {}),
                    ],
                  ),
                  const SizedBox(height: Space.sm),
                  FilledButton(onPressed: () {}, child: Text(tr('دخول'))),
                  const SizedBox(height: Space.lg),
                  Muted(tr('ما عندك حساب؟'), size: 12),
                  const SizedBox(height: Space.sm),
                  OutlinedButton(
                      onPressed: () {}, child: Text(tr('إنشاء حساب'))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(_loadFonts);

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  // **ولا `pumpAndSettle`:** في الشاشة حقولُ نصّ، ومؤشّرُ الكتابة ينبض فلا
  // تسكن الإطاراتُ أبداً.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('القائم — وجهُ الدخول', (tester) async {
    phone(tester);
    await tester.pumpWidget(_wrap(AuthScreen(session: Session()..loading = false)));
    await settle(tester);

    // **والمقيسُ شجرةُ العناصر لا الصورة.**
    expect(find.widgetWithText(FilledButton, 'دخول'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/auth-now.png');
  });

  testWidgets('المقترح — رأسٌ أحمرُ وورقةٌ بيضاء', (tester) async {
    phone(tester);
    await tester.pumpWidget(_wrap(const _Proposed()));
    await settle(tester);

    expect(find.text('دخول الحساب'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'إنشاء حساب'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/auth-proposed.png');
  });
}
