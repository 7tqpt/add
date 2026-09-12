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
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/screens/onboarding.dart';
import 'package:aras/src/ui/kit.dart';

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

  // ── المحافظة: منسدلةٌ لا جدارُ شرائح ──────────────────────────────────────
  //
  // **والعلّةُ أنّ النموذجَ كان يمتدّ صفحتين.** المحافظاتُ عشرون، فسبعةُ
  // صفوفٍ من الشرائح تدفع زرَّ «متابعة» تحت الطيّة — ومن فتح الشاشةَ لا يرى
  // كم بقي عليه. وهي الشاشةُ الأولى التي يراها من سجّل.

  Future<void> openForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(_session()));
    await _settle(tester);
    await tester.tap(find.text('أنا عروس'));
    await _settle(tester);
  }

  testWidgets('**ولا جدارَ شرائحَ للمحافظة**', (tester) async {
    await openForm(tester);
    expect(find.byType(PickChip), findsNothing,
        reason: 'الشرائحُ عادت إلى النموذج');
    expect(find.byKey(const ValueKey('governorate-field')), findsOneWidget);
  });

  testWidgets('**والزرُّ يُرى مع الحقول في شاشةٍ واحدة**', (tester) async {
    // وهذا هو المطلوبُ بعينه: لا تمريرَ لِيُرى «متابعة».
    await openForm(tester);
    final button = find.widgetWithText(FilledButton, 'متابعة');
    expect(button, findsOneWidget);
    final box = tester.getRect(button);
    final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(box.bottom, lessThan(screen),
        reason: 'زرُّ المتابعة تحت الطيّة — ${box.bottom} من $screen');
  });

  testWidgets('وكلُّ المحافظات في القائمة', (tester) async {
    await openForm(tester);
    await tester.tap(find.byKey(const ValueKey('governorate-field')));
    await _settle(tester);
    for (final g in demoGovernorates) {
      expect(find.text(g.name), findsWidgets, reason: '${g.name} ليست فيها');
    }
  });

  testWidgets('**والمحافظةُ المختارةُ هي ما يصل الخادم**', (tester) async {
    // **ولا يُسأل الحقلُ عمّا فيه — فهو يكذب.** `DropdownButtonFormField`
    // يحتفظ باختياره داخلَ نفسه فيعرضه للعين ولو لم يصل `onChanged` شيئاً.
    await openForm(tester);
    await tester.enterText(find.byType(TextField).at(0), 'محمد الصنعاني');
    await tester.enterText(find.byType(TextField).at(1), '770000000');

    await tester.tap(find.byKey(const ValueKey('governorate-field')));
    await _settle(tester);
    await tester.tap(find.text(demoGovernorates[2].name).last);
    await _settle(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'متابعة'));
    await _settle(tester);

    expect(demoProfile()?.governorate, demoGovernorates[2].name,
        reason: 'وصل الخادمَ غيرُ ما اختاره');
  });

  testWidgets('**ولا يمرّ نموذجٌ بلا محافظة**', (tester) async {
    await openForm(tester);
    await tester.enterText(find.byType(TextField).at(0), 'محمد الصنعاني');
    await tester.enterText(find.byType(TextField).at(1), '770000000');
    await tester.tap(find.widgetWithText(FilledButton, 'متابعة'));
    await _settle(tester);
    // **ونصُّ الخطأ بعينه لا كلمةٌ منه:** النصُّ الإرشاديُّ «اختر محافظتك»
    // يشترك معه في الكلمة، فسؤالٌ بالاحتواء يجد اثنين ويسقط وإن كان
    // السلوكُ صحيحاً — وقد سقط.
    expect(find.text('اكتب اسمك ورقمك واختر محافظتك.'), findsOneWidget);
  });
}
