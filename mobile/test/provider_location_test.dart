// موقعُ المحلّ: يضعه مقدّمُ الخدمة، ويراه العميل.
//
// **وكان الطرفان مكسورين:**
//
//   ١. المزوّدُ يضع دبّوسه ويحفظ، ثمّ يفتح الورقةَ فيجد «لم يُحدَّد موقع» —
//      لأنّ العمودين لم يكونا في قائمة الأعمدة التي تُقرأ أصلاً. فيظنّ
//      الحفظَ لم يقع، ويعيده، ويظنّه لا يعمل.
//   ٢. والعميلُ لا يرى الموقعَ في شيء — يُحفظ ويُرتَّب به البحث ولا يُعرض.
//      ومن قرأ «أمانة العاصمة» لا يعرف أفي حدّة هو أم في سعوان.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/geo.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/provider_public.dart';

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

void _phone(WidgetTester tester, {double height = 6000}) {
  tester.view.physicalSize = Size(1080, height);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

final _mapButton = find.byKey(const ValueKey('open-provider-map'));

void main() {
  // ==========================================================================
  //  **الطرف الأوّل: المزوّد يقرأ ما حفظ**
  // ==========================================================================

  group('ملفُّ المزوّد يقرأ نقطته', () {
    test('**الصفُّ فيه نقطةٌ تُقرأ نقطةً**', () {
      // ولولا هذا لَكان يضع الدبّوس ويحفظ ثمّ يجد الحقلَ فارغاً — فيظنّ
      // الحفظَ لم يقع.
      final p = ProviderProfile.fromMap({
        'id': 'p1',
        'latitude': 15.3350,
        'longitude': 44.1780,
      });
      expect(p.point, const GeoPoint(15.3350, 44.1780));
    });

    test('وقاعدةٌ بلا عمودين تُقرأ بلا نقطةٍ لا بانكسار', () {
      // وهي القاعدةُ التي لم يُشغَّل عليها `nearby.sql` بعد.
      final p = ProviderProfile.fromMap({'id': 'p1'});
      expect(p.point, isNull);
    });

    test('ونصفُ نقطةٍ تُقرأ لا شيء', () {
      final p = ProviderProfile.fromMap({'id': 'p1', 'latitude': 15.3});
      expect(p.point, isNull);
    });

    test('**وصفرٌ صفرٌ ليس نقطة**', () {
      // «جزيرة نُل» في خليج غينيا — وما يصل إليها في تطبيقٍ يمنيّ إنّما هو
      // حقلٌ لم يُملأ فقُرئ صفراً.
      final p = ProviderProfile.fromMap({
        'id': 'p1', 'latitude': 0, 'longitude': 0,
      });
      expect(p.point, isNull);
    });
  });

  // ==========================================================================
  //  **الطرف الثاني: العميل يرى أين المحلّ**
  // ==========================================================================

  testWidgets('**العميلُ يرى بطاقةَ الموقع وزرَّ الخرائط**', (tester) async {
    _phone(tester);
    // «قاعة التاج» في وضع العرض لها نقطةٌ في السنينة.
    await tester.pumpWidget(_wrap(
      const PublicProviderScreen(providerId: 'p1', name: 'قاعة التاج')));
    await _settle(tester);

    expect(find.text('موقع المحلّ'), findsOneWidget);
    expect(_mapButton, findsOneWidget);
  });

  testWidgets('**ولا تظهر لمزوّدٍ بلا نقطة**', (tester) async {
    // «مركز النجم» بلا نقطةٍ عمداً في وضع العرض. وبطاقةٌ تقول «الموقع غير
    // محدَّد» عقوبةٌ له وخبرٌ لا ينفع من يقرؤه.
    _phone(tester);
    await tester.pumpWidget(_wrap(
      const PublicProviderScreen(providerId: 'p5', name: 'مركز النجم')));
    await _settle(tester);

    expect(find.text('موقع المحلّ'), findsNothing);
    expect(_mapButton, findsNothing);
  });

  testWidgets('وزرُّ الخرائط يُضغط بلا انكسار', (tester) async {
    // لا تطبيقَ خرائطَ في بيئة الاختبار، فالمقيسُ أنّه لا يرمي — لا أنّه
    // يفتح. وذاك يُجرَّب على جهاز.
    _phone(tester);
    await tester.pumpWidget(_wrap(
      const PublicProviderScreen(providerId: 'p1', name: 'قاعة التاج')));
    await _settle(tester);

    await tester.tap(_mapButton);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
