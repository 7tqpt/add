// خدمةٌ في قسمٍ ليس من أقسام صاحبها تنتظر موافقةَ الإدارة — `lib/src/screens/services.dart`.
//
// ردّ صاحبُ المنصّة الحقلَ المقفل: «مقدم الخدمة يختار القسم الذي يبغى بس
// لايمكنه تغيير الي بعلم الادارة»، واختار (ج). فالمنسدلةُ بالأقسام كلِّها،
// وما يُختار خارج أقسامه يُقال تحته إنّه ينتظر، ويُحفظ «بانتظار الموافقة»، وتحمل
// بطاقتُه شارتَها — والمرفوضةُ سببَها.
//
// والقاعدةُ هي الحَكَم (`supabase/tests/provider_category_lock.test.mjs`)؛ وما هنا
// يقيس أنّ التطبيقَ يقول ويعرض — **ويُقاس ما وصل «الخادم»** (`demoMyServices`)
// في وضع العرض، الذي يحسب الموافقةَ بقاعدة القاعدة نفسِها.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/services.dart';

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

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Session _provider() => Session()
  ..userId = 'u1'
  ..appUserId = 'a1'
  ..providerId = 'demo-provider'
  ..loading = false;

final _mine = demoCategories[0]; // القاعات والخيام
final _other = demoCategories[2]; // التصوير والإضاءة

MyService _service({
  String categoryId = 'c1',
  String approval = 'approved',
  String note = '',
}) => MyService(
  id: 's1',
  title: 'تصوير حفلات',
  description: '',
  price: 150000,
  priceTo: null,
  unit: 'للحجز',
  depositPercent: 30,
  categoryId: categoryId,
  isActive: true,
  approval: approval,
  approvalNote: note,
);

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(_wrap(ServicesScreen(session: _provider())));
  await _settle(tester);
}

Future<void> _pick(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('service-category-field')));
  await _settle(tester);
  await tester.tap(find.text(name).last);
  await _settle(tester);
}

void main() {
  setUp(() {
    demoMyServices = [];
    demoProviderCategoryIds = {_mine.id};
  });

  group('«خدمة جديدة»', () {
    testWidgets('**الأقسامُ كلُّها تُعرض — لا قسمُه وحده**', (tester) async {
      _phone(tester);
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('new-service')));
      await _settle(tester);
      final field = tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>));
      expect(field.items!.map((i) => i.value).toSet(), demoCategories.map((c) => c.id).toSet());
    });

    testWidgets('**وما ليس من أقسامه يُقال تحته — وقسمُه لا**', (tester) async {
      _phone(tester);
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('new-service')));
      await _settle(tester);

      await _pick(tester, _mine.name);
      expect(find.byKey(const ValueKey('service-category-pending')), findsNothing);
      await _pick(tester, _other.name);
      expect(find.byKey(const ValueKey('service-category-pending')), findsOneWidget);
      expect(find.textContaining('بعد موافقة الإدارة'), findsOneWidget);
    });

    testWidgets('**ويُحفظ «بانتظار الموافقة» — وفي قسمه موافَقاً عليه**', (tester) async {
      _phone(tester);
      await _open(tester);
      for (final (name, title) in [(_other.name, 'تصوير حفلات'), (_mine.name, 'قاعة الأفراح')]) {
        await tester.tap(find.byKey(const ValueKey('new-service')));
        await _settle(tester);
        await tester.enterText(find.byType(TextField).at(0), title);
        await tester.enterText(find.byType(TextField).at(2), '150000');
        await _pick(tester, name);
        await tester.tap(find.widgetWithText(FilledButton, 'إضافة'));
        await _settle(tester);
      }
      final byTitle = {for (final s in demoMyServices) s.title: s.approval};
      expect(byTitle, {'تصوير حفلات': 'pending', 'قاعة الأفراح': 'approved'});
    });
  });

  group('بطاقةُ الخدمة', () {
    testWidgets('**المنتظرةُ تحمل شارتَها وسطرَها**', (tester) async {
      _phone(tester);
      demoMyServices = [_service(categoryId: _other.id, approval: 'pending')];
      await _open(tester);
      expect(find.text('بانتظار موافقة الإدارة'), findsOneWidget);
      expect(find.byKey(const ValueKey('service-approval-s1')), findsOneWidget);
    });

    testWidgets('**والمرفوضةُ سببَها — وتعديلُها يُعيدها للمراجعة**', (tester) async {
      _phone(tester);
      demoMyServices = [_service(categoryId: _other.id, approval: 'rejected', note: 'خارج نشاط القاعة')];
      await _open(tester);
      expect(find.text('مرفوضة'), findsOneWidget);
      expect(find.textContaining('خارج نشاط القاعة'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'تعديل'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
      await _settle(tester);
      expect(demoMyServices.single.approval, 'pending', reason: 'المرفوضةُ المعدَّلةُ لم تعد للمراجعة');
    });

    testWidgets('**وما وُوفق عليه بعينه لا يُقال له «ينتظر» حين يُعدَّل سعرُه**', (tester) async {
      _phone(tester);
      demoMyServices = [_service(categoryId: _other.id, approval: 'approved')];
      await _open(tester);
      expect(find.text('معروضة'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'تعديل'));
      await _settle(tester);
      expect(find.byKey(const ValueKey('service-category-pending')), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
      await _settle(tester);
      expect(demoMyServices.single.approval, 'approved');
    });
  });
}
