// حركةُ الترحيب — «اريد تسوي لي انميش هنا انميش احترافي».
//
// **وما يُقاس هنا ليس «أفيها حركة؟»** بل ما يجعلها احترافيّةً لا مزعجة:
//
//   • **تدور بلا قطع** — كلُّ ما يدور يعود إلى حيث بدأ عند تمام الدورة،
//     فلا تقفز البتلاتُ ولا تومض دفعةً كلَّ تسع ثوانٍ.
//   • **لا ضوءان معاً** — المذنّبُ وشريطُ الضوء وبريقُ «دخول» يتناوبون.
//   • **لا شيءَ يولد أو يموت فجأة** — البتلةُ تظهر وتذوب بالتدريج.
//   • **ولا يمسّ ما يُقرأ ويُضغط** — «دخول» في وسط زرّه، والبتلاتُ فوق
//     الزرّين، والوردُ لا يطول عن مقاسه.
//   • **ومن أطفأ الحركةَ لا يرى شيئاً منها.**
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/welcome.dart';

Widget _wrap(Widget child, {bool still = false}) => MaterialApp(
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
        data: MediaQuery.of(context).copyWith(disableAnimations: still),
        child: child,
      ),
    ),
  ),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// يمضي بالمشهد إلى ما بعد دخوله.
Future<void> _enter(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pump(const Duration(milliseconds: 100));
}

const _signIn = ValueKey('welcome-sign-in');

bool _near(double a, double b, [double eps = 1e-6]) => (a - b).abs() < eps;

