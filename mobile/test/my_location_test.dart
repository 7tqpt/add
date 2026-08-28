// زرُّ «موقعي الحالي» في منتقي الخريطة.
//
// **وأهمُّ ما يُقاس هنا ليس النجاح بل الفشل.** الطريقُ السعيد يُجرَّب على
// جهازٍ في دقيقة، والذي يُنسى أربعةٌ لا تقع إلّا عند غيرك: خدمةُ موقعٍ
// مطفأة، وإذنٌ مرفوض، وإذنٌ مرفوضٌ **نهائيّاً** (وهذا لا يُعالج بطلبٍ ثانٍ
// بل بالإعدادات)، وموقعٌ لا يصل داخل بناءٍ خرسانيّ.
//
// وكلُّها تُقاس هنا لأنّ `currentLocation` لها بابٌ يُركَّب فيه بديل — ولولاه
// لَما قِيس منها شيءٌ إلّا باليد على خمسة أجهزة.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/device_location.dart';
import 'package:aras/src/core/geo.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/map_picker.dart';

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

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

final _button = find.byKey(const ValueKey('my-location'));
const _aden = GeoPoint(12.788440, 45.036560);

Future<void> _openPicker(WidgetTester tester, {GeoPoint? initial}) async {
  await tester.pumpWidget(_wrap(MapPickerScreen(
    initial: initial,
    governorate: 'أمانة العاصمة',
  )));
  await tester.pump();
}

