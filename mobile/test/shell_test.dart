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

// (وذهب من هنا `_inCards` و`_onScreen` — كانا يجدان نصّاً داخل البطاقتين
// الكبيرتين ويسألان أهو في الشاشة أم خارجها. واللافتةُ الإعلانيّةُ صورةٌ لا
// نصَّ فيها، فيُسأل موضعُ الشريط نفسِه.)

// (وذهب من هنا `_card` و`_activeCategories` — مساعِدان كانا يجدان بطاقةَ
// قسمٍ في شبكة الرئيسية ويقرآن أيُّها نشط. لا شبكةَ هناك الآن، ونظيرُهما
// في `directory_test` حيث الأقسام.)

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
    await _settle(tester);

    final bar = tester.widget<GlassNavBar>(find.byType(GlassNavBar));
    expect(
      bar.items.map((i) => i.label).toList(),
      ['الرئيسية', 'حجوزاتي', 'استكشف', 'خطة العرس', 'حسابي'],
    );
  });

  testWidgets('الرئيسية هي المفتوحة أوّلاً', (tester) async {
    await tester.pumpWidget(_wrap(_session()));
    await _settle(tester);
    expect(tester.widget<GlassNavBar>(find.byType(GlassNavBar)).index, 0);
    // العنوان في الشريط الزجاجي يتبع التبويب المفتوح.
    expect(tester.widget<GlassHeader>(find.byType(GlassHeader)).title, 'الرئيسية');
  });

  testWidgets('الضغط ينقل التبويب ويغيّر العنوان', (tester) async {
    await tester.pumpWidget(_wrap(_session()));
    await _settle(tester);

    await tester.tap(find.text('حسابي').last);
    await tester.pumpAndSettle();

    expect(tester.widget<GlassNavBar>(find.byType(GlassNavBar)).index, 4);
    expect(tester.widget<GlassHeader>(find.byType(GlassHeader)).title, 'حسابي');
  });

  testWidgets('**واللافتةُ الإعلانيّةُ تُمرَّر بالإبهام**', (tester) async {
    // **وسقط هنا اختباران** كانا يقيسان البطاقتين الكبيرتين — «خطة العرس»
    // و«حجوزاتي» — تمريرَهما بالإبهام، وفتحَ بطاقةِ الحجوزات لتبويبها.
    // حُذفت البطاقتان وصارت المساحةُ للإعلانات بطلبِ صاحب المنصّة، وبابُ
    // كلٍّ منهما قائمٌ في الشريط السفلي (ويحرسه «الضغط ينقل التبويب»).
    //
    // وبقي من ضمانِهما ما يبقى: **أنّ الشريطَ يُمرَّر**. والدورانُ التلقائيُّ
    // وحدَه لا يكفي — من مدّ إصبعَه ينتظر أن ينتقل.
    _phone(tester);
    await tester.pumpWidget(_wrap(_session()));
    await _settle(tester);

    int page() => tester
        .widget<PageView>(find.byType(PageView))
        .controller!
        .page!
        .round();
    final before = page();

    // والجرُّ إلى اليمين تقدّمٌ في العربية لا رجوع.
    await _swipe(tester);

    expect(page(), isNot(before), reason: 'لم تنتقل اللافتةُ بالإبهام');
  });

  // **وسقطت هنا أربعةُ اختبارات** كانت تقيس شبكةَ الأقسام في الرئيسية:
  // «الأقسام كلُّها لا بعضها»، و«بطاقةُ القسم تفتح الاستكشاف على قسمها»،
  // و«استكشف من الشريط تفتحه بلا مرشِّح»، و«لا تبقى بطاقةٌ شفّافة».
  //
  // حُذفت الشبكةُ لأنّها تكرّر صفَّ الأقسام في «استكشف» — وهو هناك مرشِّحٌ
  // يعمل في مكانه، وكانت هنا بابَ عبورٍ إليه.
  //
  // **ولم تُرمَ ضماناتُها.** انتقل ما بقي منه معنىً إلى `directory_test`
  // حيث الأقسامُ الآن: «الأقسام كلُّها تُعرض» و«لا تبقى بطاقةٌ شفّافة بعد
  // الدخول المتدرّج». وذهب الآخران مع ما كانا يقيسانه: لا بابَ من الرئيسية
  // إلى قسمٍ بعينه، فلا مرشِّحَ يُحمل بين الشاشتين ولا مسحَ يُنسى.

  testWidgets('المحتوى يمرّ تحت الزجاج', (tester) async {
    // `extendBody` هو ما يعطي التمويهَ ما يموّهه. ولولا `glassNavSpace` في
    // حشوة القوائم لاختفت آخرُ بطاقةٍ خلف الشريط.
    await tester.pumpWidget(_wrap(_session()));
    await _settle(tester);
    expect(tester.widget<Scaffold>(find.byType(Scaffold).first).extendBody, isTrue);
    expect(glassNavSpace, greaterThan(66));
    // والأعلى كذلك: الشريط في `Stack` لا في خانة `appBar`، فيمرّ المحتوى
    // خلفه ويجد التمويهُ ما يموّهه.
    expect(find.byType(AppBar), findsNothing);
    expect(glassHeaderSpace, greaterThan(glassHeaderBar));
  });

  // **وسقط هنا اختباران** — «البحثُ من الرئيسية» و«حقلٌ فارغٌ لا ينقل
  // أحداً». كانا يقيسان حقلَ بحثٍ في الرئيسية حُذف: كان يكرّر بحثَ شاشة
  // الاستكشاف، ويحمل ما كُتب إليها لتبحث هي. فلا سلوكَ بقي يُقاس.
}
