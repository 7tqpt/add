// شاشاتُ الباب على تصميم صاحب المنصّة — الدخولُ والإنشاءُ والاستعادةُ والقفل.
//
// أرسل أربعَ صورٍ وقال: «نفذهم بنفس الاستيل»، وعُرض عليه المقترحُ قبل التنفيذ
// فاختار: **(أ) أرقامٌ لاتينيّة** في القفل، و**(ب) ورقةُ ضبط الرمز تبقى كما
// هي**.
//
// **وما يُقاس هنا ما يُرى لا ما يُكتب في الشيفرة:** أين تقع البطاقةُ من الرأس،
// وأيُّ الطبقتين فوق الأخرى، وفي أيّ صفٍّ مفتاحُ البصمة، وكم عرضاً أُعطي
// «نسيت كلمة المرور؟» — وكلُّها وقع فيها خطأٌ أو كاد.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/app_lock.dart';
import 'package:aras/src/core/biometrics.dart';
import 'package:aras/src/core/remember.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/auth.dart';
import 'package:aras/src/screens/lock.dart';
import 'package:aras/src/screens/recover_password.dart';
import 'package:aras/src/screens/welcome.dart';
import 'package:aras/src/ui/auth_frame.dart';

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

/// **ولا `pumpAndSettle`:** مؤشّرُ الكتابة ينبض في الحقول فلا تسكن الإطارات.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void _phone(WidgetTester tester, {double w = 1080, double h = 2280}) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

class _Sensor implements Biometrics {
  @override
  Future<bool> available() async => true;
  @override
  Future<bool> authenticate() async => false;
}

Future<AppLock> _lock({bool biometric = false}) async {
  final lock = AppLock();
  await lock.enable('1234');
  if (biometric) await lock.setBiometric(true);
  lock.onLeave();
  lock.onReturn();
  return lock;
}

Session _guest() => Session()..loading = false;

/// رتبةُ الطبقة التي فيها [target] في مكدّس الإطار — الأعلى رتبةً يُرسم فوق.
int _layerOf(WidgetTester tester, Finder target) {
  final stack = tester.widget<Stack>(
    find.descendant(of: find.byType(AuthFrame), matching: find.byType(Stack)).first,
  );
  for (var i = 0; i < stack.children.length; i++) {
    final hit = find.descendant(of: find.byWidget(stack.children[i]), matching: target);
    if (hit.evaluate().isNotEmpty) return i;
  }
  return -1;
}