void main() {
  setUp(resetIntroClock);

  // ==========================================================================
  //  البتلات
  // ==========================================================================
  group('البتلات', () {
    test('**تعود كلُّ بتلةٍ إلى حيث بدأت عند تمام الدورة**', () {
      for (var i = 0; i < petalSeeds.length; i++) {
        final a = petalAt(i, 0), b = petalAt(i, 1);
        expect(_near(a.x, b.x) && _near(a.y, b.y) && _near(a.flip, b.flip), isTrue,
            reason: 'البتلةُ $i تقفز عند تمام الدورة');
        expect(_near(a.alpha, b.alpha), isTrue);
        expect(_near(math.cos(a.angle), math.cos(b.angle)) &&
            _near(math.sin(a.angle), math.sin(b.angle)), isTrue,
            reason: 'البتلةُ $i تنقلب فجأةً عند تمام الدورة');
      }
    });

    test('**تظهر وتذوب بالتدريج — لا تنبت ولا تُقصّ**', () {
      const steps = 4000;
      for (var i = 0; i < petalSeeds.length; i++) {
        var lo = 1.0, hi = 0.0, jump = 0.0;
        var prev = petalAt(i, 0).alpha;
        for (var k = 1; k <= steps; k++) {
          final a = petalAt(i, k / steps).alpha;
          lo = math.min(lo, a);
          hi = math.max(hi, a);
          jump = math.max(jump, (a - prev).abs());
          prev = a;
        }
        expect(lo, lessThan(0.02), reason: 'البتلةُ $i لا تغيب أبداً');
        expect(hi, greaterThan(0.6), reason: 'البتلةُ $i لا تُرى');
        expect(jump, lessThan(0.03), reason: 'البتلةُ $i تظهر أو تختفي دفعةً');
      }
    });

    test('**وتسقط لا تصعد**', () {
      // ما يظهر منها يتحرّك إلى أسفل في كلّ خطوة — والعودةُ إلى أعلى تقع
      // وهي غائبة.
      for (var i = 0; i < petalSeeds.length; i++) {
        for (var k = 0; k < 1000; k++) {
          final a = petalAt(i, k / 1000), b = petalAt(i, (k + 1) / 1000);
          if (a.alpha > 0.05 && b.alpha > 0.05) {
            expect(b.y, greaterThan(a.y), reason: 'البتلةُ $i تصعد عند $k');
          }
        }
      }
    });

    test('ولا تخرج عن العرض', () {
      for (var i = 0; i < petalSeeds.length; i++) {
        for (var k = 0; k <= 200; k++) {
          final x = petalAt(i, k / 200).x;
          expect(x, inInclusiveRange(0.0, 1.0));
        }
      }
    });

    test('**ولا تسقط معاً**', () {
      final ys = {for (var i = 0; i < petalSeeds.length; i++) (petalAt(i, 0).y * 100).round()};
      expect(ys.length, petalSeeds.length, reason: 'بتلتان في المكان نفسِه من الدورة');
    });

    testWidgets('**تُرسم بعد الدخول — وفوق الزرّين لا خلفهما**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(WelcomeScreen(session: Session()..loading = false)));
      await _enter(tester);

      final petals = find.byKey(const ValueKey('petals'));
      expect(petals, findsOneWidget);
      expect(tester.getRect(petals).bottom,
          lessThanOrEqualTo(tester.getRect(find.byKey(_signIn)).top + 0.5));
    });
  });

  // ==========================================================================
  //  الأضواء: المذنّب وشريطُ الضوء وبريقُ «دخول»
  // ==========================================================================
  group('الأضواء', () {
    test('**لا ضوءان يتحرّكان معاً**', () {
      for (var k = 0; k < 2000; k++) {
        final v = k / 2000;
        final lights = [glintAt(v), cometAt(v), shimmerAt(v)].where((x) => x != null).length;
        expect(lights, lessThanOrEqualTo(1), reason: 'ضوءان معاً عند $v');
      }
    });

    test('**المذنّبُ يجري من أوّل القوس إلى آخره ولا يرجع**', () {
      final seen = <double>[];
      for (var k = 0; k < 2000; k++) {
        final c = cometAt(k / 2000);
        if (c != null) seen.add(c);
      }
      expect(seen, isNotEmpty, reason: 'لا مذنّب');
      expect(seen.first, lessThan(0.02));
      expect(seen.last, greaterThan(0.98));
      for (var k = 1; k < seen.length; k++) {
        expect(seen[k], greaterThanOrEqualTo(seen[k - 1]));
      }
    });

    test('**وبريقُ «دخول» يرتاح أكثرَ ممّا يمرّ، ويدخل من خارج الحافّة**', () {
      var moving = 0;
      double? first, last;
      for (var k = 0; k < 2000; k++) {
        final c = shimmerAt(k / 2000);
        if (c == null) continue;
        moving++;
        first ??= c;
        last = c;
      }
      expect(moving / 2000, lessThan(0.2));
      expect(first, lessThan(0));
      expect(last, greaterThan(1));
    });

    testWidgets('**والمذنّبُ لا يجري على قوسٍ لم يكتمل رسمُه**', (tester) async {
      // القوسُ واقفٌ في منتصف رسمه، ودورةُ الحياة تبلغ نافذةَ المذنّب.
      _phone(tester);
      await tester.pumpWidget(_wrap(const Scaffold(
        body: ArchMark(t: AlwaysStoppedAnimation(0.5)),
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2700)); // ‎٠٫٣‎ من الدورة
      final comet = tester.widget<CustomPaint>(find.byKey(const ValueKey('arch-comet')));
      expect(cometAt(0.3), isNotNull, reason: 'النافذةُ نفسُها تبدّلت');
      expect((comet.painter! as CometPainter).progress, isNull,
          reason: 'مذنّبٌ على قوسٍ نصفُه مرسوم');
    });

    testWidgets('**ويجري بعد اكتماله**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(const Scaffold(
        body: ArchMark(t: AlwaysStoppedAnimation(1)),
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2700));
      final comet = tester.widget<CustomPaint>(find.byKey(const ValueKey('arch-comet')));
      expect((comet.painter! as CometPainter).progress, isNotNull);
    });

    testWidgets('**وبريقُ «دخول» تحت الكلمة لا فوقها**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(WelcomeScreen(session: Session()..loading = false)));
      await _enter(tester);

      final shimmer = find.descendant(
        of: find.byKey(_signIn),
        matching: find.byKey(const ValueKey('welcome-shimmer')),
      );
      expect(shimmer, findsOneWidget, reason: 'لا بريقَ على «دخول»');
      final stack = tester.widget<Stack>(find
          .ancestor(of: shimmer, matching: find.byType(Stack))
          .first);
      final label = find.descendant(of: find.byKey(_signIn), matching: find.text('دخول'));
      int layerOf(Finder f) {
        for (var i = 0; i < stack.children.length; i++) {
          if (find.descendant(of: find.byWidget(stack.children[i]), matching: f, matchRoot: true)
              .evaluate()
              .isNotEmpty) {
            return i;
          }
        }
        return -1;
      }

      expect(layerOf(shimmer), lessThan(layerOf(label)), reason: 'البريقُ فوق «دخول»');
    });

    testWidgets('**و«دخول» في وسط زرّه**', (tester) async {
      // **وقد خرج في زاويته أوّلَ ما وُضع البريقُ تحته** — كدسةٌ بلا
      // `passthrough` تضع ما فيها في أوّلها.
      _phone(tester);
      await tester.pumpWidget(_wrap(WelcomeScreen(session: Session()..loading = false)));
      await _enter(tester);

      final button = tester.getRect(find.byKey(_signIn));
      final label = tester.getRect(
        find.descendant(of: find.byKey(_signIn), matching: find.text('دخول')),
      );
      expect(label.center.dx, moreOrLessEquals(button.center.dx, epsilon: 1));
      expect(label.center.dy, moreOrLessEquals(button.center.dy, epsilon: 1));
    });
  });

  // ==========================================================================
  //  القلبُ والنجومُ والورد
  // ==========================================================================
  group('الدخول', () {
    test('**النجومُ تتفتّح واحدةً بعد واحدة**', () {
      for (var i = 0; i < starSpots.length; i++) {
        expect(starEntryAt(i, 0.5), 0, reason: 'النجمةُ $i قبل القوس');
        expect(starEntryAt(i, 1), 1, reason: 'النجمةُ $i لم تظهر بعد المشهد');
      }
      // متى تبلغ كلُّ نجمةٍ نصفَ ظهورها — ويجب أن يتأخّر كلٌّ عمّا قبله.
      double half(int i) {
        for (var k = 0; k <= 1000; k++) {
          if (starEntryAt(i, k / 1000) >= 0.5) return k / 1000;
        }
        return 2;
      }

      for (var i = 0; i + 1 < starSpots.length; i++) {
        expect(half(i + 1), greaterThan(half(i)),
            reason: 'النجمتان $i و${i + 1} تظهران معاً');
      }
    });

    testWidgets('**والرسّامُ يأخذ لحظةَ الدخول لا تمامَه**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(const Scaffold(
        body: ArchMark(t: AlwaysStoppedAnimation(0.6)),
      )));
      await tester.pump();
      final stars = tester.widget<CustomPaint>(find.byKey(const ValueKey('stars')));
      expect((stars.painter! as StarsPainter).entry, 0.6);
    });

    testWidgets('**وموجةٌ من القلب حين يصل — ثمّ تنقضي**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(const Scaffold(
        body: ArchMark(t: AlwaysStoppedAnimation(0.66)),
      )));
      await tester.pump();
      expect(find.byKey(const ValueKey('heart-ripple')), findsOneWidget);

      await tester.pumpWidget(_wrap(const Scaffold(
        body: ArchMark(t: AlwaysStoppedAnimation(1)),
      )));
      await tester.pump();
      expect(find.byKey(const ValueKey('heart-ripple')), findsNothing,
          reason: 'الموجةُ باقيةٌ بعد المشهد');
    });

    test('**ونفَسُ الورد لا يطيله عن مقاسه**', () {
      var lo = 1.0;
      for (var k = 0; k <= 1000; k++) {
        final b = roseBreathAt(k / 1000);
        expect(b, lessThanOrEqualTo(1));
        lo = math.min(lo, b);
      }
      expect(lo, lessThan(0.99), reason: 'الوردُ لا يتنفّس');
      expect(_near(roseBreathAt(0), roseBreathAt(1)), isTrue);
    });

    testWidgets('**ويتنفّس من أسفله فلا يتحرّك حدُّه فوق الزرّين**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(WelcomeScreen(session: Session()..loading = false)));
      await _enter(tester);

      Rect roses() => tester.getRect(find.byType(WelcomeRoses));
      final a = roses();
      await tester.pump(const Duration(milliseconds: 2500));
      final b = roses();
      expect(a.top, isNot(moreOrLessEquals(b.top, epsilon: 0.01)), reason: 'الوردُ ساكن');
      expect(a.bottom, moreOrLessEquals(b.bottom, epsilon: 0.5));
    });
  });

  // ==========================================================================
  //  ومن أطفأ الحركة
  // ==========================================================================
  testWidgets('**ومن أطفأ الحركةَ لا يرى شيئاً منها**', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _wrap(WelcomeScreen(session: Session()..loading = false), still: true),
    );
    await tester.pump();

    for (final k in ['petals', 'welcome-shimmer', 'arch-comet', 'stars', 'heart-ripple']) {
      expect(find.byKey(ValueKey(k)), findsNothing, reason: '$k يتحرّك لمن أطفأ الحركة');
    }
    // والمشهدُ تامٌّ من أوّل إطار.
    expect(find.text('دخول'), findsOneWidget);
  });
}
