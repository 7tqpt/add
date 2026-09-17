// **تصويرُ ما صار.** `ChatScreen` المشحونةُ نفسُها من الشيفرة المدفوعة، لا
// رسمٌ يشبهها.
//
//   SHOTS=<مجلّد> flutter test tool/chat_bar_shot_test.dart
//
// **وكلُّ لقطةٍ تسأل الشجرةَ قبل أن تُؤخذ** — فلا تخرج صورةٌ تُطمئن على
// شريطٍ لم يُبنَ، ولا على ضغطةٍ لا تفتح شيئاً.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/chat.dart';

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
      builder: (_, navigator) =>
          RepaintBoundary(key: const ValueKey('shot'), child: navigator!),
      // **وتُدفع الشاشةُ طريقاً لا تُوضع في `home`** — وإلّا لم يرسم
      // `AppBar` سهمَ الرجوع (لا شيءَ يُرجَع إليه)، فخرجت لقطةٌ تُري شريطاً
      // غيرَ الذي يراه صاحبُ الجهاز. **وهو ما يُسأل عنه هنا بعينه:** أين
      // يقع سهمُ الرجوع من السهم الجديد؟
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const ValueKey('go'),
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => child)),
                child: const Text('افتح'),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  setUpAll(_loadFonts);

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('شريطُ المحادثة عند العميل — قرصٌ وسهمٌ يُضغط', (tester) async {
    phone(tester);
    await tester.pumpWidget(_wrap(ChatScreen(
      conversationId: 'c1',
      otherName: 'قاعة اللؤلؤة للأفراح',
      providerId: 'p1',
      mySide: ChatSide.customer,
    )));
    await tester.tap(find.byKey(const ValueKey('go')));
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsOneWidget,
        reason: 'لا سهمَ رجوعٍ في اللقطة — فهي تُري شريطاً غيرَ المرئيّ');

    expect(find.byKey(const ValueKey('chat-other-avatar')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-open-profile')), findsOneWidget,
        reason: 'الشريطُ لا يُضغط عند العميل — فلا تُصوَّر صورةٌ تكذب');

    await _shoot(tester, '$out/chatbar-shipped-customer.png');
  });

  testWidgets('وعند مقدّم الخدمة — قرصٌ بلا سهمٍ ولا ضغطة', (tester) async {
    phone(tester);
    await tester.pumpWidget(_wrap(ChatScreen(
      conversationId: 'c1',
      otherName: 'عبدالله محمد',
      providerId: 'p1',
      mySide: ChatSide.provider,
    )));
    await tester.tap(find.byKey(const ValueKey('go')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chat-other-avatar')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-open-profile')), findsNothing);

    await _shoot(tester, '$out/chatbar-shipped-provider.png');
  });
}
