// «خطة جديدة»: محافظةٌ تُختار من منسدلةٍ لا من جدارِ شرائح.
//
// **وأخرجها صاحبُ المنصّة بلقطة:** عشرون محافظةً تملأ البطاقةَ وتدفع
// «إنشاء الخطة» إلى أسفلها، فلا يُرى النموذجُ كلُّه في شاشةٍ واحدة. وهو
// آخرُ جدارِ شرائحَ للمحافظات في التطبيق — سقط نظيرُه في «أكمل ملفك».
//
// **وثلاثةٌ تُقاس هنا لا واحد:**
//
//   ١) أنّ الجدارَ سقط والمنسدلةَ قامت — شجرةُ العناصر لا الصورة.
//   ٢) **وأنّ ما يصل الخادمَ هو المختار** — والمنسدلةُ تحتفظ باختيارها
//      داخلَ نفسها فتعرضه للعين ولو لم يصل شيء. فيُسأل `demoPlans`.
//   ٣) **وأنّ خطّةً قائمةً تُفتح للتعديل ولا تُسقط الشاشة** — المحافظةُ
//      تُقرأ من الخطّة قبل أن تصل القائمةُ من الخادم، ومنسدلةٌ قيمتُها
//      ليست في خياراتها تُسقط الشجرةَ بدعوى.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/plan_editor.dart';
import 'package:aras/src/ui/kit.dart';

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'c@sdd.company'
  ..appUserId = 'demo-user'
  ..loading = false;

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
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

const _field = ValueKey('plan-governorate-field');

WeddingPlan _plan({required String governorate}) => WeddingPlan(
  id: 'pl1',
  title: 'عرس أحمد ومريم',
  weddingDate: '2026-12-01',
  governorate: governorate,
  guestsCount: 400,
  budget: 2000000,
  status: 'planning',
  servicesCount: 0,
  totalCost: 0,
  paidAmount: 0,
  remainingAmount: 2000000,
);

void main() {
  setUp(() {
    demoPlans = [_plan(governorate: 'أمانة العاصمة')];
  });

  testWidgets('**المنسدلةُ قامت والجدارُ سقط**', (tester) async {
    await tester.pumpWidget(_wrap(PlanEditorScreen(session: _session())));
    await _settle(tester);

    expect(find.byKey(_field), findsOneWidget);
    expect(find.byType(PickChip), findsNothing);
    expect(find.text('اختر محافظة العرس'), findsOneWidget);
  });

  testWidgets('وعنوانُ الحقل «المحافظة» يبقى مقروءاً', (tester) async {
    await tester.pumpWidget(_wrap(PlanEditorScreen(session: _session())));
    await _settle(tester);

    // كان سطراً منفصلاً فوق الجدار، فصار عنوانَ الحقل نفسِه — ويطفو فلا
    // يختفي حين تُختار محافظة.
    expect(find.text('المحافظة'), findsOneWidget);
  });

  testWidgets('**وما يصل الخادمَ هو المختار لا ما يعرضه الحقل**',
      (tester) async {
    await tester.pumpWidget(
      _wrap(PlanEditorScreen(
          session: _session(), plan: _plan(governorate: 'أمانة العاصمة'))),
    );
    await _settle(tester);

    await tester.tap(find.byKey(_field));
    await _settle(tester);
    await tester.tap(find.text('تعز').last);
    await _settle(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await _settle(tester);

    // **ولا يُسأل الحقلُ عمّا فيه:** يعرض «تعز» ولو لم يصل الخادمَ شيء.
    expect(demoPlans.single.governorate, 'تعز');
  });

  testWidgets('ولا تُحفظ خطّةٌ بلا محافظة', (tester) async {
    await tester.pumpWidget(_wrap(PlanEditorScreen(session: _session())));
    await _settle(tester);

    // **والتاريخُ يُختار أوّلاً، وإلّا لم يُقَس شيء.** الرسالةُ واحدةٌ
    // للثلاثة (الاسم والتاريخ والمحافظة)، فخطّةٌ بلا تاريخٍ تُردّ للتاريخ
    // ويمرّ الاختبارُ وهو لا يحرس المحافظةَ بشيء — وقد أمسك الضابطُ (د)
    // هذا بعينه: نُزع شرطُ المحافظة فبقيت الحزمةُ خضراء.
    await tester.tap(find.text('اختر تاريخ العرس'));
    await _settle(tester);
    await tester.tap(find
        .descendant(of: find.byType(Dialog), matching: find.byType(TextButton))
        .last);
    await _settle(tester);
    expect(find.text('اختر تاريخ العرس'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'إنشاء الخطة'));
    await _settle(tester);

    expect(find.textContaining('محافظته'), findsOneWidget);
    // ولم تُضَف خطّةٌ ناقصة.
    expect(demoPlans.length, 1);
  });

  testWidgets('**وخطّةٌ قائمةٌ تُفتح للتعديل ومحافظتُها مختارة**',
      (tester) async {
    await tester.pumpWidget(
      _wrap(PlanEditorScreen(
          session: _session(), plan: _plan(governorate: 'عدن'))),
    );
    await _settle(tester);

    expect(tester.takeException(), isNull);
    final field =
        tester.widget<DropdownButtonFormField<String>>(find.byKey(_field));
    expect(field.initialValue, 'عدن');
  });

  testWidgets(
      '**ومحافظةٌ لم تعد في القائمة لا تُسقط الشاشة**', (tester) async {
    // محافظةٌ أُطفئت من `governorates` بعد أن حُفظت الخطّة. ومنسدلةٌ قيمتُها
    // ليست في خياراتها ترمي `There should be exactly one item…` — فتصير
    // شاشةً حمراءَ لا نموذجَ تعديل.
    await tester.pumpWidget(
      _wrap(PlanEditorScreen(
          session: _session(), plan: _plan(governorate: 'محافظةٌ مطفأة'))),
    );
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byKey(_field), findsOneWidget);
  });

  testWidgets('**وزرُّ الإنشاء يُرى بلا تمرير**', (tester) async {
    // وهذا ما شكا منه صاحبُ المنصّة: الجدارُ يدفع الزرَّ تحت الطيّة.
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(PlanEditorScreen(session: _session())));
    await _settle(tester);

    final button = tester.getRect(find.widgetWithText(FilledButton, 'إنشاء الخطة'));
    expect(button.bottom, lessThan(tester.view.physicalSize.height / 3.0));
  });
}
