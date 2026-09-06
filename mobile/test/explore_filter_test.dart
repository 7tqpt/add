// حقلُ البحث ومرشِّحُ المحافظات في شاشة التصفّح.
//
//   ١. **نصُّ البحث كان أطولَ من حقله** — «ابحث عن قاعة، مصوّر، طبّاخ…» يُقصّ
//      على شاشة الجوال إلى «…ابحث عن قاعة، مصوّر، طبا». رأيتُه في لقطةٍ من
//      جهازٍ حقيقيّ، والمقصوصُ يُقرأ عطباً لا اقتراحاً.
//   ٢. **والمحافظاتُ كانت صفّاً يُمرَّر** — يعمل، لكنّ لا شيء فيه يقول إنّ
//      خلفه ستّ عشرة محافظةً أخرى. من لا يعرف أنّ الصفّ يُسحَب يرى ثلاثاً
//      فيظنّها كلَّ ما في المنصّة.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/explore.dart';
import 'package:aras/src/ui/kit.dart';
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
      home: child,
    );

/// انتظارٌ يسع تأخيرَ وضع العرض ومؤقّتاتِ الدخول.
///
/// **و`pumpAndSettle` وحدها لا تكفي**: لا تحرّك الساعةَ ما لم يُجدول إطار،
/// وشاشةُ التحميل لا تجدول شيئاً — فيبقى المؤقّتُ معلّقاً ويُسقط الإطارُ
/// الاختبارَ بـ«A Timer is still pending». وقعت لي في أوّل صياغة.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// يبني الشاشةَ وينتظر وصولَ المحافظات.
Future<void> _open(WidgetTester tester, {double width = 1080}) async {
  tester.view.physicalSize = Size(width, 3000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_wrap(const Scaffold(body: ExploreScreen())));
  await _settle(tester);
}

const _field = ValueKey('governorate-field');

