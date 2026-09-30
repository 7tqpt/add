// «أكمل ملفك» — **ولا «من أنت؟» قبلها.**
//
// كانت تسبق النموذجَ صفحةٌ فيها «أنا عروس» و«أنا عريس» و«مقدّم خدمة»،
// فحذفها صاحبُ المنصّة: «احذف لي هذا صفحة نهائي»، واختار أن تُحذف **وحدها**
// — والشارةُ تبقى «عميل» لكلّ جديد، ومقدّمُ الخدمة يفتح ملفّه من «حسابي».
//
// **وما يُقاس هنا أنّها لا تعود:** من سجّل يرى النموذجَ أوّلَ ما يرى.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/screens/onboarding.dart';
import 'package:aras/src/ui/kit.dart';

Session _session() => Session()
  ..userId = 'u-new'
  ..email = 'new@sdd.company'
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
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: OnboardingScreen(session: s),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('**النموذجُ أوّلَ ما يُرى — لا «من أنت؟» قبله**', (tester) async {
    await tester.pumpWidget(_wrap(_session()));
    await _settle(tester);

    expect(find.text('أكمل ملفك'), findsOneWidget,
        reason: 'من سجّل لا يرى النموذجَ أوّلاً');
    expect(find.byType(TextField), findsNWidgets(2),
        reason: 'حقلا الاسم والجوال ليسا أوّلَ الشاشة');
    for (final gone in [
      'مرحباً بك في فرحتي',
      'أنا عروس',
      'أنا عريس',
      'مقدّم خدمة',
    ]) {
      expect(find.text(gone), findsNothing, reason: 'عادت «$gone» — والصفحةُ محذوفة');
    }
  });

  testWidgets('**ولا سهمَ رجوعٍ إلى صفحةٍ حُذفت**', (tester) async {
    // كان في الرأس سهمٌ «غيّر الاختيار» يعود إلى «من أنت؟». وسهمٌ يبقى بعد
    // حذف وجهته إمّا لا يفعل شيئاً وإمّا يُخرج من التطبيق.
    await tester.pumpWidget(_wrap(_session()));
    await _settle(tester);

    expect(find.byTooltip('غيّر الاختيار'), findsNothing);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byIcon(Icons.arrow_forward), findsNothing);
    // **والمخرجُ باقٍ** لمن لا يريد المتابعة.
    expect(find.text('تسجيل الخروج'), findsOneWidget);
  });

  // ── المحافظة: منسدلةٌ لا جدارُ شرائح ──────────────────────────────────────
  //
  // **والعلّةُ أنّ النموذجَ كان يمتدّ صفحتين.** المحافظاتُ عشرون، فسبعةُ
  // صفوفٍ من الشرائح تدفع زرَّ «متابعة» تحت الطيّة — ومن فتح الشاشةَ لا يرى
  // كم بقي عليه. وهي الشاشةُ الأولى التي يراها من سجّل.

  Future<void> openForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(_session()));
    await _settle(tester);
  }

  testWidgets('**ولا جدارَ شرائحَ للمحافظة**', (tester) async {
    await openForm(tester);
    expect(find.byType(PickChip), findsNothing,
        reason: 'الشرائحُ عادت إلى النموذج');
    expect(find.byKey(const ValueKey('governorate-field')), findsOneWidget);
  });

  testWidgets('**والزرُّ يُرى مع الحقول في شاشةٍ واحدة**', (tester) async {
    // وهذا هو المطلوبُ بعينه: لا تمريرَ لِيُرى «متابعة».
    await openForm(tester);
    final button = find.widgetWithText(FilledButton, 'متابعة');
    expect(button, findsOneWidget);
    final box = tester.getRect(button);
    final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(box.bottom, lessThan(screen),
        reason: 'زرُّ المتابعة تحت الطيّة — ${box.bottom} من $screen');
  });

  testWidgets('وكلُّ المحافظات في القائمة', (tester) async {
    await openForm(tester);
    await tester.tap(find.byKey(const ValueKey('governorate-field')));
    await _settle(tester);
    for (final g in demoGovernorates) {
      expect(find.text(g.name), findsWidgets, reason: '${g.name} ليست فيها');
    }
  });

  testWidgets('**والمحافظةُ المختارةُ هي ما يصل الخادم**', (tester) async {
    // **ولا يُسأل الحقلُ عمّا فيه — فهو يكذب.** `DropdownButtonFormField`
    // يحتفظ باختياره داخلَ نفسه فيعرضه للعين ولو لم يصل `onChanged` شيئاً.
    await openForm(tester);
    await tester.enterText(find.byType(TextField).at(0), 'محمد الصنعاني');
    await tester.enterText(find.byType(TextField).at(1), '770000000');

    await tester.tap(find.byKey(const ValueKey('governorate-field')));
    await _settle(tester);
    await tester.tap(find.text(demoGovernorates[2].name).last);
    await _settle(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'متابعة'));
    await _settle(tester);

    expect(demoProfile()?.governorate, demoGovernorates[2].name,
        reason: 'وصل الخادمَ غيرُ ما اختاره');
  });

  testWidgets('**ولا يمرّ نموذجٌ بلا محافظة**', (tester) async {
    await openForm(tester);
    await tester.enterText(find.byType(TextField).at(0), 'محمد الصنعاني');
    await tester.enterText(find.byType(TextField).at(1), '770000000');
    await tester.tap(find.widgetWithText(FilledButton, 'متابعة'));
    await _settle(tester);
    // **ونصُّ الخطأ بعينه لا كلمةٌ منه:** النصُّ الإرشاديُّ «اختر محافظتك»
    // يشترك معه في الكلمة، فسؤالٌ بالاحتواء يجد اثنين ويسقط وإن كان
    // السلوكُ صحيحاً — وقد سقط.
    expect(find.text('اكتب اسمك ورقمك واختر محافظتك.'), findsOneWidget);
  });
}
