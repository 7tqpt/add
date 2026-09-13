// راسمُ شاشة الدخول بعد التنفيذ — **لقطةٌ حقيقيّةٌ واحدة**.
//
//   SHOTS=<مجلّد> flutter test tool/auth_shot_test.dart
//
// كان مقترحاً عُرض على صاحب المنصّة بلقطتين قبل أن يُلمَس `lib/`، فقال:
// «نفس هذا». فسقط المرسومُ وبقيت الشاشةُ الحقيقيّة.
//
// **وشعارُ «فرحتي» الذهبيُّ ليس في المستودع بعد**: لا صورةَ مجمّعةً في
// الحزمة أصلاً، وما في `assets/brand/` أيقوناتُ تطبيقٍ لا شعارُ سطر. فمكانَه
// أيقونةٌ واسمٌ بالأبيض حتى يصل الملفّ.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/auth.dart';

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

/// **وتُمهَل الصورةُ زمناً حقيقيّاً حتى تُفكَّ.**
///
/// `Image.asset` تقرأ من الحزمة وتفكّ الترميزَ في خيطٍ آخر، وذلك يحتاج
/// زمناً حقيقيّاً لا زمنَ الاختبار المصطنَع. فبلا هذا خرج الرأسُ بلا أيقونة
/// — وهي في الحزمة وتُرسم على الجهاز.
Future<void> _settleImages(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(
      const Duration(milliseconds: 300)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
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

  testWidgets('الشاشةُ بعد التنفيذ', (tester) async {
    phone(tester);
    await tester.pumpWidget(_wrap(AuthScreen(session: Session()..loading = false)));
    await settle(tester);
    await _settleImages(tester);

    // **والمقيسُ شجرةُ العناصر لا الصورة** — والتفصيلُ في
    // `test/auth_layout_test.dart` بخمسة ضوابطَ سالبةٍ تسقط بها.
    expect(find.text('دخول الحساب'), findsOneWidget);
    expect(find.byKey(const ValueKey('remember-me')), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'إنشاء حساب'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/auth-done.png');
  });

  testWidgets('وجهُ الإنشاء', (tester) async {
    phone(tester);
    await tester.pumpWidget(_wrap(AuthScreen(
        session: Session()..loading = false, startOnSignUp: true)));
    await settle(tester);
    await _settleImages(tester);
    expect(find.widgetWithText(FilledButton, 'إنشاء الحساب'), findsOneWidget);
    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/auth-signup.png');
  });

  testWidgets('ووجهُ استعادة الكلمة', (tester) async {
    phone(tester);
    await tester.pumpWidget(_wrap(AuthScreen(session: Session()..loading = false)));
    await settle(tester);
    await _settleImages(tester);
    // **والبريدُ يُكتب أوّلاً:** «نسيت كلمة المرور» تردّ «اكتب بريدك أوّلاً»
    // على الفارغ، فتبقى الشاشةُ على وجه الدخول ولا تُصوَّر الاستعادة.
    await tester.enterText(find.byType(TextField).at(0), 'a@b.co');
    await tester.tap(find.text('نسيت كلمة المرور'));
    await settle(tester);
    await _settleImages(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('استعادة كلمة المرور'), findsOneWidget);
    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/auth-recover.png');
  });
}
