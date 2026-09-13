// **مقترحٌ لا تنفيذ.** شاشةُ القفل على شكل شاشة الدخول — يُعرض على صاحب
// المنصّة قبل أن يُلمَس `lib/`.
//
//   SHOTS=<مجلّد> flutter test tool/lock_style_proposal_test.dart
//
// **الأولى حقيقيّةٌ مصوَّرة:** `LockScreen` نفسُها كما هي على الفرع.
// **والثانيةُ مرسومةٌ ويُقال إنّها مرسومة** — الإطارُ المقترَح: رأسٌ أحمرُ
// وورقةٌ بيضاء، وفيها `PinDots` الحقيقيّةُ وزرُّ البصمة الحقيقيّ.
//
// **ولوحةُ الأرقام لا تُستنسخ:** `_Pad` صنفٌ خاصٌّ في `lock.dart` لا يُنادى
// من خارج ملفّه، فلا تُركَّب نسخةٌ من الشاشة كلِّها بلا لمسِ `lib/`. فمكانُها
// سطرٌ يقول إنّها باقيةٌ كما هي — **والتبديلُ المقترَح إطارٌ لا محتوى**.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/app_lock.dart';
import 'package:aras/src/core/biometrics.dart';
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

/// حسّاسٌ مركَّب — **لا حسّاسَ في `flutter test`**.
class _Sensor implements Biometrics {
  const _Sensor({this.has = true, this.ok = true});
  final bool has;
  final bool ok;

  @override
  Future<bool> available() async => has;

  @override
  Future<bool> authenticate() async => ok;
}

/// الإطارُ المقترَح — **مرسومٌ لا مصوَّر**، وعناصرُه حقيقيّةٌ بثيمة التطبيق.
class _Proposed extends StatelessWidget {
  const _Proposed();

  @override
  Widget build(BuildContext context) {
    final headerHeight =
        (MediaQuery.sizeOf(context).height * 0.26).clamp(140.0, 230.0);
    return Scaffold(
      backgroundColor: AppColors.accent,
      body: Column(
        children: [
          SizedBox(
            height: headerHeight,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline,
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
                children: [
                  Text(
                    tr('أدخل رمز القفل'),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink),
                  ),
                  const SizedBox(height: Space.xs),
                  Muted(tr('أربعة أرقام'), size: 12),
                  const SizedBox(height: Space.lg),
                  const PinDots(filled: 0),
                  const SizedBox(height: Space.xl),
                  Muted('… لوحة الأرقام كما هي …', size: 12),
                  const SizedBox(height: Space.xl),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.fingerprint, size: 26),
                    label: Text(tr('افتح بالبصمة')),
                  ),
                  const SizedBox(height: Space.sm),
                  Muted(tr('أو أدخل رمزك'), size: 12),
                  const SizedBox(height: Space.lg),
                  TextButton(
                      onPressed: () {}, child: Text(tr('نسيتُ الرمز'))),
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

  setUp(() => lockStorageOverride = {});
  tearDown(() {
    lockStorageOverride = null;
    biometricsOverride = null;
  });

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

  testWidgets('القائم — بلا رأسٍ ولا ورقة', (tester) async {
    phone(tester);
    biometricsOverride = const _Sensor(has: true, ok: false);
    final lock = AppLock();
    await lock.enable('1234');
    await lock.setBiometric(true);
    lock.onLeave();
    lock.onReturn();

    await tester.pumpWidget(
        _wrap(LockScreen(lock: lock, onSignOut: () async {})));
    await settle(tester);

    // **والمقيسُ شجرةُ العناصر لا الصورة:** الأرضيّةُ ليست حمراءَ اليوم.
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, isNot(AppColors.accent));
    expect(find.byKey(const ValueKey('unlock-biometric')), findsOneWidget);
    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/lock-style-now.png');
  });

  testWidgets('المقترح — رأسٌ أحمرُ وورقةٌ بيضاء', (tester) async {
    phone(tester);
    await tester.pumpWidget(_wrap(const _Proposed()));
    await settle(tester);

    expect(find.text('أدخل رمز القفل'), findsOneWidget);
    expect(find.byType(PinDots), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _shoot(tester, find.byKey(const ValueKey('shot')),
        '$out/lock-style-proposed.png');
  });
}
