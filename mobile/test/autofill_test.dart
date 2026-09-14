// حقولُ الهويّة تعرض ما حفظه الجوّال.
//
// ── ولماذا يُقاس هذا ────────────────────────────────────────────────────────
//
// **بلا `autofillHints` لا يقترح الجوّالُ شيئاً.** فيُكتب البريدُ حرفاً حرفاً
// في كلّ دخول، وتُكتب كلمةُ المرور من الذاكرة، ويُحفظ رمزُ الرسالة في الرأس
// ثمّ يُعاد كتابتُه — وستُّ خاناتٍ تُنسى بين شاشتين. **ومن يكتب بيده يخطئ
// ويترك.**
//
// **والنيّةُ تُذكر لا مجرّدُ الوجود:** كلمةُ مرورٍ جديدةٌ توسَم `newPassword`
// ليعرضَ مديرُ كلماتِ المرور «أأحفظها؟»، وقديمةٌ توسَم `password` ليملأها.
// ومن وسمَ الجديدةَ بالقديمة لم يُحفظ شيءٌ لصاحبها.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/auth.dart';

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

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// تلميحاتُ حقلٍ بعينه — تُقرأ من العنصر المبنيّ لا من الشيفرة.
List<String>? _hintsOf(WidgetTester tester, Finder f) =>
    tester.widget<TextField>(f).autofillHints?.toList();

void main() {
  testWidgets('**الدخول: بريدٌ وكلمةٌ محفوظة**', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(AuthScreen(session: Session())));
    await _settle(tester);

    final fields = find.byType(TextField);
    expect(_hintsOf(tester, fields.at(0)), [AutofillHints.email]);
    expect(_hintsOf(tester, fields.at(1)), [AutofillHints.password],
        reason: 'كلمةٌ قائمةٌ تُملأ لا تُحفَظ');
  });

  testWidgets('**والإنشاء: كلمةٌ جديدةٌ تُحفَظ لا تُملأ**', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(AuthScreen(session: Session())));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('switch-face')));
    await _settle(tester);

    final fields = find.byType(TextField);
    expect(_hintsOf(tester, fields.at(1)), [AutofillHints.newPassword]);
    expect(
      _hintsOf(tester, find.byKey(const ValueKey('signup-confirm-password'))),
      [AutofillHints.newPassword],
    );
  });
}
