// العناوين، وطرقُ الدفع، والإعدادات، وشارةُ الدور.
//
// **وأهمُّ ما يُقاس هنا أنّ ما كان صفّاً في لوحة تصميم صار باباً يفتح.**
// وثلاثةُ حرّاسٍ تخصّ المعنى لا الشكل:
//
//   ١) شارةُ «حسابي» تقول «عريس» لمن قال إنه عريس — كانت تقول «عميل».
//   ٢) الافتراضيُّ واحدٌ لا اثنان، وحذفُه يرفع غيرَه مكانه.
//   ٣) شاشةُ الإعدادات تقول ما يُحذف قبل أن يُحذف، ولا تحذف بضغطةٍ واحدة.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/account.dart';
import 'package:aras/src/screens/account_extras.dart';
import 'package:aras/src/screens/payment.dart';

Session _session({bool provider = false}) => Session()
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
  home: Directionality(textDirection: TextDirection.rtl, child: child),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    demoResetAccountExtras();
    demoSetWeddingRole('');
  });

  // ==========================================================================
  //  شارةُ الدور
  // ==========================================================================

  test('اسمُ الدور يتبع ما حُفظ', () {
    expect(weddingRoleLabel('bride', provider: false), 'عروس');
    expect(weddingRoleLabel('groom', provider: false), 'عريس');
    // والفراغُ يقع على صفة الحساب: من جاء ليبيع لا ليعرس.
    expect(weddingRoleLabel('', provider: false), 'عميل');
    expect(weddingRoleLabel('', provider: true), 'مقدّم خدمة');
  });

  testWidgets('و«حسابي» تقول «عريس» لمن قال إنه عريس', (tester) async {
    // **وهذا ما كان مكسوراً:** الاختيار يُسأل عنه في «اختر نوع الحساب» ثمّ
    // يُنسى — يعيش في ذاكرة التشغيل لا في القاعدة — فتقول الشارة «عميل».
    _phone(tester);
    demoSetWeddingRole('groom');
    await tester.pumpWidget(_wrap(Scaffold(body: AccountScreen(session: _session()))));
    await _settle(tester);

    expect(find.text('عريس'), findsOneWidget);
    expect(find.text('عميل'), findsNothing);
  });

  // ==========================================================================
  //  الأبواب الثلاثة
  // ==========================================================================

  testWidgets('والأبوابُ الثلاثة صارت في القائمة', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(Scaffold(body: AccountScreen(session: _session()))));
    await _settle(tester);

    for (final door in ['العناوين', 'طرق الدفع', 'الإعدادات']) {
      expect(find.text(door, skipOffstage: false), findsOneWidget, reason: door);
    }
  });

  // ==========================================================================
  //  العناوين
  // ==========================================================================

  testWidgets('العنوانُ المحفوظ يُعرض بمحافظته، والافتراضيُّ مُعلَّم', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(const AddressesScreen()));
    await _settle(tester);

    expect(find.text('بيت العرس'), findsOneWidget);
    expect(find.textContaining('حدة'), findsOneWidget);
    // بلا علامةٍ لا يعرف صاحبُ ثلاثة عناوين أيُّها سيملأ نموذج الحجز.
    expect(find.text('الافتراضي'), findsOneWidget);
  });

  testWidgets('ويُحفظ عنوانٌ جديد فيصير هو الافتراضيّ ولا يبقى اثنان', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(const AddressesScreen()));
    await _settle(tester);

    await tester.tap(find.text('عنوان جديد'));
    await _settle(tester);

    await tester.enterText(find.widgetWithText(TextField, 'الاسم'), 'القاعة');
    await tester.enterText(
      find.widgetWithText(TextField, 'العنوان'), 'شارع الستين، قاعة التاج');
    await tester.tap(find.text('اجعله الافتراضي'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await _settle(tester);

    expect(demoAddresses.length, 2);
    expect(demoAddresses.where((a) => a.isDefault).length, 1,
        reason: 'افتراضيّان يجعلان نموذج الحجز لا يعرف أيَّهما يملأ به');
    expect(demoAddresses.firstWhere((a) => a.isDefault).label, 'القاعة');
  });

  testWidgets('وعنوانٌ قصيرٌ يُردّ ولا يُحفظ', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(const AddressesScreen()));
    await _settle(tester);

    await tester.tap(find.text('عنوان جديد'));
    await _settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'العنوان'), 'حدة');
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await _settle(tester);

    expect(find.textContaining('بتفصيلٍ يكفي'), findsOneWidget);
    expect(demoAddresses.length, 1);
  });

  test('وحذفُ الافتراضيّ يرفع غيرَه مكانه', () {
    demoSaveAddress(label: 'القاعة', details: 'شارع الستين، قاعة التاج',
        makeDefault: true);
    expect(demoAddresses.where((a) => a.isDefault).length, 1);

    final def = demoAddresses.firstWhere((a) => a.isDefault);
    demoDeleteAddress(def.id);

    expect(demoAddresses.length, 1);
    expect(demoAddresses.single.isDefault, isTrue,
        reason: 'قائمةٌ بلا افتراضيٍّ تترك نموذج الحجز بلا ما يملأ به');
  });

  // ==========================================================================
  //  طرقُ الدفع
  // ==========================================================================

  testWidgets('طرقُ الدفع تقول ما يُحفظ وما لا يُحفظ', (tester) async {
    // **ومن رأى «طرق الدفع» ظنّ بطاقةً تُخزَّن، ومن ظنّ ذلك امتنع.**
    _phone(tester);
    await tester.pumpWidget(_wrap(const PaymentMethodsScreen()));
    await _settle(tester);

    await tester.tap(find.text('وسيلة جديدة'));
    await _settle(tester);

    expect(find.textContaining('ولا نحفظ بطاقات ولا أرقاماً سرّية'), findsOneWidget);
  });

  testWidgets('ورقمُ المحفظة يُرسم من اليسار داخل صفحةٍ عربية', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(const PaymentMethodsScreen()));
    await _settle(tester);

    final ref = tester.widget<Text>(find.text('770000000'));
    expect(ref.textDirection, TextDirection.ltr,
        reason: 'رقمُ حوالةٍ مقلوبٌ يُحوَّل به إلى غير صاحبه');
  });

  // ==========================================================================
  //  الإعدادات
  // ==========================================================================

  testWidgets('الإشعاراتُ مفتاحان لا واحد', (tester) async {
    // من أطفأ الدعاية لا يقصد أن يفوته «قُبل حجزك».
    _phone(tester);
    await tester.pumpWidget(_wrap(SettingsScreen(session: _session())));
    await _settle(tester);

    expect(find.text('إشعارات الحجوزات والرسائل'), findsOneWidget);
    expect(find.text('العروض والإعلانات'), findsOneWidget);

    await tester.tap(find.text('العروض والإعلانات'));
    await _settle(tester);
    expect(demoSettings.promos, isFalse);
    expect(demoSettings.push, isTrue, reason: 'أُطفئت الدعاية فأُطفئ معها الحجز');
  });

  testWidgets('وحذفُ الحساب يُسأل عنه ويُقال ما سيضيع', (tester) async {
    // **شرطُ متجر Google، ولا رجعةَ فيه.** فيُقال ما يُحذف وما يبقى قبل أن
    // يُضغط، لا بعده.
    _phone(tester);
    await tester.pumpWidget(_wrap(SettingsScreen(session: _session())));
    await _settle(tester);

    final button = find.text('حذف الحساب');
    await tester.scrollUntilVisible(button, 200,
        scrollable: find.byType(Scrollable).first);
    await _settle(tester);
    await tester.tap(button);
    await _settle(tester);

    expect(find.text('حذف الحساب نهائياً؟'), findsOneWidget);
    // ونصُّ الزرّ يقول ما سيقع لا «موافق».
    expect(find.widgetWithText(FilledButton, 'احذف حسابي'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'إلغاء'), findsOneWidget);
    // ويُقال إنّ السجلَّ الماليَّ يبقى — فلا يظنّ أنه يمحو أثره كلَّه.
    expect(find.textContaining('سجلٌّ ماليٌّ'), findsOneWidget);
  });

  testWidgets('واللغةُ تُعرض ولا يُعرض مبدِّلٌ لخيارٍ واحد', (tester) async {
    // قائمةٌ فيها خيارٌ واحد تُوهم بثانٍ لا وجود له.
    _phone(tester);
    await tester.pumpWidget(_wrap(SettingsScreen(session: _session())));
    await _settle(tester);

    expect(find.text('العربية'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  });

  // ==========================================================================
  //  الوصل: الدفترُ يملأ الحقل بدل أن يُكتب في كل مرّة
  // ==========================================================================

  testWidgets('ورقةُ الحوالة تملأ الرقم من المحفظة الافتراضية', (tester) async {
    // **وهذا ما يجعل الدفتر نافعاً.** دفترٌ لا يملأ شيئاً قائمةٌ يزورها
    // صاحبها مرّةً ثمّ ينساها، والرقمُ يبقى يُكتب مع كل حوالة — ورقمٌ يُكتب
    // بالغلط يُبطئ مطابقة الحوالة أو يمنعها.
    _phone(tester);
    await tester.pumpWidget(_wrap(PaymentScreen(booking: demoBookings.first)));
    await _settle(tester);

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller?.text, demoPaymentMethods.first.accountRef);
  });

  testWidgets('وفيها بابٌ إلى المحافظ لمن أراد غيرَ الافتراضية', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(PaymentScreen(booking: demoBookings.first)));
    await _settle(tester);

    expect(find.byTooltip('من محافظي'), findsOneWidget);
  });

  testWidgets('ودفترٌ فارغٌ لا يُسقط الشاشة ولا يمنع الإبلاغ', (tester) async {
    // **فشلُ الراحة لا يمنع الفعل.** الحقلُ اختياريٌّ أصلاً، وشاشةُ خطأٍ عن
    // دفترٍ لم يُقرأ تمنع صاحبها من الإبلاغ بحوالةٍ دفعها فعلاً.
    _phone(tester);
    demoPaymentMethods = [];
    await tester.pumpWidget(_wrap(PaymentScreen(booking: demoBookings.first)));
    await _settle(tester);

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller?.text, isEmpty);
    expect(find.text('حوّلتُ المبلغ — أبلغ الإدارة'), findsOneWidget);
  });
}
