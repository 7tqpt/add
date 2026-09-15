// **مقترحٌ لا تنفيذ.** إجبارُ العميل ومقدّم الخدمة على ضبط قفل التطبيق —
// بصمةً أو رمزاً رباعيّاً.
//
//   SHOTS=<مجلّد> flutter test tool/force_lock_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── وقرارٌ قائمٌ يُنقَض، فليُقرأ قبل أن يُنقَض ───────────────────────────────
//
// في رأس `lib/src/core/app_lock.dart` مكتوبٌ منذ كُتب:
//
//     ٤) والقفلُ اختياريّ. من لم يشغّله لا يراه أبداً — وقفلٌ يُفرض على من
//        لا يريده عائقٌ يوميٌّ لا حماية.
//
// وطلبُ صاحب المنصّة أن يُفرض. فهذا مقترحُ الفرض، وثمنُه مكتوبٌ في الشاشة
// نفسِها لا في هامشٍ: **كلُّ فتحةٍ للتطبيق تُطالب برمزٍ أو بصمة.**
//
// ── وما يُرسم هنا حقيقيّ ──────────────────────────────────────────────────
//
// الشاشةُ مبنيّةٌ بثيمة التطبيق (`buildTheme()`) وبعناصره: `AppCard`
// و`Muted` و`FilledButton` و`PinDots` و`_Pad` — لوحةُ الأرقام المشحونة من
// `lock.dart` بعينها، لا رسمٌ يشبهها. والخطوطُ مُحمَّلةٌ بـ`FontLoader`
// وإلّا خرجت الحروفُ مربّعاتٍ بيضاء.
//
// **والمرسومُ الوحيدُ ترتيبُ الشاشة الجديدة** — لأنّها لم تُكتب بعد، وهي
// موضعُ السؤال.
//
// ثلاثُ لقطات:
//   ١) البابُ — ما يراه من دخل ولم يضبط قفلاً بعد.
//   ٢) وضبطُ الرمز — `askPin` المشحونةُ نفسُها.
//   ٣) والقفلُ اليوميّ — `LockScreen` المشحونة، وهي ما سيراه كلَّ فتحة.
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

// **وحدُّ الرسم خارجَ `home`.** الورقةُ السفليّة تُدفع في `Overlay` الملاحة،
// فلا يجدها حدٌّ داخلَ `home`. وقد خرجت ثلاثُ لقطاتٍ متطابقةٍ بسبب ذلك من قبل.
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
      builder: (_, navigator) => RepaintBoundary(
        key: const ValueKey('shot'),
        child: navigator!,
      ),
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

/// حسّاسٌ مركَّب — **لا حسّاسَ في `flutter test`**، ولو نُوديت الحزمةُ
/// الأصليّةُ لرمت.
class _Sensor implements Biometrics {
  const _Sensor();

  @override
  Future<bool> available() async => true;

  @override
  Future<bool> authenticate() async => true;
}

/// **بابُ الإجبار — وهو المرسوم.**
///
/// ولا زرَّ «لاحقاً» فيه: «نجبر» تعني أنّ الطريقَ إلى التطبيق يمرّ من هنا.
/// والمخرجُ الوحيدُ «خروج» — من لم يُرد قفلاً لا يُحبَس في شاشةٍ بلا باب،
/// بل يخرج من حسابه.
class _Gate extends StatelessWidget {
  const _Gate({required this.hasSensor});

