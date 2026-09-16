// رأسُ «الملف الشخصي»: غلافٌ طويل، ولا فراغَ تحته، وأيقونتان بلونِ الحقول.
//
// ── ثلاثةُ اختياراتٍ لصاحب المنصّة، ولكلٍّ قياسُه ──────────────────────────
//
//   ١) **الارتفاع.** عُرضت عليه أربعُ لقطاتٍ — ١٠٦ (المشحونُ يومَها) و١٥٠
//      و١٩٠ و٢٣٠ — فوق بطاقة «بياناتي» الحقيقيّة، فأعاد لقطةَ ٢٣٠. وقبلها
//      قال: «خلّيها أطول، نفس اللي عند البطاقة بياناتي».
//
//   ٢) **والفراغ.** «أريدها ما يكون فراغ بين بياناتي والغلاف» — وكان
//      بينهما `Space.xl` أي ٢٤.
//
//   ٣) **واللون.** «خلّي لي رقم الجوال والبريد نفس لون الاسم الكامل
//      والمحافظة». وكانت أيقونتا السطرين `AppColors.muted` بقياس ١٩،
//      وأيقونتا الحقلين تأخذان لونَهما من الثيمة بقياس ٢٠.
//
// ── وما يُقاس هنا ──────────────────────────────────────────────────────────
//
// **المرسومُ لا المكتوب.** شرطٌ يقرأ `_coverHeight` يقارن الثابتَ بنفسه
// فيمرّ أبداً؛ وشرطٌ يكتب `Color(0xFF…)` يوافق اليومَ ويكذب غداً إن تبدّلت
// الثيمة. فيُقاس ما خرج إلى الشجرة: ارتفاعُ الغلاف من `getSize`، والفراغُ
// من المسافة بين قاع القرص ورأس البطاقة، واللونُ **بالمقارنة بأيقونة الحقل
// الحقيقيّة** لا برقمٍ منسوخ.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/edit_profile.dart';
import 'package:aras/src/ui/kit.dart';

const _cover = ValueKey('profile-cover');
const _avatar = ValueKey('profile-avatar');

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
    child: EditProfileScreen(session: s),
  ),
);

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'demo@example.com'
  ..appUserId = 'a1'
  ..loading = false;

/// لونُ أيقونةٍ كما تُرسم فعلاً — من الشجرة لا من الظنّ.
///
/// **وأيقونةُ الحقل لا تحمل لونَها بنفسها**: `InputDecorator` يضعه في
/// `IconTheme` فوقها. فمن سأل `Icon.color` وحدَه وجده `null` وظنّ الشرطَ
/// مُرضى وهو لم يقس شيئاً.
Color? _colorOf(WidgetTester tester, IconData icon) {
  final element = tester.element(find.byIcon(icon).first);
  return (element.widget as Icon).color ?? IconTheme.of(element).color;
}

double _sizeOf(WidgetTester tester, IconData icon) {
  final element = tester.element(find.byIcon(icon).first);
  return (element.widget as Icon).size ?? IconTheme.of(element).size ?? 24;
}

Future<void> _open(WidgetTester tester) async {
  // نافذةٌ تسع الشاشةَ كلَّها: القوائمُ تبني ما يظهر وحده، وسطرُ البريد
  // آخرُها — فلا يوجد في الشجرة أصلاً على ٦٠٠ بكسل.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_wrap(_session()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('**الغلافُ بالارتفاع الذي اختاره — ٢٣٠**', (tester) async {
    await _open(tester);

    expect(find.byKey(_cover), findsOneWidget);
    expect(tester.getSize(find.byKey(_cover)).height, 230.0,
        reason: 'تبدّل ارتفاعُ الغلاف عمّا اختاره صاحبُ المنصّة');
  });

  testWidgets('**والحدُّ يسع القرصَ فلا يُقصّ**', (tester) async {
    // القرصُ ينزل نصفَه تحت الغلاف. فلو قصُر الحدُّ خرج منه القرصُ وقُصّ —
    // وهو عطبٌ لا يظهر إلّا بالعين، فيُقاس.
    await _open(tester);

    final disc = tester.getRect(find.byKey(_avatar));
    final band = tester.getRect(find.byKey(_cover));
    expect(disc.top, greaterThan(band.top),
        reason: 'القرصُ فوق الغلاف لا عليه');
    expect(disc.bottom, greaterThan(band.bottom),
        reason: 'ابتلع الغلافُ القرصَ — لا نزولَ له تحته');
  });

  testWidgets('**ولا فراغَ بين الغلاف وبطاقة «بياناتي»**', (tester) async {
    // **وهو نصُّ طلبه.** وكان بينهما ٢٤، فيُقاس أنّه لم يعُد.
    await _open(tester);

    final disc = tester.getRect(find.byKey(_avatar));
    final card = tester.getRect(find.byType(AppCard).first);
    final gap = card.top - disc.bottom;

    expect(gap, lessThanOrEqualTo(8.0),
        reason: 'عاد الفراغُ بين الغلاف والبطاقة — وقد طلب ألّا يكون');
    expect(gap, greaterThanOrEqualTo(0.0),
        reason: 'البطاقةُ تعلو القرصَ فتقصّه');
  });

  testWidgets('**وأيقونتا الجوال والبريد بلون أيقونتَي الحقلين**',
      (tester) async {
    await _open(tester);

    // **والمرجعُ أيقونةٌ حقيقيّةٌ في الشاشة نفسِها** — لا رقمٌ منسوخٌ في
    // الشرط. فلو تبدّلت الثيمةُ يوماً تبدّلا معاً ولم يكذب القياس.
    final field = _colorOf(tester, Icons.person_outline);
    expect(field, isNotNull, reason: 'لا لونَ لأيقونة الحقل — لا مرجعَ للقياس');

    expect(_colorOf(tester, Icons.phone_outlined), field,
        reason: 'أيقونةُ رقم الجوال بلونٍ غير لون الحقول');
    expect(_colorOf(tester, Icons.mail_outline), field,
        reason: 'أيقونةُ البريد بلونٍ غير لون الحقول');

    // **وليست `muted`** — وبها كان الفرقُ الذي أخرجه. ولولا هذا الشرطُ
    // لَمرّ القياسُ لو صارت الثيمةُ نفسُها `muted` يوماً، فيتساوى الطرفان
    // ويعود الفرقُ الذي شُكي منه غيرَ مرئيٍّ للحزمة.
    expect(field, isNot(AppColors.muted),
        reason: 'لونُ الحقول صار `muted` — فلا يحرس التساوي شيئاً');
  });

  testWidgets('**وبقياسها — ٢٠ لا ١٩**', (tester) async {
    await _open(tester);

    final field = _sizeOf(tester, Icons.person_outline);
    expect(_sizeOf(tester, Icons.phone_outlined), field,
        reason: 'أيقونةُ الجوال بقياسٍ غير قياس الحقول');
    expect(_sizeOf(tester, Icons.mail_outline), field,
        reason: 'أيقونةُ البريد بقياسٍ غير قياس الحقول');
  });
}
