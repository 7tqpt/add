// راسمُ لقطةٍ لحقول «تقديم خدمة» بعد التبديل — ليس اختباراً، ولا يُدرج في
// الحزمة (خارج `test/`).
//
//   flutter test tool/dropdowns_shot_test.dart
//
// **والمرسومُ هو `BecomeProviderScreen` نفسُها** — لا رسمٌ يشبهها.
//
// **ولقطةٌ واحدةٌ لا ثلاث.** حاولتُ تصويرَ المنسدلةِ مفتوحةً وورقةِ الأقسام
// فتعلّق الراسمُ عندهما ولم يُخرج شيئاً — طريقُ المنسدلة يبقى حيّاً فلا
// يسكن `pumpAndSettle`. وقبلَه كان الحدُّ داخلَ `MaterialApp` فخرجت ثلاثُ
// لقطاتٍ **متطابقةٍ إلى البايت**: الطرقُ تُدفع فوق الشاشة في `Overlay`
// الملاحة — خارجَ أيّ حدٍّ في `home`. فأُخرج الحدُّ، وبقي التعلّق.
//
// فتُقاس الحالتان الأخريان في `test/become_provider_test.dart` بشجرة
// العناصر لا بالصورة — وهو أدقُّ على كلّ حال.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/become_provider.dart';

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
  final image = await boundary.toImage(pixelRatio: 3.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

Session _session() => Session()
  ..userId = 'u1'
  ..appUserId = 'demo-user'
  ..loading = false;

/// **والحدُّ خارجَ `MaterialApp` لا داخلَه.**
///
/// القوائمُ المنسدلةُ والأوراقُ السفليّة تُدفع طرقاً فوق الشاشة في
/// `Overlay` الملاحة — أي **خارج** أيّ حدٍّ داخل `home`. فكان الحدُّ في
/// الداخل يصوّر النموذجَ المغلقَ في الحالات الثلاث، وتخرج ثلاثُ لقطاتٍ
/// متطابقةٍ إلى البايت وأنا أحسبها ثلاثاً مختلفة.
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
        home: Directionality(textDirection: TextDirection.rtl, child: child),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('النموذجُ مغلقاً', (tester) async {
    tester.view.physicalSize = const Size(1176, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(BecomeProviderScreen(session: _session())));
    await _settle(tester);

    // ولا يُصدَّق أنّ النموذجَ رُسم: تُسأل الحقولُ عن نفسها.
    //
    // **ومنسدلتان لا واحدة:** صار القسمُ واحداً بقرار صاحب المنصّة، فسقط
    // الحقلُ الذي يفتح ورقةَ الاختيار المتعدّد (`categories-field`) وصار
    // منسدلةً كالمحافظة (`category-field`).
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
    expect(find.byKey(const ValueKey('governorate-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('category-field')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'إرسال الطلب'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'فاضت الشاشة');

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/form-closed.png');
  });
}