  final bool hasSensor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Space.xl),
              Icon(Icons.lock_outline,
                  size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: Space.lg),
              Text(
                tr('اقفل تطبيقك قبل أن تبدأ'),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: Space.sm),
              Muted(
                tr('في حسابك حجوزاتُك ومحادثاتُك ومبالغُك. ومن أخذ جوالك '
                    'لحظةً يراها كلَّها ما لم يكن عليه قفل.'),
                size: 14,
              ),
              const SizedBox(height: Space.lg),
              AppCard(
                children: [
                    const _Fact(
                      icon: Icons.pin_outlined,
                      title: 'رمزٌ من أربعة أرقام',
                      body: 'يُطلب كلّما فتحتَ التطبيق. ولا يُخزَّن الرمزُ '
                          'نفسُه — بل بصمةٌ منه لا تُعكس.',
                    ),
                    const SizedBox(height: Space.md),
                    _Fact(
                      icon: Icons.fingerprint,
                      title: hasSensor ? 'وبصمتُك تفتحه أسرع' : 'ولا بصمةَ في جهازك',
                      body: hasSensor
                          ? 'اختياريّةٌ فوق الرمز — والرمزُ باقٍ تحتها لِما '
                              'تعذّرت البصمة.'
                          : 'لا حسّاسَ هنا، فالرمزُ وحدَه يفتح.',
                    ),
                    const SizedBox(height: Space.md),
                    const _Fact(
                      icon: Icons.key_outlined,
                      title: 'ونسيتَ رمزك؟',
                      body: 'تخرج من حسابك وتدخل ببريدك وكلمة مرورك، ثمّ '
                          'تضبط رمزاً جديداً.',
                    ),
                ],
              ),
              const Spacer(),
              FilledButton(
                key: const ValueKey('gate-set-pin'),
                onPressed: () {},
                child: Text(tr('اضبط الرمز الآن')),
              ),
              const SizedBox(height: Space.sm),
              TextButton(
                onPressed: () {},
                child: Text(tr('خروج من الحساب')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.muted),
        const SizedBox(width: Space.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // **ولا `textStyle` بلا `fontFamily`.** نمطُ النصّ المكتوبُ
              // يدوياً لا يرث عائلةَ الثيمة، فتخرج الحروفُ مربّعاتٍ بيضاء.
              // وقد وقعت هذه من قبل في راسمٍ آخر.
              Text(tr(title),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Muted(tr(body), size: 13),
            ],
          ),
        ),
      ],
    );
  }
}

void main() {
  setUpAll(_loadFonts);

  setUp(() {
    lockStorageOverride = {};
  });
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

  testWidgets('١) البابُ — لا يُدخَل التطبيقُ قبله', (tester) async {
    phone(tester);
    await tester.pumpWidget(_wrap(const _Gate(hasSensor: true)));
    await settle(tester);

    expect(find.text('لاحقاً'), findsNothing, reason: 'بابٌ يُتخطّى ليس إجباراً');
    expect(find.byKey(const ValueKey('gate-set-pin')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _shoot(tester, '$out/force-lock-gate.png');
  });

  testWidgets('٢) وضبطُ الرمز — الورقةُ المشحونة', (tester) async {
    phone(tester);
    await tester.pumpWidget(_wrap(
      Builder(builder: (context) {
        return Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => askPin(
                context,
                title: tr('اضبط رمزك'),
                step: tr('الخطوة ١ من ٢'),
                note: tr('أربعةُ أرقامٍ تحفظها — ولا تكتبها في جوالك.'),
              ),
              child: Text(tr('افتح')),
            ),
          ),
        );
      }),
    ));
    await settle(tester);
    await tester.tap(find.byType(FilledButton));
    await settle(tester);

    // **ولا يُصدَّق أنّ الورقةَ فُتحت لأنّها رُسمت: تُسأل الشجرة.**
    expect(find.byType(PinDots), findsOneWidget,
        reason: 'لم تُفتح ورقةُ الرمز — فاللقطةُ لشيءٍ آخر');

    await _shoot(tester, '$out/force-lock-setpin.png');
  });

  testWidgets('٣) والقفلُ اليوميُّ — ما سيراه كلَّ فتحة', (tester) async {
    phone(tester);
    biometricsOverride = const _Sensor();
    final lock = AppLock();
    await lock.enable('1234');
    await lock.setBiometric(true);
    lock.onLeave();
    lock.onReturn();

    await tester.pumpWidget(_wrap(
      LockScreen(lock: lock, onSignOut: () async {}),
    ));
    await settle(tester);

    await _shoot(tester, '$out/force-lock-daily.png');
  });
}
