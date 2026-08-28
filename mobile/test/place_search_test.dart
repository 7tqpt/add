// البحثُ عن مكانٍ باسمه في منتقي الخريطة.
//
// **وحقلٌ واحدٌ يقبل الاثنين:** اسمَ مكانٍ أو رابطاً. والفرقُ يُعرف من النصّ
// نفسه لا من صاحبه — وهذا ما يُقاس هنا أكثرَ من غيره، لأنّ خطأه صامت: من
// لصق رابطاً فبُحث عنه اسماً يرى «لم أجد مكاناً» ولا يفهم لماذا.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/geo.dart';
import 'package:aras/src/core/place_search.dart';
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

final _field = find.byKey(const ValueKey('place-field'));

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(_wrap(const MapPickerScreen(governorate: 'أمانة العاصمة')));
  await tester.pump();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_field, text);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

const _saneena = GeoPoint(15.3350, 44.1780);

/// نصُّ الإحداثيّات تحت الخريطة — **بمفتاحه لا بمحتواه**.
///
/// وحقلُ البحث فوقه قد يحمل الإحداثيّتين نفسَهما إن لُصقتا، فباحثٌ يسأل عن
/// النصّ وحده يجد اثنين ولا يدري أيُّهما قرأ. وهذا وقع هنا فعلاً.
String _pointText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('point-text'))).data ?? '';