Future<void> _press(WidgetTester tester) async {
  await tester.tap(_button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  tearDown(() => locationOverride = null);

  // ==========================================================================
  //  **أن تُركَّب الشاشةُ أصلاً بلا استثناء**
  // ==========================================================================

  testWidgets('**الشاشةُ تُبنى بلا استثناءِ تخطيط**', (tester) async {
    // **وهذا الاختبارُ وُلد من عيبٍ وجده غيابُه.** كانت هذه الشاشة الوحيدةَ
    // في التطبيق التي لا تُركَّب في اختبارٍ قطّ — فكانت ترمي ثلاثةَ عشرَ
    // استثناءَ تخطيطٍ عند فتحها ولا يعلم بها أحد: زرُّ «تأكيد الموقع» كان
    // في `Row`، ونمطُ الأزرار في هذا التطبيق يفرض عرضاً لا نهائيّاً.
    //
    // و`flutter_test` يُسقط الاختبارَ من نفسه عند أيّ استثناء، فمجرّدُ
    // التركيب حارس. وهذا يقوله صراحةً حتى لا يُحذف ظنّاً أنّه لا يقيس شيئاً.
    _phone(tester);
    await _openPicker(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('تأكيد الموقع'), findsOneWidget);
  });

  // ==========================================================================
  //  وجودُ الزرّ
  // ==========================================================================

  testWidgets('الزرُّ موجودٌ في الخريطة', (tester) async {
    // وكان ناقصاً: الخريطةُ تُحرَّك بالإصبع أو يُلصق فيها رابط، ومن يقف في
    // القاعة نفسها لم يكن له طريقٌ يقول «أنا هنا».
    _phone(tester);
    await _openPicker(tester);

    expect(_button, findsOneWidget);
  });

  // ==========================================================================
  //  الطريقُ السعيد
  // ==========================================================================

  testWidgets('**وضغطُه ينقل النقطةَ إلى موقع الجهاز**', (tester) async {
    _phone(tester);
    locationOverride = () async => const LocationResult.found(_aden);
    await _openPicker(tester);
    await _press(tester);

    // النصُّ تحت الخريطة يعرض الإحداثيّات — فهو ما يُقاس، لا حالةٌ داخليّة.
    expect(find.textContaining('12.788440'), findsOneWidget);
  });

  testWidgets('ويصير الموقعُ «موضوعاً» فيعمل زرُّ التأكيد', (tester) async {
    // **ولولا هذا لَكان الزرُّ زينة:** من ضغطه ثمّ وجد «تأكيد الموقع» معطَّلاً
    // لا يستطيع حفظ ما وجده.
    _phone(tester);
    locationOverride = () async => const LocationResult.found(_aden);
    await _openPicker(tester);

    final before = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'تأكيد الموقع'));
    expect(before.onPressed, isNull, reason: 'كان مفعَّلاً قبل أن يُوضع شيء');

    await _press(tester);
    final after = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'تأكيد الموقع'));
    expect(after.onPressed, isNotNull);
  });

  // ==========================================================================
  //  **مساراتُ الفشل — وكلُّها تقول ما جرى وما يُفعل**
  // ==========================================================================

  testWidgets('وخدمةُ موقعٍ مطفأةٌ يُقال فيها ذلك', (tester) async {
    _phone(tester);
    locationOverride =
        () async => const LocationResult.failed(LocationFailure.servicesOff);
    await _openPicker(tester);
    await _press(tester);

    expect(find.textContaining('خدمة الموقع مطفأة'), findsOneWidget);
  });

  testWidgets('وإذنٌ مرفوضٌ يُقال فيه «اضغط ثانيةً»', (tester) async {
    _phone(tester);
    locationOverride =
        () async => const LocationResult.failed(LocationFailure.denied);
    await _openPicker(tester);
    await _press(tester);

    expect(find.textContaining('اضغط الزرّ ثانيةً'), findsOneWidget);
  });

  testWidgets('**ورفضٌ نهائيٌّ يُحال إلى الإعدادات لا إلى ضغطةٍ ثانية**',
      (tester) async {
    // وهذا هو الفرقُ الذي يُنسى: بعد الرفض النهائيّ لا يعرض أندرويد الطلبَ
    // أبداً، فمن قيل له «اضغط ثانيةً» يضغط عشراً ولا يقع شيء.
    _phone(tester);
    locationOverride =
        () async => const LocationResult.failed(LocationFailure.deniedForever);
    await _openPicker(tester);
    await _press(tester);

    expect(find.textContaining('إعدادات الجهاز'), findsOneWidget);
    expect(find.textContaining('اضغط الزرّ ثانيةً'), findsNothing,
        reason: 'الرفضُ النهائيُّ لا يُعالج بضغطةٍ ثانية');
  });

  testWidgets('وموقعٌ لا يصل يُقال فيه ذلك', (tester) async {
    _phone(tester);
    locationOverride =
        () async => const LocationResult.failed(LocationFailure.unavailable);
    await _openPicker(tester);
    await _press(tester);

    expect(find.textContaining('تعذّر تحديد موقعك'), findsOneWidget);
  });

  testWidgets('**والفشلُ لا يضع نقطةً**', (tester) async {
    // ولو ترك الفشلُ الموقعَ «موضوعاً» لَحُفظ مركزُ المحافظة موقعاً للعرس،
    // ولَسِيق المصوّر إلى وسط صنعاء بدل بيتٍ في السنينة — وهو أسوأُ من لا
    // موقعَ أصلاً لأنّه يبدو دقيقاً.
    _phone(tester);
    locationOverride =
        () async => const LocationResult.failed(LocationFailure.denied);
    await _openPicker(tester);
    await _press(tester);

    expect(find.text('لم يُحدَّد موقعٌ بعد'), findsOneWidget);
    final confirm = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'تأكيد الموقع'));
    expect(confirm.onPressed, isNull);
  });

  // ==========================================================================
  //  الانتظار
  // ==========================================================================

  testWidgets('**ولا يُضغط مرّتين وهو يقرأ**', (tester) async {
    // نداءان متوازيان يتسابقان على الخريطة، والثاني ينقلها بعد أن استقرّت.
    _phone(tester);
    var calls = 0;
    locationOverride = () async {
      calls++;
      await Future.delayed(const Duration(seconds: 2));
      return const LocationResult.found(_aden);
    };
    await _openPicker(tester);

    await tester.tap(_button);
    await tester.pump();
    expect(tester.widget<FloatingActionButton>(_button).onPressed, isNull,
        reason: 'الزرُّ ما زال يُضغط وهو يقرأ');

    await tester.tap(_button, warnIfMissed: false);
    await tester.pump(const Duration(seconds: 3));
    expect(calls, 1);
  });

  testWidgets('ويدور وهو يقرأ ثمّ يعود', (tester) async {
    _phone(tester);
    locationOverride = () async {
      await Future.delayed(const Duration(seconds: 1));
      return const LocationResult.found(_aden);
    };
    await _openPicker(tester);

    await tester.tap(_button);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pump(const Duration(seconds: 2));
    expect(find.byIcon(Icons.my_location), findsOneWidget);
  });
}
