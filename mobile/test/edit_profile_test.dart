// شاشة تعديل البيانات.
//
// وأهمّ ما يُثبَت هنا أن **البريد ليس حقلاً**: هو هويّة الدخول لا بيانَ ملف،
// وحقلٌ يغيّره في `app_users` وحده يُنتج حساباً يُعرض ببريدٍ ويدخل بآخر.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/edit_profile.dart';

Widget _wrap(Session s) => MaterialApp(
  theme: buildTheme(),
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Directionality(textDirection: TextDirection.rtl, child: EditProfileScreen(session: s)),
);

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'demo@example.com'
  ..appUserId = 'a1'
  ..loading = false;

void main() {
  testWidgets('**ما يُكتب في النموذج اثنان، والرقمُ خرج منه**',
      (tester) async {
    // **والرقمُ ليس كسائر البيانات فلا يُحفظ معها:** تبديلُه يُبطل تأكيدَه
    // في القاعدة فيهبط حاجزُ واتساب فورَ الحفظ. فصار سطراً بزرِّ تعديلٍ
    // صريحٍ له ورقتُه — وهي `showPhoneEditSheet` المشحونةُ نفسُها.
    await tester.pumpWidget(_wrap(_session()));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'الاسم الكامل'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

    expect(find.widgetWithText(TextField, 'رقم الجوال'), findsNothing,
        reason: 'ما زال الرقمُ حقلاً يُحفظ مع الاسم');
    expect(find.byKey(const ValueKey('phone-row')), findsOneWidget);
    expect(find.byKey(const ValueKey('phone-edit')), findsOneWidget);
  });

  testWidgets('والبريد يُعرض ولا يُكتب فيه', (tester) async {
    await tester.pumpWidget(_wrap(_session()));
    await tester.pumpAndSettle();
    // لا حقلَ نصٍّ للبريد بحال — عرضٌ فقط، ومعه سببُ ذلك.
    //
    // **وصار السببُ مطويّاً خلف «لماذا؟»** بعد أن كان بطاقةً كاملةً بشارةٍ
    // وثلاثةِ أسطرٍ خافتة، تُزاحم بمساحتِها ما جاء المستخدمُ ليعدّله.
    // والمقصودُ باقٍ: البريدُ يُعرض، ولا يُكتب فيه، والسببُ متاحٌ لمن سأل.
    expect(find.widgetWithText(TextField, 'البريد الإلكتروني'), findsNothing);
    expect(find.text('demo@example.com'), findsOneWidget);
    expect(find.byKey(const ValueKey('email-why')), findsOneWidget);
  });

  testWidgets('اسمٌ قصير يُرفض قبل أن يُرسل', (tester) async {
    // الحراسة في القاعدة أيضاً، لكن ردَّها يمرّ بالشبكة — ورفضٌ فوريّ أرحم.
    //
    // ونافذةٌ أطول من الافتراضية: زرّ الحفظ آخرُ القائمة، والقوائم في Flutter
    // تبني ما يظهر وحده — فلا يوجد الزرُّ في الشجرة أصلاً على ٦٠٠ بكسل.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(_session()));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'الاسم الكامل'), 'أ');
    // **ودفعةٌ بعد الكتابة.** صار زرُّ الحفظ مطفأً حتى يتغيّر شيء، ويُضاء
    // في الإطار التالي للكتابة — فنقرةٌ قبل الدفعة تقع على زرٍّ ميّتٍ ولا
    // تفعل شيئاً. وهذا تبدّلُ افتراضٍ في الاختبار لا في السلوك: من يكتب
    // بإصبعه تمرّ بين حرفه ونقرته عشراتُ الإطارات.
    await tester.pumpAndSettle();
    // النصّ لا النوع: `FilledButton.icon` تُنتج نوعاً مشتقّاً، و`find.byType`
    // يطابق النوع الحرفيّ وحده فلا يجده.
    final save = find.text('حفظ التعديلات');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('اكتب اسمك كاملاً.'), findsOneWidget);
  });

  testWidgets('زرّ الكاميرا يفتح خيارَي الالتقاط والمعرض', (tester) async {
    await tester.pumpWidget(_wrap(_session()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.photo_camera));
    await tester.pumpAndSettle();
    expect(find.text('التقاط صورة'), findsOneWidget);
    expect(find.text('اختيار من المعرض'), findsOneWidget);
  });

  // ── تبديلُ الرقم ────────────────────────────────────────────────────────────
  //
  // **والثغرةُ التي سُدّت:** من أكّد رقمه ثمّ بدّله بقي «مؤكَّداً» على رقمٍ لم
  // يشهد له أحد. فصارت القاعدةُ تُبطل التأكيدَ عند التبديل — وصار يُقال ذلك
  // لصاحبه **قبل** أن يبدّل، فلا يُفاجأ بحاجزٍ يظنّه إخراجاً من التطبيق.

  Session gated({required bool required_}) => Session()
    ..userId = 'u1'
    ..email = 'demo@example.com'
    ..appUserId = 'a1'
    ..loading = false
    ..phoneGate = PhoneGate(
        required_: required_, verified: true, phone: '+967771234567');

  testWidgets('**ويُقال إنّ تبديلَ الرقم يُلزم بتأكيدٍ جديد**', (tester) async {
    await tester.pumpWidget(_wrap(gated(required_: true)));
    await tester.pumpAndSettle();
    expect(find.textContaining('يُلزمك بتأكيده'), findsOneWidget);
  });

  testWidgets('**ولا يُقال حين لا تأكيدَ مطلوبٌ في المنصّة**', (tester) async {
    // سطرٌ يقول «ستُطالَب بتأكيد» والحاجزُ مطفأٌ يُخيف بلا سبب — وهو كذبٌ
    // صغيرٌ يُفقد الثقةَ بسائر ما تقوله الشاشة.
    await tester.pumpWidget(_wrap(gated(required_: false)));
    await tester.pumpAndSettle();
    expect(find.textContaining('يُلزمك بتأكيده'), findsNothing);
  });
}
