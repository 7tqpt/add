// ملفُّ مقدّم الخدمة كما يراه العميل، وأبوابُه.
//
// وأكثرُ ما يُختبَر هنا ليس ما يُعرض بل **ما لا يُعرض**: خدماتُ غيره، واسمُه
// مكرّراً في صفحته، وضغطةٌ على اسمه تفتح الخدمة بدل ملفّه.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/explore.dart';
import 'package:aras/src/screens/provider_public.dart';
import 'package:aras/src/screens/service_detail.dart';
import 'package:aras/src/ui/service_card.dart';

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

/// انتظارٌ يسع تأخير وضع العرض.
///
/// `pumpAndSettle` وحدها لا تحرّك الساعة ما لم يُجدول إطار، وكتلةُ التحميل لا
/// تجدول شيئاً — فالتأخيرُ لا ينقضي أبداً.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester, {double height = 3200}) {
  tester.view.physicalSize = Size(1080, height);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('الملفّ يعرض المزوّد وخدماته وآراء عملائه', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(const PublicProviderScreen(providerId: 'p1')));
    await _settle(tester);

    // من هو.
    expect(find.text('قاعة التاج'), findsWidgets);
    expect(find.textContaining('حي السنينة'), findsOneWidget);
    expect(find.text('موثَّق'), findsOneWidget);
    expect(find.text('مميّز'), findsOneWidget);
    expect(find.text('القاعات والخيام'), findsOneWidget);

    // ماذا يعرض — الثلاث كلُّها.
    expect(find.text('قاعة التاج — باقة شاملة', skipOffstage: false), findsOneWidget);
    expect(find.text('قاعة التاج — باقة الخطوبة', skipOffstage: false), findsOneWidget);
    expect(find.text('خيمة أفراح متنقّلة', skipOffstage: false), findsOneWidget);

    // وماذا قال من تعامل معه.
    expect(find.textContaining('قاعة نظيفة والاستقبال', skipOffstage: false), findsOneWidget);
  });

  testWidgets('ولا تظهر فيه خدمةٌ لغيره', (tester) async {
    // **وهذا ما ينكسر بصمت:** استعلامٌ بلا `eq('provider_id', …)` يُعيد كلّ
    // شيء، فتبدو الصفحة عامرةً وهي تنسب إلى صاحبها ما ليس له.
    _phone(tester);
    await tester.pumpWidget(_wrap(const PublicProviderScreen(providerId: 'p1')));
    await _settle(tester);

    expect(find.text('مندي وحنيذ لـ300 شخص', skipOffstage: false), findsNothing);
    expect(find.text('تصوير فيديو وفوتوغرافي', skipOffstage: false), findsNothing);
  });

  testWidgets('واسمُه لا يُكرَّر على كل بطاقةٍ في صفحته', (tester) async {
    // القارئ في صفحة «قاعة التاج» يعرف عند من هو، وتكرارُ الاسم في كل بطاقة
    // يزاحم ما يميّز الخدمات بعضَها عن بعض.
    _phone(tester);
    await tester.pumpWidget(_wrap(const PublicProviderScreen(providerId: 'p1')));
    await _settle(tester);

    final cards = tester.widgetList<ServiceListCard>(
      find.byType(ServiceListCard, skipOffstage: false),
    );
    expect(cards, hasLength(3));
    expect(cards.every((c) => !c.showProvider), isTrue);
  });

  testWidgets('والضغط على خدمةٍ فيه يفتح تفاصيلها', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(const PublicProviderScreen(providerId: 'p1')));
    await _settle(tester);

    await tester.tap(find.text('خيمة أفراح متنقّلة'));
    await _settle(tester);

    expect(find.byType(ServiceDetailScreen), findsOneWidget);
  });

  testWidgets('صفحةُ الخدمة تفتح ملفّ صاحبها', (tester) async {
    // **وهذا ما طلبه صاحب المنتج:** كان اسمُ المزوّد في صفحة الخدمة حرفاً
    // رمادياً لا يُضغط، فلا سبيل من الخدمة إلى صاحبها.
    _phone(tester);
    await tester.pumpWidget(_wrap(const ServiceDetailScreen(serviceId: 's4')));
    await _settle(tester);

    await tester.tap(find.text('عرض ملفّه'));
    await _settle(tester);

    expect(find.byType(PublicProviderScreen), findsOneWidget);
    // ملفُّ صاحبها هو الذي فُتح لا صفحةٌ عامّة: تعريفُه فيها.
    expect(find.textContaining('كوشات الورد الطبيعيّ', skipOffstage: false), findsOneWidget);
  });

  testWidgets('واسمُ المزوّد في قائمة الاستكشاف بابٌ إلى ملفّه لا إلى الخدمة', (
    tester,
  ) async {
    // الاسمُ يقع **داخل** بطاقةٍ كلُّها تُضغط. فلو لم يلتقط الضغطةَ بنفسه
    // لنزلت إلى البطاقة وفُتحت صفحةُ الخدمة — وهو أقربُ الأخطاء وقوعاً هنا.
    _phone(tester);
    // الاستكشاف صفحةُ تبويبٍ لا شاشةً قائمة بذاتها: تعيش داخل `Scaffold`
    // القشرة، فتُعطى واحداً هنا.
    await tester.pumpWidget(_wrap(const Scaffold(body: ExploreScreen())));
    await _settle(tester);

    await tester.tap(find.text('مطبخ الأصالة').first);
    await _settle(tester);

    expect(find.byType(PublicProviderScreen), findsOneWidget);
    expect(find.byType(ServiceDetailScreen), findsNothing);
  });

  testWidgets('وملفٌّ لا وجود له يقول ذلك ولا يسقط', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(const PublicProviderScreen(providerId: 'لا-أحد')));
    await _settle(tester);

    expect(find.text('الملفّ غير متاح'), findsOneWidget);
  });
}
