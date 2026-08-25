// «من أنت؟» — ثلاثةُ أبوابٍ إلى بابٍ واحد.
//
// **وأهمّ ما يُقاس هنا أن الاختيار طريقٌ لا قسمة.** شاشةٌ تسأل «عروس أم
// مقدّم خدمة؟» يقرأها المستخدم على أنها نوعُ حسابٍ لا يُبدَّل — فمن أراد أن
// يعرض خدمةً ويحجز فتح حسابين. ولذلك يُقال له صراحةً إن الحساب واحد، ولذلك
// يبقى بابُ الرجوع مفتوحاً بعد الاختيار.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/onboarding.dart';

Session _session() => Session()
  ..userId = 'u-new'
  ..email = 'new@sdd.company'
  ..loading = false;

Widget _wrap(Session s) => MaterialApp(
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
    child: OnboardingScreen(session: s),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('الاختيارُ أوّلاً — ثلاثةٌ لا اثنان', (tester) async {
    await tester.pumpWidget(_wrap(_session()));
    await _settle(tester);

    expect(find.text('أنا عروس'), findsOneWidget);
    expect(find.text('أنا عريس'), findsOneWidget);
    expect(find.text('مقدّم خدمة'), findsOneWidget);
    // ولا حقولَ قبل الاختيار: شاشةٌ واحدة تسأل شيئاً واحداً.
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('ويُقال إن الحساب واحد — وإلّا فُتح حسابان', (tester) async {
    await tester.pumpWidget(_wrap(_session()));
    await _settle(tester);
    expect(find.textContaining('الحساب واحد'), findsOneWidget);
  });

  testWidgets('والاختيارُ يفتح النموذج نفسه للثلاثة', (tester) async {
    await tester.pumpWidget(_wrap(_session()));
    await _settle(tester);

    await tester.tap(find.text('أنا عروس'));
    await _settle(tester);

    expect(find.text('أكمل ملفك'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('وبابُ الرجوع مفتوحٌ بعده', (tester) async {
    // من ضغط «مقدّم خدمة» وهو يريد أن يحجز كان سيمضي في طريقٍ لم يقصده.
    await tester.pumpWidget(_wrap(_session()));
    await _settle(tester);

    await tester.tap(find.text('مقدّم خدمة'));
    await _settle(tester);
    expect(find.text('أكمل ملفك'), findsOneWidget);

    await tester.tap(find.byTooltip('غيّر الاختيار'));
    await _settle(tester);
    expect(find.text('أنا عروس'), findsOneWidget);
  });
}
