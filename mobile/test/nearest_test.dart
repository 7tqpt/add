// «الأقربُ إليّ» في شاشة الاستكشاف.
//
// **وما يُقاس هنا أربعة:**
//
//   ١. أنّ المفتاح **لا يظهر** لمن لا عنوانَ له بنقطة — ومفتاحٌ يُضغط فلا
//      يتغيّر شيءٌ أسوأُ من مفتاحٍ غائب.
//   ٢. وأنّ رفعه **يبدّل الترتيبَ فعلاً** — لا أنّه يُلوَّن فحسب.
//   ٣. وأنّ المسافةَ تُكتب على البطاقة حين يكون الترتيبُ بها، **ولا تُكتب
//      قبله** — رقمٌ على قائمةٍ لم تُرتَّب به يُقرأ ترتيباً فيُكذَّب.
//   ٤. وأنّ من لا نقطةَ له يبقى في القائمة آخِراً.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/explore.dart';
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

/// شاشةٌ طويلةٌ عمداً — **٣٠٠٠ نقطةٍ منطقيّة**.
///
/// **و`skipOffstage: false` لا تُغني عنها في `ListView`:** ما تحت الطيّة لا
/// يُبنى أصلاً، فلا يجده باحثٌ مهما تساهل. والترتيبُ لا يُقاس على نصف قائمة.
void _phone(WidgetTester tester, {double height = 9000}) {
  tester.view.physicalSize = Size(1080, height);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

Future<void> _openExplore(WidgetTester tester) async {
  await tester.pumpWidget(_wrap(const Scaffold(body: ExploreScreen())));
  await _settle(tester);
}

final _chip = find.byKey(const ValueKey('nearest-chip'));

/// أسماءُ المزوّدين بترتيب ظهورهم في بطاقات الخدمات.
List<String> _order(WidgetTester tester) => tester
    .widgetList<ServiceListCard>(find.byType(ServiceListCard, skipOffstage: false))
    .map((c) => c.item.providerName)
    .toList();

void main() {
  setUp(demoResetAccountExtras);

  // ==========================================================================
  //  ظهورُ المفتاح
  // ==========================================================================

  testWidgets('المفتاحُ يظهر لمن عنوانُه الافتراضيّ فيه نقطة', (tester) async {
    _phone(tester);
    await _openExplore(tester);

    expect(_chip, findsOneWidget);
  });

  testWidgets('**ولا يظهر لمن لا نقطةَ في دفتره**', (tester) async {
    // ولا تُترك ضغطةٌ لا تفعل شيئاً: من ضغطها ولم تتغيّر القائمةُ يظنّ
    // التطبيقَ معلّقاً.
    _phone(tester);
    demoAddresses = [
      const SavedAddress(
        id: 'ad1',
        label: 'بيت العرس',
        details: 'حدة، خلف جامع الرحمة',
        governorate: 'أمانة العاصمة',
        governorateId: null,
        isDefault: true,
      ),
    ];
    await _openExplore(tester);

    expect(_chip, findsNothing);
  });

  testWidgets('ولا يظهر لمن لا عنوانَ له أصلاً', (tester) async {
    _phone(tester);
    demoAddresses = [];
    await _openExplore(tester);

    expect(_chip, findsNothing);
  });

  // ==========================================================================
  //  أثرُ الرفع
  // ==========================================================================

  testWidgets('**ورفعُه يبدّل الترتيب**', (tester) async {
    // وهذا هو الاختبارُ الذي يقول إنّ الميزةَ تعمل. ولو كان المفتاحُ يُلوَّن
    // ولا يُمرَّر إلى الطريقة لَمرّ كلُّ ما فوقه وسقط هذا وحده.
    _phone(tester);
    await _openExplore(tester);
    final before = _order(tester);

    await tester.tap(_chip);
    await _settle(tester);
    final after = _order(tester);

    expect(after, isNot(equals(before)), reason: 'الترتيبُ لم يتبدّل');
    expect(after.length, before.length, reason: 'سقطت خدماتٌ من القائمة');
  });

  testWidgets('**والأقربُ إلى حدّة أوّلاً**', (tester) async {
    // العنوانُ الافتراضيّ في حدّة، وأقربُ المزوّدين إليها «قاعة التاج» في
    // السنينة — لا «ديكور الياسمين» في سعوان على طرف المدينة الآخر.
    _phone(tester);
    await _openExplore(tester);
    await tester.tap(_chip);
    await _settle(tester);

    final order = _order(tester);
    expect(order.first, 'قاعة التاج');
    expect(order.indexOf('ديكور الياسمين'),
        greaterThan(order.indexOf('مطبخ الأصالة')),
        reason: 'سعوان أبعدُ من الزبيري عن حدّة');
  });

  testWidgets('**ومن لا نقطةَ له آخراً لا خارجَ القائمة**', (tester) async {
    // «مركز النجم» بلا نقطةٍ في وضع العرض — وهو مزوّدٌ موثَّقٌ يعمل.
    _phone(tester);
    await _openExplore(tester);
    await tester.tap(_chip);
    await _settle(tester);

    final order = _order(tester);
    expect(order, contains('مركز النجم'), reason: 'اختفى من لا نقطةَ له');
    expect(order.last, 'مركز النجم');
  });

  // ==========================================================================
  //  المسافةُ على البطاقة
  // ==========================================================================

  testWidgets('**والمسافةُ لا تُكتب قبل رفع المفتاح**', (tester) async {
    // رقمٌ على قائمةٍ لم تُرتَّب به يُقرأ ترتيباً: يُظنّ الأوّلُ أقربَ وهو
    // ليس كذلك.
    _phone(tester);
    await _openExplore(tester);

    expect(find.textContaining(' كم', skipOffstage: false), findsNothing);
  });

  testWidgets('**ولا تُكتب في الدليل قبله**', (tester) async {
    // ودليلُ المزوّدين مسلكٌ ثانٍ للرقم نفسه — يُقاس وحده، وإلّا انكسر
    // صامتاً وحده.
    _phone(tester);
    await _openExplore(tester);
    await tester.tap(find.text('مقدّمو الخدمة'));
    await _settle(tester);

    expect(find.textContaining(' كم', skipOffstage: false), findsNothing);
  });

  testWidgets('وتُكتب في الدليل بعده', (tester) async {
    _phone(tester);
    await _openExplore(tester);
    await tester.tap(find.text('مقدّمو الخدمة'));
    await _settle(tester);
    await tester.tap(_chip);
    await _settle(tester);

    expect(find.textContaining(' كم', skipOffstage: false), findsWidgets);
  });

  testWidgets('وتُكتب بعده', (tester) async {
    _phone(tester);
    await _openExplore(tester);
    await tester.tap(_chip);
    await _settle(tester);

    expect(find.textContaining(' كم', skipOffstage: false), findsWidgets);
  });

  testWidgets('ولا تُكتب على بطاقةِ من لا نقطةَ له', (tester) async {
    // وكتابةُ «غير معروف» على بطاقته عقوبةٌ لا خبر.
    _phone(tester);
    await _openExplore(tester);
    await tester.tap(_chip);
    await _settle(tester);

    final card = tester
        .widgetList<ServiceListCard>(find.byType(ServiceListCard, skipOffstage: false))
        .firstWhere((c) => c.item.providerName == 'مركز النجم');
    expect(card.item.providerPoint, isNull);
    expect(
      find.descendant(
        of: find.byWidget(card),
        matching: find.textContaining(' كم', skipOffstage: false),
        skipOffstage: false,
      ),
      findsNothing,
    );
  });

  // ==========================================================================
  //  الدليلُ كذلك
  // ==========================================================================

  testWidgets('والدليلُ يُرتَّب بالقرب أيضاً', (tester) async {
    _phone(tester);
    await _openExplore(tester);
    await tester.tap(find.text('مقدّمو الخدمة'));
    await _settle(tester);
    await tester.tap(_chip);
    await _settle(tester);

    // «قاعة التاج» في السنينة أقربُ إلى حدّة من «استوديو السعادة» في عدن.
    final names = tester
        .widgetList<Text>(find.byType(Text, skipOffstage: false))
        .map((t) => t.data ?? '')
        .toList();
    expect(names.indexOf('قاعة التاج'),
        lessThan(names.indexOf('استوديو السعادة')));
  });

  // ==========================================================================
  //  المحافظةُ تبقى مرشِّحاً معه
  // ==========================================================================

  testWidgets('**والمحافظةُ لا تُلغى برفع المفتاح**', (tester) async {
    // ولو أسقط مسلكُ «الأقرب» المحافظةَ لَكذبت الشاشةُ على صاحبها: يختار
    // «عدن» فتأتيه صنعاء.
    _phone(tester);
    await _openExplore(tester);
    await tester.tap(_chip);
    await _settle(tester);
    await tester.tap(find.text('عدن'));
    await _settle(tester);

    final cards = tester
        .widgetList<ServiceListCard>(find.byType(ServiceListCard, skipOffstage: false))
        .toList();
    expect(cards, isNotEmpty, reason: 'لا نتائجَ في عدن أصلاً فلا يُقاس شيء');
    expect(cards.every((c) => c.item.providerGovernorate == 'عدن'), isTrue,
        reason: 'المحافظةُ سقطت حين رُفع «الأقرب إليّ»');
  });
}
