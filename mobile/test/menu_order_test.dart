// ترتيبُ الأبواب في «حسابي» وفي «ملفّي» — وصفُّ البصمة معهما.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// عدَّ صاحبُ المنصّة أبوابَ الشاشتين بأرقامها، واختار للبصمة الشكلَ (ج):
// صفٌّ بمفتاحٍ يُشغّل ويُطفئ في مكانه لا بابٌ يفتح شاشة. وزاد للمزوّد:
// «وخليه كلهن دخل بطاقة كامل».
//
// ── ويُقاس الترتيبُ لا الوجود ───────────────────────────────────────────────
//
// قائمةٌ فيها الأبوابُ كلُّها بترتيبٍ آخرَ تمرّ لو قيس وجودُ كلِّ بابٍ وحدَه
// — **والترتيبُ هو الطلبُ بعينه**. فتُقرأ النصوصُ بترتيب شجرة العناصر
// وتُقارَن قائمةً بقائمة.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/screens/account.dart';
import 'package:aras/src/screens/provider_profile.dart';
import 'package:aras/src/ui/kit.dart';

Session _session({required bool provider}) => Session()
  ..userId = 'u1'
  ..email = 'ayman@sdd.company'
  ..appUserId = 'a1'
  ..providerId = provider ? 'p1' : null
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
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(body: child),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// نصوصُ الشاشة بترتيب شجرتها — منها يُقرأ الترتيب.
List<String> _labels(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data)
    .whereType<String>()
    .toList();

void main() {
  group('أبوابُ «حسابي»', () {
    testWidgets('**بالترتيب الذي طُلب — لمن له ملفُّ مزوّد**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(AccountScreen(session: _session(provider: true))));
      await _settle(tester);

      const wanted = [
        'الملف الشخصي',
        'التبديل إلى وضع مقدّم الخدمة',
        'فواتيري',
        'المفضّلة',
        'العناوين',
        'طرق الدفع',
        'الإعدادات',
        'الدعم',
        'النزاعات',
        'تسجيل الخروج',
      ];
      expect(_labels(tester).where(wanted.contains).toList(), wanted,
          reason: 'الترتيبُ ليس ما طُلب');
    });

    testWidgets('**ومن لا ملفَّ له يرى «أريد تقديم خدمة» في الموضع نفسِه**',
        (tester) async {
      // **البابُ واحدٌ بوجهين** — ولو نُقل أحدُ الوجهين ونُسي الآخرُ لَاختلف
      // ترتيبُ الشاشتين وهما شاشةٌ واحدة.
      _phone(tester);
      await tester.pumpWidget(_wrap(AccountScreen(session: _session(provider: false))));
      await _settle(tester);

      final labels = _labels(tester);
      expect(labels.indexOf('أريد تقديم خدمة'), labels.indexOf('الملف الشخصي') + 1,
          reason: 'وجهُ الباب الآخر ليس ثانياً');
      expect(find.text('التبديل إلى وضع مقدّم الخدمة'), findsNothing,
          reason: 'عُرض الوجهان معاً');
    });
  });

  group('أبوابُ «ملفّي» في وضع المزوّد', () {
    // **والملفُّ لا يوجد حتى يُطلب.** `demoProviderProfile` يبدأ فارغاً
    // عمداً، وشاشةُ من لا ملفَّ له بابٌ واحدٌ لا قائمة — فلو تُرك فارغاً
    // لَقيس الاختبارُ تلك الشاشةَ لا هذه.
    setUp(() => demoBecomeProvider(
          businessName: 'قاعة التاج',
          governorate: 'أمانة العاصمة',
          bio: 'قاعةٌ لأعراس صنعاء',
        ));

    testWidgets('**بالترتيب الذي طُلب**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _wrap(ProviderProfileScreen(session: _session(provider: true))),
      );
      await _settle(tester);

      const wanted = [
        'ملفّي كما يراه العميل',
        'العودة إلى وضع العميل',
        'تعديل الاسم والتعريف',
        'مستندات التوثيق',
        'الباقات والاشتراك',
        'مستحقّاتي',
        'الدعم',
        'تسجيل الخروج',
      ];
      expect(_labels(tester).where(wanted.contains).toList(), wanted,
          reason: 'الترتيبُ ليس ما طُلب');
    });

    testWidgets('**وبطاقةٌ واحدةٌ متّصلةٌ بلا فاصل**', (tester) async {
      // «خليه كلهن دخل بطاقة كامل» — والفاصلُ شريطٌ رماديٌّ يقطعها.
      _phone(tester);
      await tester.pumpWidget(
        _wrap(ProviderProfileScreen(session: _session(provider: true))),
      );
      await _settle(tester);

      expect(find.byType(MenuSheet), findsOneWidget);
      expect(find.byType(MenuGap), findsNothing, reason: 'بقي فاصلٌ يقطع البطاقة');
    });
  });
}
