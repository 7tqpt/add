// منظِّم حفل الزفاف: عدٌّ تنازلي، وتقدّمٌ محسوب، وقائمةٌ تُشطب.
//
// **وأخطر ما يُقاس هنا نسبةُ التقدّم.** رقمٌ يُعرض في أعلى الشاشة ويُصدَّق:
// من رآه ٨٠٪ قبل أسبوعٍ من العرس اطمأنّ. فإن كان محسوباً من عددٍ خاطئ —
// أو مكتوباً لا محسوباً — طَمْأنَ في غير موضعه.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/plan.dart';

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
  home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: child)),
);

/// الضغطُ بعد الإحضار إلى الشاشة.
///
/// **ولولاها لمرّت الاختبارات كاذبة:** الشاشة أطولُ من نافذة الاختبار
/// (‏٨٠٠×٦٠٠‏)، فما تحت الطيّ مبنيٌّ لكنه خارج المشهد — و`tap` عليه يُطلق
/// ضغطةً في مكانٍ لا شيء فيه، فلا يقع شيءٌ ولا يُرفع خطأ.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// قائمةُ عرضٍ معروفةُ العدد: ثلاثٌ من ثمانٍ منجَزة = ‎٣٨٪‎.
void _resetTasks() {
  demoPlanTasks = [
    const PlanTask(id: 'a', title: 'حجز القاعة', done: true, dueDate: '', sortOrder: 10),
    const PlanTask(id: 'b', title: 'المهر', done: true, dueDate: '', sortOrder: 20),
    const PlanTask(id: 'c', title: 'عقد القران', done: true, dueDate: '', sortOrder: 30),
    const PlanTask(id: 'd', title: 'حجز المصوّر', done: false, dueDate: '', sortOrder: 40),
    const PlanTask(id: 'e', title: 'فستان العروس', done: false, dueDate: '', sortOrder: 50),
    const PlanTask(id: 'f', title: 'بطاقات الدعوة', done: false, dueDate: '', sortOrder: 60),
    const PlanTask(id: 'g', title: 'سيارة الزفّة', done: false, dueDate: '', sortOrder: 70),
    const PlanTask(id: 'h', title: 'الحلويات', done: false, dueDate: '', sortOrder: 80),
  ];
}

void main() {
  setUp(_resetTasks);

  testWidgets('العدُّ التنازلي رقمٌ كبيرٌ لا سطرٌ في زحام', (tester) async {
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    // خطّةُ العرض بعد ٢٨ يوماً.
    expect(find.text('28'), findsOneWidget);
    expect(find.text('بقي 28 يوماً'), findsOneWidget);

    final number = tester.widget<Text>(find.text('28'));
    // **الحجم جزءٌ من المعنى:** رقمٌ بحجم السطر المجاور ليس عدّاً تنازليّاً.
    expect(number.style?.fontSize, greaterThanOrEqualTo(32));
  });

  testWidgets('والتقدّم محسوبٌ من المشطوب لا مكتوب', (tester) async {
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    expect(find.text('38٪'), findsOneWidget);
    expect(find.textContaining('بقيت 5 مهامّ'), findsOneWidget);
  });

  testWidgets('والشطبُ يحرّك النسبة في الحال', (tester) async {
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);
    expect(find.text('38٪'), findsOneWidget);

    // أوّلُ مربّعٍ في القائمة لأوّل مهمّةٍ **غير** منجزة — فالمنجَز مطويّ.
    await _tap(tester, find.byType(Checkbox).first);

    // أربعٌ من ثمانٍ.
    expect(find.text('50٪'), findsOneWidget);
    expect(demoPlanTasks.where((t) => t.done).length, 4);
  });

  testWidgets('والمنجَزُ مطويٌّ حتى يُطلب — لئلّا يدفن ما بقي', (tester) async {
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    expect(find.text('حجز القاعة'), findsNothing);
    expect(find.text('حجز المصوّر'), findsOneWidget);

    await _tap(tester, find.text('المنجَز (3)'));
    expect(find.text('حجز القاعة'), findsOneWidget);
  });

  testWidgets('ومهمّةٌ تُضاف من الشاشة نفسها', (tester) async {
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    await tester.ensureVisible(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'استئجار كراسي');
    await _tap(tester, find.byIcon(Icons.add).last);

    expect(find.text('استئجار كراسي'), findsOneWidget);
    expect(demoPlanTasks.length, 9);
  });

  testWidgets('والمربّعاتُ الأربعة تعرض أرقام الخطّة', (tester) async {
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    expect(find.text('المهامّ'), findsOneWidget);
    expect(find.text('5 متبقّية'), findsOneWidget);
    expect(find.text('قائمة الضيوف'), findsOneWidget);
    expect(find.text('400 ضيفاً'), findsOneWidget);
  });

  testWidgets('وقاعدةٌ بلا مهامّ تنقص ميزةً ولا تُسقط شاشة', (tester) async {
    // من لم يشغّل `plan_tasks.sql` بعد.
    demoPlanTasks = [];

    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    // العدُّ والميزانية يعملان كما كانا.
    expect(find.text('28'), findsOneWidget);
    expect(find.text('الميزانية'), findsWidgets);
    expect(find.textContaining('لم تُفتح قائمة التجهيز'), findsOneWidget);
    expect(find.text('0٪'), findsOneWidget);
  });
}
