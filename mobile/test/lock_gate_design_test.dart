// «اقفل تطبيقك قبل أن تبدأ» على صورة صاحب المنصّة.
//
// في إطار شاشات الباب **بلا بطاقة** (`bare`): العنوانُ في القوس تحت قفلٍ
// بقلب، والسطرُ على ورقةٍ كريميّة، وبطاقةٌ داخليّةٌ للحقائق الثلاث، ثمّ
// «خطوة واحدة لحماية خصوصيتك»، ثمّ الزرّ والمخرج.
//
// **وما يُقاس ما يُرى:** الطبقاتُ فوق بعضها — العنوانُ فوق الورد، والورقةُ
// فوق مخمله — لأنّ كليهما وقع مقلوباً في أوّل لقطة.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/app_lock.dart';
import 'package:aras/src/core/biometrics.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/lock.dart';
import 'package:aras/src/ui/auth_frame.dart';

class _Sensor implements Biometrics {
  const _Sensor({this.has = true});
  final bool has;
  @override
  Future<bool> available() async => has;
  @override
  Future<bool> authenticate() async => false;
}

Widget _wrap(Widget child, {double scale = 1}) => MaterialApp(
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
    child: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child,
      ),
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, {bool sensor = true, double w = 360, double h = 780}) async {
  biometricsOverride = _Sensor(has: sensor);
  tester.view.physicalSize = Size(w * 3, h * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_wrap(LockGateScreen(lock: AppLock(), onSignOut: () async {})));
  await _settle(tester);
}

/// رتبةُ الطبقة التي فيها [target] في مكدّس الإطار — الأعلى رتبةً يُرسم فوق.
int _layerOf(WidgetTester tester, Finder target) {
  final stack = tester.widget<Stack>(
    find.descendant(of: find.byType(AuthFrame), matching: find.byType(Stack)).first,
  );
  for (var i = 0; i < stack.children.length; i++) {
    if (find.descendant(of: find.byWidget(stack.children[i]), matching: target).evaluate().isNotEmpty) {
      return i;
    }
  }
  return -1;
}

void main() {
  setUp(() => lockStorageOverride = {});
  tearDown(() {
    lockStorageOverride = null;
    biometricsOverride = null;
  });

  testWidgets('**بلا بطاقة، وعلى ورقةٍ كريميّة، والعنوانُ فوق الورد**', (tester) async {
    await _open(tester);
    final frame = tester.widget<AuthFrame>(find.byType(AuthFrame));
    expect(frame.bare && frame.crestOnTop, isTrue);
    expect(tester.widget<Container>(find.byKey(const ValueKey('auth-card'))).decoration, isNull,
        reason: 'بطاقةٌ حول بطاقة الحقائق');
    expect(
      _layerOf(tester, find.byKey(const ValueKey('auth-crest-top'))),
      greaterThan(_layerOf(tester, find.byKey(const ValueKey('rose-left')))),
      reason: 'الوردُ فوق العنوان — وقد غطّى طرفيه في أوّل لقطة',
    );
    expect(find.text('اقفل تطبيقك قبل أن تبدأ'), findsOneWidget);
  });

  testWidgets('**والورقةُ فوق مخمل الورد — فلا أحمرَ تحت السطر الأوّل**', (tester) async {
    await _open(tester);
    expect(
      _layerOf(tester, find.byKey(const ValueKey('auth-sheet'))),
      greaterThan(_layerOf(tester, find.byKey(const ValueKey('rose-left')))),
    );
    final sheet = tester.getRect(find.byKey(const ValueKey('auth-sheet')));
    final line = tester.getRect(find.text('احم حجوزاتك ومحادثاتك وملفاتك برمز قفل خاص بالتطبيق.'));
    expect(line.top, greaterThanOrEqualTo(sheet.top), reason: 'السطرُ على الرأس النبيذيّ');
  });

  testWidgets('**وفي القفل قلبٌ مكانَ الثقب**', (tester) async {
    await _open(tester);
    final heart = find.byKey(const ValueKey('gate-lock-heart'));
    final lock = find.byIcon(Icons.lock_outline_rounded);
    expect(heart, findsOneWidget);
    final l = tester.getRect(lock), h = tester.getRect(heart);
    expect(l.contains(h.center), isTrue, reason: 'القلبُ خارجَ القفل');
    expect(h.center.dy, greaterThan(l.center.dy), reason: 'القلبُ في الحلقة لا في الجسم');
  });

  testWidgets('**والحقائقُ الثلاث بكلماته**', (tester) async {
    await _open(tester);
    for (final t in [
      'رمز من أربعة أرقام',
      'يُطلب عند فتح التطبيق ويضيف طبقة حماية.',
      'بصمتك تفتحه أسرع',
      'يمكنك تفعيلها بعد إعداد الرمز.',
      'ونسيت رمزك؟',
      'سجّل الدخول ببريدك وكلمة مرورك لضبط رمز جديد.',
      'خطوة واحدة لحماية خصوصيتك',
      'اضبط الرمز الآن',
      'خروج من الحساب',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
  });

  testWidgets('**ولا يُوعَد ببصمةٍ ليست في الجهاز**', (tester) async {
    await _open(tester, sensor: false);
    expect(find.text('بصمتك تفتحه أسرع'), findsNothing);
    expect(find.text('يمكنك تفعيلها بعد إعداد الرمز.'), findsNothing);
    expect(find.text('ولا بصمةَ في جهازك'), findsOneWidget);
  });

  testWidgets('**و«خطوة واحدة…» سطرٌ واحدٌ لا سطران**', (tester) async {
    // انكسر سطرين في أوّل لقطة.
    await _open(tester, w: 320, h: 640);
    final p = tester.renderObject<RenderParagraph>(find.byKey(const ValueKey('gate-pledge-text')));
    expect(p.maxLines, 1, reason: 'السطرُ يُكسر');
    // **ويُصغَّر ولا يُقصّ**: سطرٌ واحدٌ مقصوصُ الآخر شرٌّ من سطرين.
    expect(p.didExceedMaxLines, isFalse, reason: 'قُصّ آخرُ السطر');
  });

  testWidgets('**والزرُّ نبيذيٌّ بتدرّج، والمخرجُ تحته**', (tester) async {
    await _open(tester);
    final set = find.byKey(const ValueKey('gate-set-pin'));
    expect(find.descendant(of: set, matching: find.byKey(const ValueKey('auth-primary-gradient'))), findsOneWidget);
    final out = tester.getRect(find.byKey(const ValueKey('gate-sign-out')));
    expect(out.top, greaterThanOrEqualTo(tester.getRect(set).bottom));
  });

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('**لا يفيض على جوالٍ صغيرٍ بخطّ ×$scale**', (tester) async {
      biometricsOverride = const _Sensor();
      tester.view.physicalSize = const Size(960, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(LockGateScreen(lock: AppLock(), onSignOut: () async {}), scale: scale));
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
