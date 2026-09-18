// حقلُ «القسم» في ورقة «خدمة جديدة» — منسدلةٌ لا شريطَ شرائح.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «القسم أبغى تكون قائمة منسدلة». وهو نفسُ ما صار قبلُ لحقل القسم وحقل
// المحافظة في «تقديم خدمة» — فالحقلان في التطبيق كلِّه على شكلٍ واحد.
//
// ── ولا يُسأل الحقلُ عمّا فيه ───────────────────────────────────────────────
//
// `DropdownButtonFormField` حقلُ نموذجٍ **يحتفظ باختياره داخلَ نفسه**،
// فيعرضه للعين ولو لم يصل `onChanged` شيئاً ولو لم يصل الخادمَ شيء. فيُقاس
// **ما وصل** — `categoryId` في `demoMyServices` بعد الحفظ — لا ما تعرضه
// الشاشة. وهذا بعينه ما كشف عيباً في حقل «تقديم خدمة» من قبل.
//
// **ويُقاس المعرّفُ لا الاسم**: وضعُ `c.name` في `value` بدل `c.id` يمرّ في
// العين تماماً، ثمّ يصل الخادمَ نصّاً عربيّاً بدل `uuid` فيُرفض الطلب.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/services.dart';
import 'package:aras/src/ui/kit.dart';

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

MyService _service({String categoryId = 'c1'}) => MyService(
  id: 's1',
  title: 'قاعة التاج',
  description: '',
  price: 850000,
  priceTo: null,
  unit: 'للحجز',
  depositPercent: 30,
  categoryId: categoryId,
  isActive: true,
);

/// يفتح ورقةَ «خدمة جديدة» بالضغط الحقيقيّ على الزرّ العائم.
Future<void> _openNew(WidgetTester tester) async {
  await tester.pumpWidget(_wrap(ServicesScreen(session: _provider())));
  await _settle(tester);
  await tester.tap(find.widgetWithText(FloatingActionButton, 'خدمة جديدة'));
  await _settle(tester);
}

void main() {
  setUp(() {
    // **حالٌ في الذاكرة يبقى بين اختبارٍ وآخر** — فمن حفظ هنا وجده التالي
    // محفوظاً فمرّ وهو لا يقيس شيئاً.
    demoMyServices = [_service()];
  });

  group('شكلُ الحقل', () {
    testWidgets('**منسدلةٌ واحدةٌ — ولا شريحةَ قسمٍ باقية**', (tester) async {
      _phone(tester);
      await _openNew(tester);

      expect(find.byKey(const ValueKey('service-category-field')), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      // شريطُ الشرائح زال — وهو الطلبُ بعينه.
      expect(find.byType(PickChip), findsNothing,
          reason: 'عاد شريطُ الشرائح');
    });

    testWidgets('**وأقسامُ القاعدة كلُّها في القائمة**', (tester) async {
      _phone(tester);
      await _openNew(tester);

      await tester.tap(find.byKey(const ValueKey('service-category-field')));
      await _settle(tester);
      for (final c in demoCategories) {
        expect(find.text(c.name), findsWidgets, reason: '${c.name} ليست فيها');
      }
    });

    testWidgets('**ولا تُسمّى «القسم» مرّتين**', (tester) async {
      // عنوانٌ فوق الحقل وعنوانٌ طافٍ داخلَه = كلمةٌ مكرّرةٌ تُقرأ عطباً.
      // وهذا ما كشفته اللقطةُ قبل التنفيذ لا اختبار.
      _phone(tester);
      await _openNew(tester);

      expect(find.text('القسم'), findsOneWidget,
          reason: 'عنوانُ «القسم» مكتوبٌ مرّتين');
    });
  });

  group('ما يصل الخادم', () {
    testWidgets('**القسمُ المختارُ هو ما يُحفَظ — بمعرّفه**', (tester) async {
      _phone(tester);
      demoMyServices = [];
      await _openNew(tester);

      await tester.enterText(find.byType(TextField).at(0), 'قاعة التجربة');
      // الوصفُ يُترك فارغاً عمداً: ليس شرطاً للحفظ.
      await tester.enterText(find.byType(TextField).at(2), '500000');

      await tester.tap(find.byKey(const ValueKey('service-category-field')));
      await _settle(tester);
      await tester.tap(find.text(demoCategories[2].name).last);
      await _settle(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'إضافة'));
      await _settle(tester);

      expect(demoMyServices, isNotEmpty, reason: 'لم تُحفظ الخدمةُ أصلاً');
      // **والمعرّفُ لا الاسم.**
      expect(demoMyServices.first.categoryId, demoCategories[2].id,
          reason: 'وصل الخادمَ غيرُ معرّفِ القسم المختار');
    });

    testWidgets('**وبلا قسمٍ لا تُحفَظ — ويُقال السبب**', (tester) async {
      _phone(tester);
      demoMyServices = [];
      await _openNew(tester);

      await tester.enterText(find.byType(TextField).at(0), 'قاعة بلا قسم');
      await tester.enterText(find.byType(TextField).at(2), '500000');

      await tester.tap(find.widgetWithText(FilledButton, 'إضافة'));
      await _settle(tester);

      expect(demoMyServices, isEmpty, reason: 'حُفظت خدمةٌ بلا قسم');
      expect(find.text('اكتب اسم الخدمة وسعرها، واختر قسمها.'), findsOneWidget);
    });
  });

  group('تعديلُ خدمةٍ قائمة', () {
    testWidgets('**يفتح الحقلُ على قسمها لا فارغاً**', (tester) async {
      _phone(tester);
      demoMyServices = [_service(categoryId: demoCategories[3].id)];

      await tester.pumpWidget(_wrap(ServicesScreen(session: _provider())));
      await _settle(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'تعديل'));
      await _settle(tester);

      final field = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const ValueKey('service-category-field')),
      );
      expect(field.initialValue, demoCategories[3].id,
          reason: 'فُتح الحقلُ على غير قسم الخدمة');
    });
  });
}