void main() {
  setUp(() {
    rememberStorageOverride = {};
    lockStorageOverride = {};
  });
  tearDown(() {
    rememberStorageOverride = null;
    lockStorageOverride = null;
    biometricsOverride = null;
  });

  group('الإطار', () {
    testWidgets('**الرأسُ نبيذيٌّ بتدرّج**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(AuthScreen(session: _guest())));
      await _settle(tester);

      final head = tester.widget<DecoratedBox>(find.byKey(const ValueKey('auth-head')));
      final g = (head.decoration as BoxDecoration).gradient as LinearGradient;
      expect(g.colors, [AppColors.accentDeep, AppColors.accent]);
    });

    testWidgets('**والبطاقةُ تبدأ حيث ينتهي الرأس — لا تحته ولا بعيداً عنه**',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(AuthScreen(session: _guest())));
      await _settle(tester);

      final head = tester.getRect(find.byKey(const ValueKey('auth-head')));
      final card = tester.getRect(find.byKey(const ValueKey('auth-card')));
      expect(card.top, inInclusiveRange(head.bottom - 10, head.bottom + 2));
      // **وعائمةٌ لا ورقةٌ من الحافّة إلى الحافّة.**
      expect(card.left, greaterThan(8));
      expect(card.right, lessThan(tester.view.physicalSize.width / 3 - 8));
    });

    testWidgets('**والوردُ من أصل الترحيب، وتحت البطاقة لا فوقها**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(AuthScreen(session: _guest())));
      await _settle(tester);

      for (final side in ['rose-left', 'rose-right']) {
        final img = tester.widget<Image>(find.byKey(ValueKey(side)));
        expect((img.image as AssetImage).assetName, WelcomeRoses.asset);
        expect(
          _layerOf(tester, find.byKey(ValueKey(side))),
          lessThan(_layerOf(tester, find.byKey(const ValueKey('auth-card')))),
          reason: '$side فوق البطاقة — يغطّي منها شيئاً',
        );
      }
    });

    testWidgets('**وزرُّ البطاقة الأوّل نبيذيٌّ بتدرّج، واللونُ المصمتُ تحته**',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(AuthScreen(session: _guest())));
      await _settle(tester);

      final button = find.widgetWithText(FilledButton, 'دخول');
      final fill = tester.widget<DecoratedBox>(find.descendant(
        of: button,
        matching: find.byKey(const ValueKey('auth-primary-gradient')),
      ));
      final g = (fill.decoration as BoxDecoration).gradient as LinearGradient;
      expect(g.colors, [AppColors.accentLift, AppColors.accent, AppColors.accentDeep]);
      expect(
        tester.widget<FilledButton>(button).style?.backgroundColor?.resolve({}),
        AppColors.accent,
      );
    });

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('**لا يفيض شيءٌ على جوالٍ صغيرٍ بخطّ ×$scale**', (tester) async {
        final screens = <Widget>[
          AuthScreen(session: _guest()),
          AuthScreen(session: _guest(), startOnSignUp: true),
          RecoverPasswordScreen(session: _guest()),
          LockScreen(lock: await _lock(), onSignOut: () async {}),
        ];
        for (final s in screens) {
          _phone(tester, w: 960, h: 1920); // ‎٣٢٠×٦٤٠‎
          await tester.pumpWidget(_wrap(s, scale: scale));
          await _settle(tester);
          expect(tester.takeException(), isNull, reason: '${s.runtimeType} فاض عند ×$scale');
          await tester.pumpWidget(const SizedBox.shrink());
        }
      });
    }
  });

  group('الدخول', () {
    testWidgets('**«نسيت كلمة المرور؟» يأخذ الصفَّ كلَّه لا نصفَه**', (tester) async {
      // **وكان `Flexible` بجوار `Spacer`**، وهما يقتسمان الفراغَ نصفين، فانكسر
      // الزرُّ سطرين في أوّل لقطةٍ حقيقيّة. ويُقاس بعرض ما أُعطيه النصُّ لا
      // بعدد أسطره: الخطُّ في الاختبار غيرُ خطّ الجهاز فأسطرُه تكذب.
      _phone(tester);
      await tester.pumpWidget(_wrap(AuthScreen(session: _guest())));
      await _settle(tester);

      final label = find.text('نسيت كلمة المرور؟');
      final para = tester.renderObject<RenderParagraph>(label);
      final row = tester.getRect(find.ancestor(of: label, matching: find.byType(Row)).first);
      final others = tester.getRect(find.byKey(const ValueKey('remember-me'))).width +
          tester.getRect(find.text('تذكّرني')).width;
      expect(para.constraints.maxWidth, greaterThan((row.width - others) * 0.75),
          reason: 'أُعطي ${para.constraints.maxWidth} من ${row.width - others}');
    });

    testWidgets('**والعينُ تُظهر الكلمةَ في حقلها وحدَه**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(AuthScreen(session: _guest(), startOnSignUp: true)));
      await _settle(tester);

      bool hidden(int i) => tester.widget<TextField>(find.byType(TextField).at(i)).obscureText;
      expect([hidden(1), hidden(2)], [true, true], reason: 'الكلمةُ ظاهرةٌ ابتداءً');

      await tester.tap(find.byTooltip('أظهر الكلمة').first);
      await _settle(tester);
      expect([hidden(1), hidden(2)], [false, true]);

      await tester.tap(find.byTooltip('أخفِ الكلمة'));
      await _settle(tester);
      expect([hidden(1), hidden(2)], [true, true]);
    });
  });

  group('الاستعادة', () {
    testWidgets('**عنوانُها وسهمُها في الرأس، والنجومُ تحتهما لا عليهما**',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(RecoverPasswordScreen(session: _guest())));
      await _settle(tester);

      final title = tester.getRect(find.text('استعادة كلمة المرور'));
      final head = tester.getRect(find.byKey(const ValueKey('auth-head')));
      expect(title.bottom, lessThan(head.bottom));
      expect(find.byType(BackButton), findsOneWidget);
      expect(tester.getRect(find.byKey(const ValueKey('head-stars'))).top,
          greaterThanOrEqualTo(title.bottom),
          reason: 'نجمةٌ على العنوان — وقد وقعت في أوّل لقطة');
    });
  });

  group('القفل', () {
    testWidgets('**أرقامٌ لاتينيّة — اختارها صاحبُ المنصّة**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(LockScreen(lock: await _lock(), onSignOut: () async {})));
      await _settle(tester);
      for (final d in '0123456789'.split('')) {
        expect(find.text(d), findsOneWidget, reason: d);
      }
      for (final d in '٠١٢٣٤٥٦٧٨٩'.split('')) {
        expect(find.text(d), findsNothing, reason: d);
      }
    });

    testWidgets('**والمفاتيحُ دوائرُ بإطارٍ ذهبيّ**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(LockScreen(lock: await _lock(), onSignOut: () async {})));
      await _settle(tester);
      final m = tester.widget<Material>(
        find.ancestor(of: find.byKey(const ValueKey('pad-5')), matching: find.byType(Material)).first,
      );
      expect(m.shape, isA<CircleBorder>());
      expect((m.shape! as CircleBorder).side.color, authGoldLine);
    });

    testWidgets('**والبصمةُ مفتاحٌ في صفّ الصفر، يمينَه**', (tester) async {
      biometricsOverride = _Sensor();
      _phone(tester);
      await tester.pumpWidget(_wrap(
        LockScreen(lock: await _lock(biometric: true), onSignOut: () async {}),
      ));
      await _settle(tester);

      final bio = tester.getCenter(find.byKey(const ValueKey('unlock-biometric')));
      final zero = tester.getCenter(find.byKey(const ValueKey('pad-0')));
      final back = tester.getCenter(find.byKey(const ValueKey('pad-back')));
      expect(bio.dy, moreOrLessEquals(zero.dy, epsilon: 1), reason: 'ليست في صفّ الصفر');
      // يمينَ الصفر في لوحةٍ عربيّة — والمحوُ يسارَه.
      expect(bio.dx, greaterThan(zero.dx));
      expect(back.dx, lessThan(zero.dx));
      // **ولا زرَّ ثانياً تحت اللوحة** — كان هناك «افتح بالبصمة».
      expect(find.text('افتح بالبصمة'), findsNothing);
    });

    testWidgets('**وبلا بصمةٍ تبقى خانتُها فارغةً والصفرُ في الوسط**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(LockScreen(lock: await _lock(), onSignOut: () async {})));
      await _settle(tester);
      expect(find.byKey(const ValueKey('unlock-biometric')), findsNothing);
      expect(
        tester.getCenter(find.byKey(const ValueKey('pad-0'))).dx,
        moreOrLessEquals(tester.getCenter(find.byKey(const ValueKey('pad-5'))).dx, epsilon: 1),
      );
    });

    testWidgets('**«أدخل رمز القفل»: الكلمةُ الأخيرةُ نبيذيّة**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(LockScreen(lock: await _lock(), onSignOut: () async {})));
      await _settle(tester);

      final para = tester.renderObject<RenderParagraph>(find.text('أدخل رمز القفل'));
      final spans = <String, Color?>{};
      para.text.visitChildren((span) {
        if (span is TextSpan && span.text != null) {
          // اللونُ الفعليُّ بعد الوراثة — ما يُرسم لا ما كُتب في الفرع.
          spans[span.text!.trim()] = span.style?.color ?? para.text.style?.color;
        }
        return true;
      });
      expect(spans['القفل'], AppColors.accent);
      expect(spans['أدخل رمز'], AppColors.ink);
    });

    testWidgets('**والنقاطُ الفارغةُ بإطارٍ ذهبيّ**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(LockScreen(lock: await _lock(), onSignOut: () async {})));
      await _settle(tester);
      final dot = tester.widget<AnimatedContainer>(find
          .descendant(
            of: find.byKey(const ValueKey('pin-dots')),
            matching: find.byType(AnimatedContainer),
          )
          .first);
      final border = (dot.decoration as BoxDecoration).border as Border;
      expect(border.top.color, authGoldEdge);
    });

    testWidgets('**وورقةُ ضبط الرمز باقيةٌ كما هي** — اختارها صاحبُ المنصّة',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => askPin(context, title: 'اضبط'),
            child: const Text('افتح'),
          ),
        ),
      )));
      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();

      final m = tester.widget<Material>(
        find.ancestor(of: find.byKey(const ValueKey('pad-5')), matching: find.byType(Material)).first,
      );
      expect(m.shape, isNot(isA<CircleBorder>()));
      final dot = tester.widget<AnimatedContainer>(find
          .descendant(of: find.byType(PinDots), matching: find.byType(AnimatedContainer))
          .first);
      expect(((dot.decoration as BoxDecoration).border as Border).top.color, AppColors.hairline);
    });
  });
}
