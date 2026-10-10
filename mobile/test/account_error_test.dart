// شاشةُ «تعذّر فتح حسابك» — **ما يراه العميلُ لا ما يراه المطوّر**.
//
// وُلد من لقطةٍ أرسلها صاحبُ المنصّة من جوال عميل: عنوانُها «تعذّرت قراءة
// حسابك»، وفيها «إن كنت لم تُطبّق ملفات مجلّد supabase/…»، وتحت «تفاصيل
// تقنية»:
//
//   [401] {"code":"PGRST303","details":null,"hint":null,"message":"JWT issued at future"}
//
// وسببُه عطبٌ مؤقّتٌ في ساعة الخادم، وللتطبيق علاجٌ صامتٌ له — **لم يعمل**:
// مكتبةُ postgrest رمت العطبَ برمز `401` والجسمُ كلُّه في الرسالة، فقُرئ
// الرمزُ `401` لا `PGRST303`. واختار صاحبُ المنصّة بعد الصورة (ب): وجهٌ
// هادئٌ بلا تفاصيلَ تقنيّةٍ أصلاً.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/supabase.dart';
import 'package:aras/src/screens/root.dart';

/// العطبُ **بالشكل الذي ترميه المكتبةُ فعلاً** — لا نصّاً يشبهه.
///
/// وهذا ما فات الاختبارَ القديم: قاس نصّاً خاماً فيه `"code":"PGRST303"`
/// فنجح، والعطبُ الحقيقيّ يصل نوعاً برمز `401`.
const _real = PostgrestException(
  message:
      '{"code":"PGRST303","details":null,"hint":null,"message":"JWT issued at future"}',
  code: '401',
  details: 'Unauthorized',
);

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

/// جلسةٌ داخلةٌ تعذّرت قراءةُ هويّتها — كما يتركها `refreshIdentity`.
Session _failed(Object error, {Duration? drift}) => Session()
  ..userId = 'u1'
  ..loading = false
  ..identityError = messageOf(error)
  ..identityErrorCode = errorCodeOf(error)
  ..clockDrift = drift;

/// كلُّ نصٍّ على الشاشة — يُسأل عمّا رُسم لا عمّا في الحقول.
String _screenText(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(find.byType(Text)))
    t.data ?? t.textSpan?.toPlainText() ?? '',
].join('\n');

void main() {
  group('**قراءةُ الرمز من العطب الحقيقيّ**', () {
    test('رمزُ الحالة `401` لا يُقرأ رمزاً — والرمزُ من الجسم', () {
      // ولولا هذا لَما حاول العلاجُ الصامتُ شيئاً.
      expect(errorCodeOf(_real), jwtIssuedAtFuture);
    });

    test('ورمزُ الخادم الصريحُ يُقرأ كما هو', () {
      const e = PostgrestException(message: 'denied', code: '42501');
      expect(errorCodeOf(e), '42501');
    });

    test('ورقمُ حالةٍ بلا جسمٍ يبقى رقمَه لا يضيع', () {
      const e = PostgrestException(message: 'Bad Gateway', code: '502');
      expect(errorCodeOf(e), '502');
    });

    test('والرسالةُ جملةٌ لا JSON', () {
      final text = messageOf(_real);
      expect(text, '[PGRST303] JWT issued at future');
      expect(text, isNot(contains('{')));
    });
  });

  test('**والمحاولاتُ الصامتةُ تتباعد ثوانيَ**', () {
    // ما يُبلَّغ عنه عند Supabase لا يزول في أقلّ من ثانية.
    expect(clockSkewRetryDelays.length, greaterThanOrEqualTo(3));
    expect(clockSkewRetryDelays.every((d) => d >= const Duration(seconds: 1)), isTrue);
    final total = clockSkewRetryDelays.fold(Duration.zero, (a, b) => a + b);
    expect(total, greaterThanOrEqualTo(const Duration(seconds: 8)));
  });

  group('الشاشة', () {
    testWidgets('**عطبُ ساعة الخادم: وجهٌ هادئٌ بلا شيءٍ تقنيّ** (ب)', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(RootScreen(session: _failed(_real))));
      await tester.pump();

      expect(find.byKey(const ValueKey('quiet-error-title')), findsOneWidget);
      expect(find.text('تعذّر فتح حسابك الآن'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      expect(find.text('خروج'), findsOneWidget);

      final shown = _screenText(tester);
      for (final leak in ['supabase', 'PGRST', '401', '{', 'JWT', 'تفاصيل تقنية']) {
        expect(shown, isNot(contains(leak)), reason: 'ظهر للعميل: $leak');
      }
    });

    testWidgets('**وساعةُ جواله هو: يُقال له بالرقم وما يفعل**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(RootScreen(
          session: _failed(_real, drift: const Duration(minutes: 7)))));
      await tester.pump();

      expect(find.text('ساعة جوالك غير مضبوطة'), findsOneWidget);
      final shown = _screenText(tester);
      expect(shown, contains('7 دقائق'));
      expect(shown, contains('الوقت التلقائي'));
      // والنجمتان علامةُ تنسيقٍ في الجدول لا تُرسم حرفاً.
      expect(shown, isNot(contains('**')));
    });

    testWidgets('وفرقٌ صغيرٌ لا يُتّهم به الجوال', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(RootScreen(
          session: _failed(_real, drift: const Duration(seconds: 5)))));
      await tester.pump();

      expect(find.text('تعذّر فتح حسابك الآن'), findsOneWidget);
      expect(find.text('ساعة جوالك غير مضبوطة'), findsNothing);
    });
  });

  test('**ولا رمزَ يُرسل العميلَ إلى ملفّات المطوّر**', () {
    for (final code in [null, '401', '42P01', 'PGRST205', '42703', '42501', 'PGRST301', jwtIssuedAtFuture]) {
      final hint = identityHint(code);
      expect(hint, isNot(contains('supabase')), reason: '$code');
      expect(hint, isNot(contains('.sql')), reason: '$code');
    }
  });
}