void main() {
  group('حقلُ البحث', () {
    testWidgets('**نصُّه قصيرٌ لا يُقصّ**', (tester) async {
      await _open(tester);
      final hint = tester
          .widgetList<TextField>(find.byType(TextField))
          .first
          .decoration!
          .hintText!;
      // **والقياسُ على الطول لا على الحرف.** لو قيس بالمساواة لَمرّ أيُّ نصٍّ
      // طويلٍ آخر يُكتب مكانه غداً.
      expect(hint.length, lessThan(12), reason: 'نصٌّ طويلٌ يُقصّ في الحقل: «$hint»');
      expect(hint, startsWith('ابحث عن'));
    });

    testWidgets('**وشعارُه في الطرف الأيسر**', (tester) async {
      // **ويُقاس بالموضع لا باسم المعامل.** `prefixIcon` تضعه يميناً في
      // العربيّة و`suffixIcon` يساراً — والاسمُ وحده لا يقول ذلك لمن يقرأ،
      // وقد يُبدَّل الاتّجاهُ يوماً. فيُقاس أين رُسم فعلاً.
      await _open(tester);
      final field = tester.renderObject<RenderBox>(find.byType(TextField).first);
      final left = field.localToGlobal(Offset.zero).dx;
      final right = left + field.size.width;

      final icon = tester.renderObject<RenderBox>(find.descendant(
          of: find.byType(TextField).first, matching: find.byIcon(Icons.search)));
      final ix = icon.localToGlobal(Offset.zero).dx + icon.size.width / 2;

      expect(ix, lessThan((left + right) / 2),
          reason: 'الشعارُ في يمين الحقل لا يساره: $ix في [$left, $right]');
    });

    testWidgets('**وحدُّه قرصٌ كاملُ الاستدارة**', (tester) async {
      await _open(tester);
      final d = tester
          .widgetList<TextField>(find.byType(TextField))
          .first
          .decoration!
          .enabledBorder! as OutlineInputBorder;
      // الاستدارةُ الكاملةُ ما بلغ نصفَ الارتفاع فأكثر — و٩٩٩ تعني «أقصى ما
      // يمكن»، والقياسُ عليها لا على رقمٍ يُبدَّل.
      expect(d.borderRadius.topRight.x, greaterThan(100));
    });
  });

  group('مرشِّحُ المحافظات', () {
    testWidgets('**زرٌّ واحدٌ لا صفٌّ يُمرَّر**', (tester) async {
      await _open(tester);
      expect(find.byKey(_field), findsOneWidget);
      // **ولا شريحةَ محافظةٍ باقية.**
      //
      // و«الأقرب إليّ» شريحةٌ تبقى — ظننتُها تغيب في بيئة الاختبار لعدم وجود
      // عنوانٍ محفوظ، فكتبتُ `findsNothing` فسقط الاختبار: بياناتُ العرض فيها
      // عنوانٌ افتراضيٌّ بنقطة. فيُقاس المقصودُ بعينه — أسماءُ المحافظات — لا
      // «لا شريحةَ ألبتّة».
      final chips = tester.widgetList<PickChip>(find.byType(PickChip));
      expect(chips.map((c) => c.label), ['الأقرب إليّ']);
    });

    testWidgets('**ومغلقُه يقول «كل المحافظات» قبل الاختيار**', (tester) async {
      await _open(tester);
      expect(
        find.descendant(of: find.byKey(_field), matching: find.text('كل المحافظات')),
        findsOneWidget,
      );
    });

    testWidgets('**ويُفتح على الورقة وفيها المحافظاتُ كلُّها**', (tester) async {
      await _open(tester);
      await tester.tap(find.byKey(_field));
      await _settle(tester);

      expect(find.text('اختر المحافظة'), findsOneWidget);
      // ثلاثٌ من أوّل القائمة وواحدةٌ من آخرها: لو عُرض بعضُها فقط لَسقط.
      for (final g in ['أمانة العاصمة', 'عدن', 'تعز']) {
        expect(find.text(g), findsWidgets, reason: g);
      }
    });

    testWidgets('**والمختارُ يُكتب في المغلق ويُعلَّم في المفتوح**',
        (tester) async {
      await _open(tester);
      await tester.tap(find.byKey(_field));
      await _settle(tester);
      await tester.tap(find.text('عدن').last);
      await _settle(tester);

      // **في المغلق**: من قصّ نتائجَه على محافظةٍ يجب أن يراها بلا أن يفتح.
      expect(
        find.descendant(of: find.byKey(_field), matching: find.text('عدن')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(_field), matching: find.text('كل المحافظات')),
        findsNothing,
      );

      // **وفي المفتوح**: علامةُ صحٍّ عند المختار.
      //
      // **والبحثُ داخل الورقة لا في الشجرة كلِّها.** `find.byIcon` وحدها
      // وجدت اثنتين: صحّي، وصحٌّ أبيضُ حجمُه ٧٫٣ في بطاقةِ خدمةٍ خلف الورقة.
      await tester.tap(find.byKey(_field));
      await _settle(tester);
      expect(
        find.descendant(
            of: find.byType(BottomSheet), matching: find.byIcon(Icons.check_rounded)),
        findsOneWidget,
      );
    });

    testWidgets('**و«كل المحافظات» تمسح المرشِّح لا تُطلب محافظةً بهذا الاسم**',
        (tester) async {
      // **ولا يكفي أن يُقرأ في المغلق «كل المحافظات».** لو أُرسل الاسمُ نصّاً
      // لَقرأه المغلقُ كما هو تماماً — والفرقُ في النتائج لا في السطر: طلبُ
      // محافظةٍ اسمُها «كل المحافظات» يُرجع لا شيء. فيُقاس ما يُعرض.
      //
      // كشفه ضابطٌ سالبٌ كسرتُه فلم يسقط: لم يكن في الاختبارات ما يعود من
      // محافظةٍ إلى الكلّ أصلاً.
      await _open(tester);
      final all = find.byType(ServiceListCard).evaluate().length;
      expect(all, greaterThan(1), reason: 'لا نتائجَ أصلاً فلا شيء يُقاس');

      await tester.tap(find.byKey(_field));
      await _settle(tester);
      await tester.tap(find.text('عدن').last);
      await _settle(tester);
      expect(find.byType(ServiceListCard).evaluate().length, lessThan(all),
          reason: 'المرشِّحُ لم يقصّ شيئاً، فالعودةُ منه لا تُقاس');

      await tester.tap(find.byKey(_field));
      await _settle(tester);
      await tester.tap(find.text('كل المحافظات').last);
      await _settle(tester);
      expect(find.byType(ServiceListCard).evaluate().length, all,
          reason: 'لم تعد النتائجُ كما كانت — المرشِّحُ لم يُمسح');
    });

    testWidgets('**وسحبُ الورقة بلا اختيارٍ لا يُبدّل المرشِّح**',
        (tester) async {
      // **و`null` من الورقة تعني «أُغلقت» لا «كل المحافظات».** ولو خُلط بينهما
      // لَمسحَ الإغلاقُ مرشِّحَ من اختار «عدن» ثمّ فتح الورقةَ ليطالع غيرها.
      await _open(tester);
      await tester.tap(find.byKey(_field));
      await _settle(tester);
      await tester.tap(find.text('تعز').last);
      await _settle(tester);

      await tester.tap(find.byKey(_field));
      await _settle(tester);
      // إغلاقٌ بالضغط خارج الورقة — كما يفعل من عدل عن رأيه.
      await tester.tapAt(const Offset(20, 20));
      await _settle(tester);

      expect(
        find.descendant(of: find.byKey(_field), matching: find.text('تعز')),
        findsOneWidget,
        reason: 'ضاع المرشِّحُ بمجرّد فتح الورقة وإغلاقها',
      );
    });

    // **والشاشةُ الضيّقةُ هي التي تفيض.** ٣٢٠ منطقيّاً أضيقُ ما يُباع، والزرُّ
    // فيه اسمُ محافظةٍ وأيقونتان وشريحةُ «الأقرب» بجانبه.
    for (final w in [960.0, 1080.0, 1200.0]) {
      testWidgets('**ولا يفيض عند عرض ${w ~/ 3} منطقيّاً**', (tester) async {
        await _open(tester, width: w);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
