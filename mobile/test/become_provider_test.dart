// «تقديم خدمة» — الحقولُ المغلقة بدل جدار الشرائح.
//
// **والعلّةُ أنّ النموذجَ كان يمتدّ صفحتين.** المحافظاتُ عشرون شريحةً
// والأقسامُ ستّ، فتُدفع بها بقيّةُ النموذج وزرُّ الإرسال تحت الطيّة —
// ومن فتح الشاشةَ لا يرى كم بقي عليه.
//
// فصارت المحافظةُ منسدلةً كما في «عنوان جديد» و«تعديل الملف»، والأقسامُ
// حقلاً مغلقاً يفتح ورقةَ اختيارٍ متعدّد.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/screens/account_extras.dart';
import 'package:aras/src/screens/become_provider.dart';
import 'package:aras/src/ui/kit.dart';

Session _session() => Session()
  ..userId = 'u1'
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
  home: Directionality(textDirection: TextDirection.rtl, child: child),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester, {double height = 3600}) {
  tester.view.physicalSize = Size(1080, height);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _open(WidgetTester tester) async {
  _phone(tester);
  await tester.pumpWidget(_wrap(BecomeProviderScreen(session: _session())));
  await _settle(tester);
}

void main() {
  group('تقديم خدمة', () {
    testWidgets('**ولا جدارَ شرائحَ في النموذج**', (tester) async {
      // وهي علّةُ الباب: عشرون شريحةً للمحافظة وستٌّ للأقسام تدفع زرَّ
      // الإرسال تحت الطيّة.
      await _open(tester);
      expect(find.byType(PickChip), findsNothing,
          reason: 'الشرائحُ عادت إلى النموذج');
    });

    testWidgets('**والمحافظةُ منسدلةٌ فيها كلُّ المحافظات**', (tester) async {
      await _open(tester);
      final field = find.byType(DropdownButtonFormField<String>);
      expect(field, findsOneWidget);

      await tester.tap(field);
      await _settle(tester);

      // **ويُقاس عددُ ما فُتح لا وجودُ القائمة.** منسدلةٌ فارغةٌ تُفتح ولا
      // تُظهر شيئاً، ومن فتحها ظنّ الشاشةَ عاطلة.
      for (final g in demoGovernorates) {
        expect(find.text(g.name), findsWidgets, reason: '${g.name} ليست في القائمة');
      }
    });

    testWidgets('**وما يُختار منها هو ما يصل الخادم**', (tester) async {
      // **ولا يُسأل الحقلُ عمّا فيه — فهو يكذب.** `DropdownButtonFormField`
      // حقلُ نموذجٍ يحتفظ باختياره **داخلَ نفسه**، فيعرضه للعين ولو لم يصل
      // `onChanged` شيئاً. كسرتُ `onChanged` إلى دالّةٍ فارغةٍ فبقي الاسمُ
      // مكتوباً في الحقل وبقيت الحزمةُ خضراء — والطلبُ يُرسَل بمحافظةٍ
      // فارغة.
      //
      // فيُقاس **ما وصل** لا ما رُسم: النموذجُ يُملأ ويُرسل، ثمّ يُسأل
      // الملفُّ الذي أنشأه الخادم.
      demoProviderProfile = null;
      addTearDown(() => demoProviderProfile = null);

      await _open(tester);
      final pick = demoGovernorates[1].name;

      await tester.enterText(find.byType(TextField).at(0), 'قاعة التجربة');
      await tester.enterText(find.byType(TextField).at(1), '770000000');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await _settle(tester);
      await tester.tap(find.text(pick).last);
      await _settle(tester);

      await tester.tap(find.byKey(const ValueKey('categories-field')));
      await _settle(tester);
      await tester.tap(find.text(demoCategories.first.name));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'تمّ'));
      await _settle(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'إرسال الطلب'));
      await _settle(tester);

      expect(demoProviderProfile, isNotNull, reason: 'لم يُرسَل الطلبُ أصلاً');
      expect(demoProviderProfile!.governorate, pick,
          reason: 'المحافظةُ المختارةُ لم تصل الخادم');
    });

    testWidgets('**وحقلُ الأقسام يقول ما لم يُختر بعد**', (tester) async {
      // حقلٌ فارغٌ بلا كلمةٍ لا يقول إن كان مطلوباً أم اختيارياً.
      await _open(tester);
      expect(find.byKey(const ValueKey('categories-field')), findsOneWidget);
      expect(find.text('اختر قسماً واحداً على الأقل'), findsOneWidget);
    });

    testWidgets('**والورقةُ اختيارٌ متعدّدٌ لا تُغلق عند كلّ ضغطة**',
        (tester) async {
      // **وهذا سببُ ألّا تكون منسدلةً:** قائمةُ المادّة تُغلق عند كلّ
      // اختيار، فمن أراد ثلاثةَ أقسامٍ فتحها ثلاثاً.
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('categories-field')));
      await _settle(tester);

      expect(find.byType(CheckboxListTile), findsNWidgets(demoCategories.length));

      await tester.tap(find.text(demoCategories[0].name));
      await tester.pump();
      await tester.tap(find.text(demoCategories[1].name));
      await tester.pump();

      // الورقةُ ما زالت مفتوحةً بعد اختيارين.
      expect(find.byType(CheckboxListTile), findsNWidgets(demoCategories.length),
          reason: 'الورقةُ أُغلقت عند أوّل اختيار');

      final boxes = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .toList();
      expect(boxes[0].value, isTrue);
      expect(boxes[1].value, isTrue);
      expect(boxes[2].value, isFalse);
    });

    testWidgets('**و«تمّ» مطفأٌ حتى يُختار قسم**', (tester) async {
      // الخادمُ يرفض طلباً بلا قسم، فزرٌّ يُغلق الورقةَ ثمّ يردّه النموذجُ
      // بخطأٍ أسوأُ من زرٍّ مطفأ.
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('categories-field')));
      await _settle(tester);

      final done = find.widgetWithText(FilledButton, 'تمّ');
      expect(tester.widget<FilledButton>(done).onPressed, isNull);

      await tester.tap(find.text(demoCategories.first.name));
      await tester.pump();
      expect(tester.widget<FilledButton>(done).onPressed, isNotNull);
    });

    testWidgets('**وما اختير في الورقة يُكتب في الحقل بعد إغلاقها**',
        (tester) async {
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('categories-field')));
      await _settle(tester);

      await tester.tap(find.text(demoCategories.first.name));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'تمّ'));
      await _settle(tester);

      // الورقةُ أُغلقت، والاسمُ في الحقل.
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.text(demoCategories.first.name), findsOneWidget);
      expect(find.text('اختر قسماً واحداً على الأقل'), findsNothing);
    });

    testWidgets('ولا يفيض النموذجُ بخطّ الجهاز الكبير', (tester) async {
      for (final scale in [1.3, 2.0]) {
        _phone(tester, height: 6000);
        await tester.pumpWidget(_wrap(MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: BecomeProviderScreen(session: _session()),
        )));
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: 'فاض عند $scale');
        await tester.pumpWidget(const SizedBox.shrink());
        await _settle(tester);
      }
    });
  });

  group('محفظة الحساب', () {
    testWidgets('**والوسيلةُ منسدلةٌ بعنوانها لا شرائحُ بلا عنوان**',
        (tester) async {
      // كانت الشرائحُ العنصرَ الوحيدَ في الورقة بلا عنوان، وتحتها حقلان
      // بعنوانيهما — فيُقرأ الصفُّ الأوّلُ زينةً لا سؤالاً.
      _phone(tester);
      await tester.pumpWidget(_wrap(const PaymentMethodsScreen()));
      await _settle(tester);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'وسيلة جديدة'));
      await _settle(tester);

      expect(find.byKey(const ValueKey('wallet-method')), findsOneWidget);
      expect(find.byType(PickChip), findsNothing);
      // والعنوانُ مكتوب.
      expect(find.text('الوسيلة'), findsWidgets);
    });
  });
}
