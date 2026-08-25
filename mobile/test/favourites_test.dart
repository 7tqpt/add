// المفضّلة: ما حُفظ يُعرض، وما لم يعد متاحاً يُقال.
//
// **والعطبُ الذي تسدّه هذه الشاشة لا يُرى في أي اختبارٍ آخر:** القلب في
// الاستكشاف كان يحفظ الصفّ فعلاً — واختباراتُ الاستكشاف تمرّ خضراء — ثم لا
// يوجد في التطبيق كلِّه مكانٌ يعرض ما حُفظ. فما يُقاس هنا ليس الضغطة بل
// وصولُ ما حُفظ إلى عين صاحبه.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/data/api.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/favourites.dart';
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
  home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: child)),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => demoFavourites = {});

  testWidgets('الفارغةُ تقول كيف تُملأ لا «لا يوجد» وحدها', (tester) async {
    await tester.pumpWidget(_wrap(const FavouritesScreen()));
    await _settle(tester);

    expect(find.text('لا شيء في المفضّلة بعد'), findsOneWidget);
    // الإرشادُ جزءٌ من الشاشة الفارغة: من لا يعرف أين القلب لا يملأها أبداً.
    expect(find.textContaining('اضغط القلب'), findsOneWidget);
    expect(find.byType(ServiceListCard), findsNothing);
  });

  testWidgets('وما حُفظ يُعرض صفّاً لكلٍّ', (tester) async {
    final saved = demoServices.take(2).toList();
    demoFavourites = saved.map((s) => s.id).toSet();

    await tester.pumpWidget(_wrap(const FavouritesScreen()));
    await _settle(tester);

    expect(find.byType(ServiceListCard), findsNWidgets(2));
    // والاسمُ نفسه لا عددٌ وحده: بطاقتان بأيّ محتوىً تمرّان بلا هذا.
    expect(find.text(saved.first.title), findsOneWidget);
    expect(find.text(saved[1].title), findsOneWidget);
  });

  testWidgets('والإزالة تُخرج الصفّ من القائمة لا تُطفئ قلباً ويبقى', (tester) async {
    demoFavourites = demoServices.take(2).map((s) => s.id).toSet();

    await tester.pumpWidget(_wrap(const FavouritesScreen()));
    await _settle(tester);
    expect(find.byType(ServiceListCard), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.favorite).first);
    await _settle(tester);

    expect(find.byType(ServiceListCard), findsOneWidget);
    expect(demoFavourites.length, 1);
    // وبابُ رجوعٍ من ضغطةٍ خاطئة.
    expect(find.text('تراجع'), findsOneWidget);
  });

  testWidgets('وما لم يعد متاحاً يُقال بعددِه', (tester) async {
    // خدمةٌ حُفظت ثم أُوقفت: `v_services` تُخفيها، فتنقص القائمة. والصمتُ
    // هنا يُقرأ «التطبيق أضاع حفظي».
    demoFavourites = {demoServices.first.id, 'خدمةٌ-لا-وجود-لها'};

    await tester.pumpWidget(_wrap(const FavouritesScreen()));
    await _settle(tester);

    expect(find.byType(ServiceListCard), findsOneWidget);
    expect(find.textContaining('لم تعد متاحة'), findsOneWidget);
  });

  test('والطبقةُ تحت الشاشة تعدّ الناقص لا تبتلعه', () async {
    demoFavourites = {demoServices.first.id, 'أ', 'ب'};
    final data = await Api.favouriteServices();
    expect(data.items.length, 1);
    expect(data.missing, 2);
  });
}