void main() {
  tearDown(() => placeSearchOverride = null);

  // ==========================================================================
  //  اختصارُ الاسم — دالّةٌ نقيّة
  // ==========================================================================

  group('اختصارُ الاسم', () {
    test('يأخذ ثلاثةَ أجزاءٍ لا العنوانَ كلَّه', () {
      // Nominatim يعيد «السنينة، مديرية معين، أمانة العاصمة، اليمن» —
      // وأربعةُ أسطرٍ لكلّ نتيجةٍ تجعل القائمةَ صفحةً تُمرَّر.
      expect(
        shortPlaceName('السنينة، مديرية معين، أمانة العاصمة، اليمن'),
        'السنينة، مديرية معين، أمانة العاصمة',
      );
    });

    test('واسمٌ قصيرٌ يبقى كما هو', () {
      expect(shortPlaceName('حدة، صنعاء'), 'حدة، صنعاء');
    });

    test('ولا ينكسر على نصٍّ بلا فواصل', () {
      expect(shortPlaceName('السنينة'), 'السنينة');
    });
  });

  // ==========================================================================
  //  **الحقلُ يفرّق بين الاسم والرابط**
  // ==========================================================================

  testWidgets('**رابطٌ فيه إحداثيّتان يُقرأ ولا يُبحث عنه اسماً**',
      (tester) async {
    // ولو بُحث عنه اسماً لَذهب رابطٌ صحيحٌ إلى خدمة البحث فعاد بلا شيء،
    // ورأى صاحبُه «لم أجد مكاناً» وهو يحمل الموقع في يده.
    _phone(tester);
    var searched = false;
    placeSearchOverride = (q) async {
      searched = true;
      return const [];
    };
    await _open(tester);
    await _type(tester, 'https://www.google.com/maps/@15.354722,44.206667,17z');

    expect(searched, isFalse, reason: 'الرابطُ ذهب إلى خدمة البحث');
    expect(_pointText(tester), contains('15.354722'));
  });

  testWidgets('وإحداثيّتان مجرّدتان كذلك', (tester) async {
    _phone(tester);
    var searched = false;
    placeSearchOverride = (q) async {
      searched = true;
      return const [];
    };
    await _open(tester);
    await _type(tester, '15.354722, 44.206667');

    expect(searched, isFalse);
    expect(_pointText(tester), contains('15.354722'));
  });

  testWidgets('**واسمُ مكانٍ يُبحث عنه**', (tester) async {
    _phone(tester);
    String? asked;
    placeSearchOverride = (q) async {
      asked = q;
      return const [Place(name: 'السنينة، معين، أمانة العاصمة', point: _saneena)];
    };
    await _open(tester);
    await _type(tester, 'السنينة');

    expect(asked, 'السنينة');
    expect(find.textContaining('السنينة'), findsWidgets);
  });

  testWidgets('**والرابطُ المختصر لا يُبحث عنه اسماً بل يُقال ما يُفعل**',
      (tester) async {
    // وهو ليس اسماً، فبحثُه عبثٌ ينتهي بـ«لم أجد مكاناً» — والصوابُ أن يُقال
    // له: افتحه أوّلاً ثمّ انسخ الرابط الكامل.
    _phone(tester);
    var searched = false;
    placeSearchOverride = (q) async {
      searched = true;
      return const [];
    };
    await _open(tester);
    await _type(tester, 'https://maps.app.goo.gl/abcd1234');

    expect(searched, isFalse);
    expect(find.textContaining('رابطٌ مختصر'), findsOneWidget);
  });

  // ==========================================================================
  //  اختيارُ النتيجة
  // ==========================================================================

  testWidgets('**واختيارُ نتيجةٍ ينقل الدبّوس ويفعّل التأكيد**', (tester) async {
    _phone(tester);
    placeSearchOverride = (q) async =>
        const [Place(name: 'السنينة، معين، أمانة العاصمة', point: _saneena)];
    await _open(tester);

    final before = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'تأكيد الموقع'));
    expect(before.onPressed, isNull);

    await _type(tester, 'السنينة');
    await tester.tap(find.byKey(const ValueKey('place-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(_pointText(tester), contains('15.335000'));
    final after = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'تأكيد الموقع'));
    expect(after.onPressed, isNotNull);
  });

  testWidgets('وتختفي القائمةُ بعد الاختيار', (tester) async {
    // ولو بقيت لَغطّت زرَّ التأكيد الذي فُتحت لأجله.
    _phone(tester);
    placeSearchOverride = (q) async =>
        const [Place(name: 'السنينة، معين', point: _saneena)];
    await _open(tester);
    await _type(tester, 'السنينة');
    expect(find.byKey(const ValueKey('place-0')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('place-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('place-0')), findsNothing);
  });

  // ==========================================================================
  //  **الفشلُ يُقال — و«لا نتائج» غيرُ «لا شبكة»**
  // ==========================================================================

  testWidgets('ولا نتائجَ يُقال فيها ذلك', (tester) async {
    _phone(tester);
    placeSearchOverride = (q) async => const [];
    await _open(tester);
    await _type(tester, 'زقنبوت');

    expect(find.textContaining('لم أجد مكاناً'), findsOneWidget);
  });

  testWidgets('**وعطلُ الشبكة يُقال غيرَ «لا نتائج»**', (tester) async {
    // ومن قيل له «لا نتائج» وهو مقطوعٌ عن الشبكة يظنّ مكانَه غيرَ موجودٍ
    // فيكفّ عن البحث — والعلاجُ إعادةُ المحاولة لا تبديلُ الاسم.
    _phone(tester);
    placeSearchOverride = (q) async =>
        throw 'تعذّر الوصول إلى خدمة البحث. تحقّق من الشبكة وأعد المحاولة.';
    await _open(tester);
    await _type(tester, 'السنينة');

    expect(find.textContaining('تحقّق من الشبكة'), findsOneWidget);
    expect(find.textContaining('لم أجد مكاناً'), findsNothing);
  });

  testWidgets('والفشلُ لا يضع نقطةً', (tester) async {
    _phone(tester);
    placeSearchOverride = (q) async => const [];
    await _open(tester);
    await _type(tester, 'زقنبوت');

    expect(find.text('لم يُحدَّد موقعٌ بعد'), findsOneWidget);
  });

  // ==========================================================================
  //  أزرارُ التكبير
  // ==========================================================================

  testWidgets('**أزرارُ التكبير موجودةٌ وتعمل**', (tester) async {
    // ومن يمسك جواله بيدٍ واحدة لا يستطيع القرصَ بإصبعين.
    _phone(tester);
    await _open(tester);

    expect(find.byKey(const ValueKey('zoom-in')), findsOneWidget);
    expect(find.byKey(const ValueKey('zoom-out')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('zoom-in')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('zoom-out')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('والشاشةُ تبقى بلا استثناءٍ مع الحقل الجديد', (tester) async {
    _phone(tester);
    await _open(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}
