// ما يُعرض على صاحب الجهاز حين يفشل شيء.
//
// **وُلد هذا الملفّ من لقطةِ شاشةٍ من جهازٍ حقيقيّ**: ظهر فيها للمستخدم
// جسمُ ردٍّ خامّ —
//
//   {"message":"JWT issued at future","code":"PGRST303",…} [401]
//
// — وتحته «الغالب أنّ ملفات المخطّط لم تُطبَّق». وكلاهما خطأ:
//
//   ١. الأقواسُ وعلاماتُ الاقتباس لا تعني العميلَ في شيء.
//   ٢. والتشخيصُ **كاذب**: السببُ فرقُ ساعةٍ لا ملفّاتٌ ناقصة. فأُرسل
//      صاحبُه إلى مجلّدٍ سليمٍ يبحث فيه.
//   ٣. **والإصلاحُ الذاتيّ لم يعمل أصلاً** — وهو مشروطٌ بالرمز، والرمزُ
//      كان يُقرأ `null` لأنّ العطب لم يصل نوعاً معروفاً.
//
// وكلُّ ذلك من سببٍ واحد: `errorCodeOf` كانت تسأل عن النوع ولا تقرأ الردّ.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/data/supabase.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/ui/kit.dart';

/// الردُّ كما وصل في اللقطة، حرفاً بحرف.
const _raw =
    '{"message":"JWT issued at future","code":"PGRST303","details":null,'
    '"hint":null} [401]';

Widget _wrap(Widget child) => MaterialApp(
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
    child: Scaffold(body: child),
  ),
);

void main() {
  // ==========================================================================
  //  **قراءةُ الرمز — وهي أصلُ العطب كلِّه**
  // ==========================================================================

  group('errorCodeOf', () {
    test('**تقرأ الرمزَ من ردٍّ خامّ لا نوعَ له**', () {
      // وهذه هي الحالةُ التي وقعت. ولولا قراءتُها لَبقي الرمزُ `null`،
      // ولَبقي الإصلاحُ الذاتيّ معطَّلاً والتشخيصُ كاذباً.
      expect(errorCodeOf(_raw), 'PGRST303');
    });

    test('وتقرأه من الرسالة حين لا رمزَ في الردّ', () {
      expect(errorCodeOf('PostgrestException: JWT issued at future'),
          jwtIssuedAtFuture);
    });

    test('ورمزٌ آخر يُقرأ كما هو لا يُخلط بهذا', () {
      expect(errorCodeOf('{"code":"42P01","message":"no table"}'), '42P01');
    });

    test('وعطبٌ لا رمزَ فيه يبقى بلا رمز', () {
      expect(errorCodeOf('تعذّر الاتصال بالشبكة'), isNull);
    });
  });

  // ==========================================================================
  //  **الرسالة — ولا JSON في وجه أحد**
  // ==========================================================================

  group('messageOf', () {
    test('**تستخرج الجملةَ من الردّ الخامّ**', () {
      final text = messageOf(_raw);
      expect(text, 'JWT issued at future');
      expect(text, isNot(contains('{')), reason: 'بقيت أقواسُ JSON');
      expect(text, isNot(contains('"code"')));
    });

    test('ونصٌّ عاديٌّ يمرّ كما هو', () {
      expect(messageOf('تعذّر الاتصال بالشبكة'), 'تعذّر الاتصال بالشبكة');
    });

    test('وفارغٌ يصير جملةً مفهومة', () {
      expect(messageOf(''), 'تعذّر تنفيذ الطلب.');
    });
  });

  // ==========================================================================
  //  **الشاشة: الإنسانُ أوّلاً والتقنيُّ مطويّ**
  // ==========================================================================

  testWidgets('**النصُّ التقنيُّ مطويٌّ لا معروض**', (tester) async {
    await tester.pumpWidget(_wrap(ErrorBlock(
      message: 'السبب فرقٌ في الساعة بين جهازك والخادم.',
      details: _raw,
      onRetry: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('فرقٌ في الساعة'), findsOneWidget);
    // والأقواسُ ليست على الشاشة حتى تُفتح الطيّة.
    expect(find.textContaining('PGRST303'), findsNothing);
    expect(find.text('تفاصيل تقنية'), findsOneWidget);
  });

  testWidgets('**وتُفتح الطيّةُ فيظهر لمن يريده**', (tester) async {
    // ويبقى ولا يُحذف: صاحبُ المنصّة يحتاجه حين يسأله عميلٌ «ماذا ظهر لك؟».
    await tester.pumpWidget(_wrap(ErrorBlock(
      message: 'السبب فرقٌ في الساعة.',
      details: _raw,
      onRetry: () {},
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('تفاصيل تقنية'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PGRST303'), findsOneWidget);
  });

  testWidgets('وبلا تفاصيلَ لا تظهر طيّةٌ فارغة', (tester) async {
    await tester.pumpWidget(_wrap(const ErrorBlock(message: 'تعذّر شيء.')));
    await tester.pumpAndSettle();

    expect(find.text('تفاصيل تقنية'), findsNothing);
  });

  testWidgets('وزرُّ إعادة المحاولة يعمل', (tester) async {
    var tries = 0;
    await tester.pumpWidget(_wrap(ErrorBlock(
      message: 'تعذّر شيء.',
      onRetry: () => tries++,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('إعادة المحاولة'));
    expect(tries, 1);
  });
}
