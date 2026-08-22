// قشرة العميل وشريطها السفلي.
//
// الترتيب هنا ليس تفصيلاً: الشريط في العربية يبدأ من اليمين، فالبند الأوّل هو
// أقصى اليمين — أوّلُ ما يقع عليه الإبهام. وانقلابه يضع «حسابي» مكان
// «الرئيسية» بلا خطأٍ في أي سجلّ.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/customer_shell.dart';
import 'package:aras/src/ui/kit.dart';

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'ayman@sdd.company'
  ..appUserId = 'a1'
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
  home: Directionality(textDirection: TextDirection.rtl, child: CustomerShell(session: s)),
);

/// مقاس جوالٍ حقيقي — لا ‎٨٠٠×٦٠٠‎ الافتراضية.
void _phone(WidgetTester tester, {double height = 2340}) {
  tester.view.physicalSize = Size(1080, height);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// النصّ داخل البطاقات وحدها — لا في الشريط السفلي.
///
/// «خطة العرس» و«حجوزاتي» اسمان في مكانين: عنوانُ بطاقةٍ وبندُ تنقّل. وباحثٌ
/// بالنصّ وحده يجد اثنين فيرمي، أو يجد الخطأ منهما فيقيس مكان الشريط.
Finder _inCards(String text) =>
    find.descendant(of: find.byType(PageView), matching: find.text(text));

bool _onScreen(WidgetTester tester, Finder finder) {
  final screen = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
  return screen.contains(tester.getCenter(finder));
}

/// أسماء البطاقات النشطة في صفّ الأقسام.
///
/// و`skipOffstage: false` ضرورةٌ لا احتياط: الصفُّ أفقيٌّ فيه ثلاث عشرة
/// بطاقة، وأكثرُها خارج الشاشة.
List<String> _activeCategories(WidgetTester tester) => tester
    .widgetList<CategoryCard>(find.byType(CategoryCard, skipOffstage: false))
    .where((c) => c.active)
    .map((c) => c.label)
    .toList();

/// انتظارٌ يسع تأخير وضع العرض.
///
/// `pumpAndSettle` وحدها لا تحرّك الساعة ما لم يُجدول إطار، وشاشةُ التحميل لا
/// تجدول شيئاً — فالتأخيرُ لا ينقضي أبداً.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// تمريرةٌ كاملةٌ إلى الصفحة التالية — أوسعُ من نصف عرض البطاقة.
Future<void> _swipe(WidgetTester tester) async {
  await tester.drag(find.byType(PageView), const Offset(260, 0));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('خمسة بنودٍ بالترتيب المطلوب', (tester) async {
    await tester.pumpWidget(_wrap(_session()));
    await tester.pump(const Duration(seconds: 1));

    final bar = tester.widget<GlassNavBar>(find.byType(GlassNavBar));
    expect(
      bar.items.map((i) => i.label).toList(),
      ['الرئيسية', 'حجوزاتي', 'استكشف', 'خطة العرس', 'حسابي'],
    );
  });

  testWidgets('الرئيسية هي المفتوحة أوّلاً', (tester) async {
    await tester.pumpWidget(_wrap(_session()));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<GlassNavBar>(find.byType(GlassNavBar)).index, 0);
    // العنوان في الشريط الزجاجي يتبع التبويب المفتوح.
    expect(tester.widget<GlassHeader>(find.byType(GlassHeader)).title, 'الرئيسية');
  });

  testWidgets('الضغط ينقل التبويب ويغيّر العنوان', (tester) async {
    await tester.pumpWidget(_wrap(_session()));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('حسابي').last);
    await tester.pumpAndSettle();

    expect(tester.widget<GlassNavBar>(find.byType(GlassNavBar)).index, 4);
    expect(tester.widget<GlassHeader>(find.byType(GlassHeader)).title, 'حسابي');
  });

  testWidgets('بطاقتان كبيرتان تُمرَّران بالإبهام', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(_session()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byType(PageView), findsOneWidget);
    // الأولى في الشاشة، والثانية مبنيّةٌ خارجها تُطلّ من الحافّة.
    expect(_onScreen(tester, _inCards('خطة العرس')), isTrue);
    expect(_onScreen(tester, _inCards('حجزان')), isFalse);

    // ثمّ يمرّ الإبهام فتحلّ الثانية محلّها. والجرّ إلى اليمين تقدّمٌ في
    // العربية لا رجوع.
    //
    // ووجودُ النصّ وحده لا يثبت شيئاً: `PageView` يبني الصفحة المجاورة وإن
    // كانت خارج الشاشة، فـ`findsOneWidget` تمرّ ولو لم يتحرّك شيء — وقد
    // مرّت، وكانت البطاقة عند ‎−٣٢٠‎ من الحافة.
    await _swipe(tester);
    expect(_onScreen(tester, _inCards('حجزان')), isTrue);
  });

  testWidgets('وبطاقة الحجوزات تفتح تبويب الحجوزات', (tester) async {
    // البطاقة تنقل التبويب ولا تفتح شاشةً فوقه: لو دفعت شاشةً جديدة لخرج
    // المستخدم من الشريط السفلي كلّه وصار عليه زرُّ رجوع — وهو مغادرة لا
    // انتقال.
    _phone(tester);
    await tester.pumpWidget(_wrap(_session()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await _swipe(tester);
    await tester.tapAt(tester.getCenter(_inCards('حجزان')));
    await tester.pumpAndSettle();

    expect(tester.widget<GlassNavBar>(find.byType(GlassNavBar)).index, 1);
  });

  testWidgets('الرئيسية تعرض الأقسام كلّها لا بعضها', (tester) async {
    // كان `take(8)` يقصّ أربعةً بلا أن يقول، فيظنّ المستخدم أن المنصّة لا
    // تقدّم غيرها — وهي تقدّم. وهذا ما رآه على جهازه.
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(_session()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(CategoryCard, skipOffstage: false), findsNWidgets(12));
  });

  testWidgets('وبطاقة القسم تفتح الاستكشاف **على قسمها**', (tester) async {
    // **وهذا ما أبلغ عنه المستخدم:** كانت البطاقات كلُّها تنادي `onGoTo(2)`،
    // فالقسمُ المضغوط يُرمى ويُفتح الاستكشاف بكل شيء. فيضغط «الطبخ» فيجد
    // القاعات والتصوير والسيارات أمامه — وضغطتُه وقعت ولم يقع أثرها.
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(_session()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('الطبخ والضيافة'));
    await _settle(tester);

    expect(tester.widget<GlassNavBar>(find.byType(GlassNavBar)).index, 2);
    // القائمة مقصورةٌ على القسم: خدمتُه وحدها دون سواها.
    expect(find.text('مندي وحنيذ لـ300 شخص'), findsOneWidget);
    expect(find.text('قاعة التاج — باقة شاملة'), findsNothing);
    // والمرشِّح فوقها يقول أيُّ قسمٍ هذا — وإلا بدت قائمةً ناقصةً بلا سبب.
    expect(_activeCategories(tester), ['الطبخ والضيافة']);
  });

  testWidgets('و«استكشف» من الشريط تفتحه بلا مرشِّح', (tester) async {
    // القسم يبقى في القشرة بعد الضغط، فلو لم يُمسح عند التنقّل العاديّ لظلّت
    // القائمة مقصوصةً على قسمٍ ضُغط قبل دقيقة — بلا ما يدلّ على ذلك.
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(_session()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('الطبخ والضيافة'));
    await _settle(tester);
    await tester.tap(find.text('استكشف').last);
    await _settle(tester);

    expect(find.text('قاعة التاج — باقة شاملة'), findsOneWidget);
    expect(_activeCategories(tester), ['الكل']);
  });

  testWidgets('ولا تبقى بطاقةٌ شفّافة بعد الدخول المتدرّج', (tester) async {
    // الحركة تدخل البطاقات تباعاً؛ فإن عَلِقت واحدةٌ عند الشفافية بقيت
    // خليّةٌ فارغة في الشبكة بلا خطأٍ في أي سجلّ.
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(_session()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final faded = find
        .byType(AnimatedOpacity, skipOffstage: false)
        .evaluate()
        .where((e) => (e.widget as AnimatedOpacity).opacity < 1);
    expect(faded, isEmpty);
  });

  testWidgets('المحتوى يمرّ تحت الزجاج', (tester) async {
    // `extendBody` هو ما يعطي التمويهَ ما يموّهه. ولولا `glassNavSpace` في
    // حشوة القوائم لاختفت آخرُ بطاقةٍ خلف الشريط.
    await tester.pumpWidget(_wrap(_session()));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<Scaffold>(find.byType(Scaffold).first).extendBody, isTrue);
    expect(glassNavSpace, greaterThan(66));
    // والأعلى كذلك: الشريط في `Stack` لا في خانة `appBar`، فيمرّ المحتوى
    // خلفه ويجد التمويهُ ما يموّهه.
    expect(find.byType(AppBar), findsNothing);
    expect(glassHeaderSpace, greaterThan(glassHeaderBar));
  });
}
