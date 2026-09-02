// شريطُ التحديث، وشاشةُ المنع، والبوّابةُ التي تختار بينهما.
//
// **وأثقلُ ما هنا: أنّ الإجباريَّ يقع فوق كلّ شيء.** من كان على نسخةٍ لا
// تعمل مع الخدمة لا ينفعه أن يفتح قفله ولا أن يسجّل دخوله — والنداءُ نفسُه
// هو المكسور.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/app_update.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/update_prompt.dart';
import 'package:aras/src/ui/kit.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: buildTheme(),
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Directionality(textDirection: TextDirection.rtl, child: child),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

AppRelease _r(
  int build, {
  bool force = false,
  int rollout = 100,
  String notes = '',
  String url = 'https://sdd.company/farhati.apk',
}) =>
    AppRelease(
      build: build,
      version: '2.0.0',
      notes: notes,
      downloadUrl: url,
      forceUpdate: force,
      rolloutPercent: rollout,
    );

void main() {
  tearDown(() {
    releasesOverride = null;
    updateBucketOverride = null;
  });

  // ==========================================================================
  //  البوّابة
  // ==========================================================================

  group('البوّابة', () {
    test('**ولا تسقط إن سقط النداء**', () async {
      // فحصُ التحديث خدمةٌ زائدة، وتطبيقٌ لا يُقلع لأنّها فشلت عطبٌ أكبرُ
      // من الذي يتجنّبه.
      releasesOverride = () async => throw 'لا شبكة';
      updateBucketOverride = 0;
      final gate = UpdateGate();
      await gate.check();
      expect(gate.forced, isNull);
      expect(gate.banner, isNull);
    });

    test('ولا شيءَ من قاعدةٍ لا نسخَ فيها', () async {
      releasesOverride = () async => [];
      updateBucketOverride = 0;
      final gate = UpdateGate();
      await gate.check();
      expect(gate.banner, isNull);
    });

    test('والعاديُّ يذهب إلى الشريط لا إلى المنع', () async {
      releasesOverride = () async => [_r(99)];
      updateBucketOverride = 0;
      final gate = UpdateGate();
      await gate.check();
      expect(gate.banner?.build, 99);
      expect(gate.forced, isNull);
    });

    test('والإجباريُّ يذهب إلى المنع لا إلى الشريط', () async {
      releasesOverride = () async => [_r(99, force: true)];
      updateBucketOverride = 0;
      final gate = UpdateGate();
      await gate.check();
      expect(gate.forced?.build, 99);
      expect(gate.banner, isNull);
    });

    test('**ولا يُمنع أحدٌ خلف شاشةٍ زرُّها لا يفتح شيئاً**', () async {
      // نسخةٌ إجباريّةٌ بلا رابط: لو مُنع بها لَحُبس صاحبُ الجهاز بلا مخرج.
      releasesOverride = () async => [_r(99, force: true, url: '')];
      updateBucketOverride = 0;
      final gate = UpdateGate();
      await gate.check();
      expect(gate.forced, isNull, reason: 'حُبس خلف شاشةٍ بلا مخرج');
      expect(gate.banner, isNull);
    });

    test('و«لاحقاً» تُخفي الشريط', () async {
      releasesOverride = () async => [_r(99)];
      updateBucketOverride = 0;
      final gate = UpdateGate();
      await gate.check();
      expect(gate.banner, isNotNull);
      gate.dismiss();
      expect(gate.banner, isNull);
    });

    test('**ولا تُخفي «لاحقاً» المنعَ**', () async {
      releasesOverride = () async => [_r(99, force: true)];
      updateBucketOverride = 0;
      final gate = UpdateGate();
      await gate.check();
      gate.dismiss();
      expect(gate.forced?.build, 99, reason: 'أُغلق البابُ المقفل بزرّ');
    });
  });

  // ==========================================================================
  //  الشريط
  // ==========================================================================

  group('الشريط', () {
    testWidgets('**يُركَّب بلا استثناء**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(Scaffold(
        body: UpdateBanner(release: _r(99, notes: 'إصلاحات'), onDismiss: () {}),
      )));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('ويقول اسمَ النسخة وملاحظاتِها', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(Scaffold(
        body: UpdateBanner(
          release: _r(99, notes: 'تسريعُ البحث'),
          onDismiss: () {},
        ),
      )));
      await tester.pump();
      expect(find.textContaining('2.0.0'), findsOneWidget);
      expect(find.text('تسريعُ البحث'), findsOneWidget);
    });

    testWidgets('و«لاحقاً» تُنادى عند الضغط', (tester) async {
      _phone(tester);
      var dismissed = 0;
      await tester.pumpWidget(_wrap(Scaffold(
        body: UpdateBanner(release: _r(99), onDismiss: () => dismissed++),
      )));
      await tester.tap(find.byKey(const ValueKey('update-dismiss')));
      await tester.pump();
      expect(dismissed, 1);
    });

    testWidgets('وملاحظاتٌ فارغةٌ لا تترك سطراً خالياً', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(Scaffold(
        body: UpdateBanner(release: _r(99, notes: '   '), onDismiss: () {}),
      )));
      await tester.pump();
      expect(find.byType(Muted), findsNothing);
    });
  });

  // ==========================================================================
  //  شاشةُ المنع
  // ==========================================================================

  group('شاشةُ المنع', () {
    testWidgets('**تُركَّب بلا استثناء**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(ForcedUpdateScreen(release: _r(99))));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('forced-download')), findsOneWidget);
    });

    testWidgets('**ولا زرَّ «لاحقاً» فيها**', (tester) async {
      // ومن أوهمناه أنّ له خياراً وليس له أسوأُ حالاً ممّن قيل له الحقّ.
      _phone(tester);
      await tester.pumpWidget(_wrap(ForcedUpdateScreen(release: _r(99))));
      await tester.pump();
      expect(find.byKey(const ValueKey('update-dismiss')), findsNothing);
      expect(find.text('لاحقاً'), findsNothing);
    });
  });
}
