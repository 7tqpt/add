// **مقترحٌ لا تنفيذ.** «البصمة تفتح القفلَ مكانَ الرمز» — يُعرض على صاحب
// المنصّة قبل أن يُلمَس `lib/`.
//
//   SHOTS=<مجلّد> flutter test tool/biometric_proposal_test.dart
//
// **اللقطةُ الأولى حقيقيّةٌ مصوَّرة:** `LockScreen` نفسُها كما هي على الفرع —
// أربعةُ أرقامٍ ولوحةٌ في الشاشة و«نسيتُ الرمز».
//
// **والثانيةُ مرسومةٌ ويُقال إنّها مرسومة.** لوحةُ الأرقام في `lock.dart`
// صنفٌ خاصٌّ (`_Pad`) لا يُنادى من خارج ملفّه، فلا تُركَّب نسخةٌ من الشاشة
// كلِّها بلا لمسِ `lib/`. فرُسم **الزائدُ وحدَه** بثيمة التطبيق وعناصره
// الحقيقيّة، وموضعُه بين اللوحة و«نسيتُ الرمز».
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/app_lock.dart';
import 'package:aras/src/core/i18n.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/lock.dart';
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

/// الزائدُ المقترَح — **مرسومٌ لا مصوَّر**، وعناصرُه حقيقيّةٌ بثيمة التطبيق.
///
/// وموضعُه في الشاشة بين لوحة الأرقام و«نسيتُ الرمز».
class _ProposedAddition extends StatelessWidget {
  const _ProposedAddition();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ما فوقه في الشاشة الحقيقيّة: النقاطُ ثمّ اللوحة.
                  Muted(tr('… لوحة الأرقام كما هي …'), size: 12),
                  const SizedBox(height: Space.xl),

                  // ── الزائد ─────────────────────────────────────────────
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.fingerprint, size: 26),
                    label: Text(tr('افتح بالبصمة')),
                  ),
                  const SizedBox(height: Space.sm),
                  Muted(tr('أو أدخل رمزك'), size: 12),
                  // ── انتهى الزائد ───────────────────────────────────────

                  const SizedBox(height: Space.lg),
                  TextButton(
                      onPressed: () {}, child: Text(tr('نسيتُ الرمز'))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  setUpAll(_loadFonts);

  setUp(() {
    // **ولا خزنةَ نظامٍ في `flutter test`** — فيُركَّب بديلٌ في الذاكرة.
    lockStorageOverride = {};
  });
  tearDown(() => lockStorageOverride = null);

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

  testWidgets('القائم — رمزٌ رباعيٌّ ولا بصمة', (tester) async {
    phone(tester);
    final lock = AppLock();
    await lock.enable('1234');

    await tester.pumpWidget(
        _wrap(LockScreen(lock: lock, onSignOut: () async {})));
    await settle(tester);

    // **وهذا هو المقيس لا الصورة:** لا أثرَ للبصمة في الشاشة اليوم.
    expect(find.byIcon(Icons.fingerprint), findsNothing);
    expect(find.byKey(const ValueKey('pin-dots')), findsOneWidget);
    expect(find.byKey(const ValueKey('forgot-pin')), findsOneWidget);
    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/lock-now.png');
  });

  testWidgets('المقترح — الزائدُ مرسوماً', (tester) async {
    phone(tester);
    await tester.pumpWidget(_wrap(const _ProposedAddition()));
    await settle(tester);

    expect(find.byIcon(Icons.fingerprint), findsOneWidget);
    expect(find.text('افتح بالبصمة'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _shoot(tester, find.byKey(const ValueKey('shot')),
        '$out/lock-proposed.png');
  });
}
