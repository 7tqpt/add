// غلافُ صفحة الخدمة يمشي مع المحتوى ويخرج بالتمرير.
//
// ── ما شكا منه ─────────────────────────────────────────────────────────────
//
// «ليش صورة ثابتة؟ أريدها ما تكون ثابتة». وكانت الشاشةُ عموداً: الغلافُ
// بارتفاعٍ ثابتٍ ثمّ `Expanded` فيه القائمة — أي أنّ الغلافَ **خارجَ
// الممرَّر**، فيمشي المحتوى تحته وهو لا يتزحزح مهما مُرِّر.
//
// واختار (أ) من ثلاث: أن يدخل القائمةَ نفسَها فيخرج بالتمرير.
//
// ── ولا يُسأل التخطيطُ عن شكله، يُمرَّر ويُقاس أين صار ─────────────────────
//
// «أداخلَ القائمة هو؟» سؤالٌ عن الشجرة يُجاب بنعم وإن كان فوقها ما يثبّته.
// **فتُمرَّر القائمةُ تمريراً حقيقيّاً ويُقاس ارتفاعُ الغلاف قبلُ وبعد.**
//
// ── وأخطرُ ما يُحفظ هنا: موضعُ الطيران ─────────────────────────────────────
//
// الغلافُ يطير من البطاقة إلى هذه الشاشة، **ووقتُ التحميل هو وقتُ الانتقال
// بعينه**. فلو دخل الغلافُ في `FutureBuilder` وهو ينتقل إلى ممرٍّ لَغاب عن
// أوّل إطارٍ ولَطار من البطاقة إلى فراغٍ وارتدّ. وهذا الشرطُ كان يحفظه
// العمودُ بترتيبه، ويجب أن يبقى محفوظاً بعد أن ذهب العمود.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/service_detail.dart';
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
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

final _cover = find.byKey(const ValueKey('service-cover-tap'));

Future<void> _open(WidgetTester tester) async {
  _phone(tester);
  await tester.pumpWidget(_wrap(const ServiceDetailScreen(
    serviceId: 's1',
    coverPath: 'services/s1/cover.jpg',
  )));
  await _settle(tester);
}

void main() {
  // **ولا `mediaUrlOverride` هنا.** ما يُقاس مواضعُ لا صور، ورابطٌ مركَّبٌ
  // يجعل `Image.network` يطلب ويُردّ بأربعمئة فيبقى في الشجرة ما لا يسكن —
  // و`pumpAndSettle` لا تعود. والغلافُ بلا رابطٍ سطحٌ باهتٌ بالارتفاع نفسِه،
  // وهو ما يُقاس.

  testWidgets('**الغلافُ يمشي مع المحتوى**', (tester) async {
    await _open(tester);

    final before = tester.getTopLeft(_cover).dy;
    await tester.drag(find.byType(ListView).first, const Offset(0, -140));
    await _settle(tester);

    // ولا يكفي أن يتزحزح: يجب أن يمشي بقدر ما مُرِّر لا بأقلَّ منه.
    final moved = before - tester.getTopLeft(_cover).dy;
    expect(moved, closeTo(140, 12),
        reason: 'الغلافُ لا يمشي مع المحتوى — مشى $moved من ١٤٠ نقطة');
  });

  testWidgets('**ثمّ يخرج من الشاشة**', (tester) async {
    // وهذا تمامُ اختياره: «ومن أراد رؤيتَه رجع إلى أعلى». ولو بقي متعلّقاً
    // في أعلاها لَكان الخيارَ (ب) لا (أ).
    await _open(tester);

    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await _settle(tester);
    expect(_cover, findsNothing, reason: 'الغلافُ باقٍ في الشاشة بعد التمرير');

    // **ويعود بالرجوع** — ولولا هذا لَجاز أن يكون قد ذهب ولا يعود.
    await tester.drag(find.byType(ListView).first, const Offset(0, 900));
    await _settle(tester);
    expect(_cover, findsOneWidget, reason: 'الغلافُ لا يعود بالرجوع إلى أعلى');
  });

  testWidgets('**ويخلي الشاشةَ للتفاصيل**', (tester) async {
    // الوجهُ الآخر لاختياره: ما كان تحت الغلاف يصعد مكانَه.
    await _open(tester);

    final priceBefore = tester.getTopLeft(find.text('السعر').first).dy;
    await tester.drag(find.byType(ListView).first, const Offset(0, -260));
    await _settle(tester);

    expect(tester.getTopLeft(find.text('السعر').first).dy,
        lessThan(priceBefore - 200),
        reason: 'المحتوى لم يصعد مكانَ الغلاف');
  });

  testWidgets('**وهو أوّلُ ما في الشاشة قبل التمرير**', (tester) async {
    // لو وقع تحت شيءٍ لَما رآه من فتح الخدمة، وهو أوّلُ ما جاء يراه.
    await _open(tester);

    final cover = tester.getTopLeft(_cover).dy;
    expect(tester.getTopLeft(find.text('السعر').first).dy, greaterThan(cover),
        reason: 'السعرُ فوق الغلاف');
    expect(cover, lessThan(200), reason: 'الغلافُ بعيدٌ عن أعلى الشاشة');
  });

  testWidgets('**وموضعُ الطيران باقٍ في أوّل إطار**', (tester) async {
    // **ووقتُ التحميل هو وقتُ الانتقال بعينه**: لو غاب الغلافُ عن أوّل إطارٍ
    // لَطار من البطاقة إلى فراغٍ وارتدّ. وهو شرطٌ كان يحفظه العمودُ بترتيبه.
    _phone(tester);
    await tester.pumpWidget(_wrap(const ServiceDetailScreen(
      serviceId: 's1',
      coverPath: 'services/s1/cover.jpg',
    )));
    await tester.pump();

    expect(find.byType(LoadingBlock), findsOneWidget,
        reason: 'وصلت الخدمةُ فوراً — فالاختبارُ لا يقيس ما يدّعي');
    expect(
      find.byWidgetPredicate((w) => w is Hero && w.tag == serviceHeroTag('s1')),
      findsOneWidget,
      reason: 'لا موضعَ يطير إليه الغلاف',
    );
    await _settle(tester);
  });

  testWidgets('**ولا ممرَّرَ داخلَ ممرّ**', (tester) async {
    // قائمتان متداخلتان: الداخلةُ بلا ارتفاعٍ فترمي، أو تُلفّ بارتفاعٍ
    // ثابتٍ فيصير في الشاشة ممرّان يتنازعان الإصبع.
    await _open(tester);

    expect(
      find.descendant(
        of: find.byType(ServiceDetailScreen),
        matching: find.byType(ListView),
      ),
      findsOneWidget,
      reason: 'في الشاشة أكثرُ من قائمة',
    );
  });
}
