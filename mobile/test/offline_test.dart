// انقطاعُ الشبكة.
//
// **وهذا العطبُ وقع على جهازٍ حقيقيّ، ولقطتُه في يدنا:** فُتح التطبيق بلا
// شبكة، فقيل لصاحبه «إن كنت لم تُطبّق ملفات مجلّد supabase/ على المشروع بعد
// فابدأ بها»، وعُرض له تحتها:
//
//   ClientException with SocketException: Failed host lookup:
//   '….supabase.co' (OS Error: No address associated with hostname, errno = 7)
//
// وهو لا يملك مجلّد `supabase/` ولا يعرف ما هو، وجوالُه على وضع الطيران.
// **والتشخيصُ الكاذب أسوأ من الصمت:** يُرسل صاحبَه إلى مكانٍ لا شيء فيه.
//
// فيُقاس هنا ثلاثة:
//
//   ١. **أنّ الانقطاع يُعرف** — بالنصّ الذي وقع فعلاً لا بنصٍّ مصنوع.
//   ٢. **وأنّ ردَّ الخادم لا يُقرأ انقطاعاً** — وإلّا صار كلُّ عطبٍ في
//      القاعدة «لا يوجد اتصال»، وهو كذبٌ في الجهة الأخرى.
//   ٣. **وأنّ زرَّ الخروج يغيب** — الخروجُ يمحو الجلسة والدخولُ يحتاج شبكة،
//      فمن ضغطه وهو مقطوعٌ حبس نفسَه خارجَ التطبيق.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthApiException, AuthRetryableFetchException, PostgrestException;

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/supabase.dart';
import 'package:aras/src/screens/root.dart' show identityHint;
import 'package:aras/src/ui/kit.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: buildTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, home) =>
          Directionality(textDirection: TextDirection.rtl, child: home!),
      home: child,
    );

/// النصُّ الذي وقع على الجهاز — منقولاً كما هو من اللقطة.
const _fromTheScreenshot =
    "ClientException with SocketException: Failed host lookup: "
    "'oempuuqwpnofuwczhzv.supabase.co' (OS Error: No address associated with "
    "hostname, errno = 7), uri=https://oempuuqwpnofuwczhzv.supabase.co/auth/v1/"
    "token?grant_type=refresh_token";

void main() {
  // ==========================================================================
  //  التمييز
  // ==========================================================================

  group('يُعرف الانقطاع', () {
    test('**من النصّ الذي وقع فعلاً**', () {
      final e = Exception(_fromTheScreenshot);
      expect(isOffline(e), isTrue);
      expect(errorCodeOf(e), offlineCode);
      expect(messageOf(e), offlineMessage);
    });

    // **ولكلّ مَسلكٍ سطرُه، ولا سطرَ يلتقطه غيرُه.**
    //
    // وهذا هو الفرقُ الذي علّمَنيه ضابطٌ سالب: كانت هنا ستّةُ نصوصٍ تحمل
    // بينها أربعَ عشرةَ علامة، فلمّا حُذفت علاماتٌ منها بقيت الاختباراتُ
    // خضراء — لأنّ كلَّ نصٍّ كان يحمل علامتين أو ثلاثاً. فصار لكلّ علامةٍ
    // نصٌّ لا يحمل سواها، فحذفُ أيِّ واحدةٍ يُسقط سطرَها وحده.
    test('**ولكلّ مسلكٍ نصُّه — تسقط علامتُه فيسقط**', () {
      const paths = {
        // الجوال، ولا شبكةَ أصلاً.
        'SocketException':
            'SocketException: Failed host lookup (OS Error: No address '
                'associated with hostname, errno = 7)',
        // `package:http` — في الجوال والمتصفّح جميعاً.
        'ClientException':
            'ClientException: XMLHttpRequest error, uri=https://x.supabase.co',
        // ردٌّ انقطع في منتصفه.
        'HttpException':
            'HttpException: Connection closed before full header was received',
        // TLS.
        'HandshakeException':
            'HandshakeException: Handshake error in client (OS Error: ...)',
        // مهلةٌ انقضت بلا ردّ.
        'TimeoutException':
            'TimeoutException after 0:00:30.000000: Future not completed',
      };
      paths.forEach((mark, text) {
        expect(isOffline(Exception(text)), isTrue, reason: 'فات مسلكُ $mark');
      });
    });

    test('و`gotrue` يلفّه في نوعه فلا يضيع', () {
      // انقطاعُ الشبكة يصل من `gotrue` بهذا النوع بلا رمزِ حالة.
      final e = AuthRetryableFetchException(message: _fromTheScreenshot);
      expect(isOffline(e), isTrue);
      expect(messageOf(e), offlineMessage);
    });
  });

  // ==========================================================================
  //  **والجهةُ الأخرى: ما ليس انقطاعاً**
  // ==========================================================================

  group('ولا يُقرأ ردُّ الخادم انقطاعاً', () {
    test('عطبُ القاعدة يبقى عطبَ قاعدة', () {
      // وإلّا ضاع تشخيصُ «الجدولُ غيرُ موجود» كلُّه خلف «لا يوجد اتصال»،
      // وهو أنفعُ ما يُقال لصاحب المنصّة.
      const e = PostgrestException(
        message: 'relation "public.services" does not exist',
        code: '42P01',
      );
      expect(isOffline(e), isFalse);
      expect(errorCodeOf(e), '42P01');
      expect(messageOf(e), contains('42P01'));
    });

    // ======================================================================
    //  **والسطران التاليان هما اللذان يجعلان حرّاسَ النوع تعني شيئاً.**
    //
    //  فالنصُّ وحده لا يكفي: خادمٌ قد يردّ بجسمٍ فيه نصُّ عطبٍ منقولٌ عن
    //  طبقةٍ أخرى — دالّةٌ طرفيّةٌ تنادي خدمةً فتسقط فتردّ نصَّ سقوطها،
    //  أو ‎PostgREST‎ ينقل رسالةَ إضافةٍ في القاعدة. فتقع في النصّ علامةٌ
    //  من علاماتنا وشبكةُ صاحب الجوال سليمةٌ تماماً.
    //
    //  وقولُ «لا يوجد اتصال» ساعتَها كذبٌ في الجهة الأخرى: يُقعده ينتظر
    //  شبكةً موجودة، والعطبُ عندنا لا عنده.
    // ======================================================================

    test('**وردُّ الخمسمئة ينقل نصَّ عطبٍ فلا يُقرأ انقطاعاً**', () {
      // `gotrue` يرمي `AuthRetryableFetchException` للخمسمئة أيضاً — النوعُ
      // نفسُه الذي يصل به انقطاعُ الشبكة. ويفرّقهما أنّ للردّ رمزَ حالة.
      final e = AuthRetryableFetchException(
        message: '{"error":"ClientException: Failed to fetch, uri=upstream"}',
        statusCode: '500',
      );
      expect(isOffline(e), isFalse, reason: 'خادمٌ ردّ — فالشبكةُ عملت');
      expect(messageOf(e), isNot(offlineMessage));
    });

    test('**وكذلك ردُّ PostgREST إن نقل نصّاً كهذا**', () {
      const e = PostgrestException(
        message: 'function failed: ClientException: Failed to fetch',
        code: 'PGRST202',
      );
      expect(isOffline(e), isFalse);
      expect(errorCodeOf(e), 'PGRST202', reason: 'ضاع رمزُ العطب');
    });

    test('وبياناتُ دخولٍ خاطئةٌ تبقى كما هي', () {
      const e = AuthApiException('Invalid login credentials', statusCode: '400');
      expect(isOffline(e), isFalse);
      expect(messageOf(e), 'بيانات الدخول غير صحيحة.');
    });
  });

  // ==========================================================================
  //  ما يُقال في شاشة الدخول
  // ==========================================================================

  group('نصيحةُ الهوية', () {
    test('**لا تُرسل المقطوعَ إلى مجلّد supabase/**', () {
      final said = identityHint(offlineCode);
      expect(said, offlineMessage);
      expect(said, isNot(contains('supabase/')),
          reason: 'التشخيصُ الكاذب هو العطبُ بعينه');
    });

    test('وتشخيصُ المخطّط يبقى لمن يخصّه', () {
      expect(identityHint('42P01'), contains('supabase/'));
    });
  });

  // ==========================================================================
  //  الوجه
  // ==========================================================================

  group('وجهُ الانقطاع', () {
    testWidgets('**رمزٌ عالميٌّ وسطران وزرُّ إعادة**', (tester) async {
      var retries = 0;
      await tester.pumpWidget(_wrap(Scaffold(
        body: ErrorBlock(
          message: messageOf(Exception(_fromTheScreenshot)),
          onRetry: () => retries++,
          details: _fromTheScreenshot,
        ),
      )));
      await tester.pump();

      expect(find.byKey(const ValueKey('offline-icon')), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byKey(const ValueKey('offline-icon'))).icon,
        Icons.wifi_off_rounded,
        reason: 'رمزُ الواي‑فاي المشطوب يُقرأ بلا لغة',
      );
      expect(find.byKey(const ValueKey('offline-title')), findsOneWidget);

      await tester.tap(find.text('إعادة المحاولة'));
      expect(retries, 1);
    });

    testWidgets('**ولا نصَّ تقنيٍّ في وجهه ولو مُرِّر**', (tester) async {
      // `Failed host lookup` و`errno = 7` لا يعنيان صاحبَ الجوال شيئاً،
      // ولا يعنيان صاحبَ المنصّة شيئاً كذلك: الشبكةُ انقطعت، وانتهى.
      await tester.pumpWidget(_wrap(Scaffold(
        body: ErrorBlock(
          message: messageOf(Exception(_fromTheScreenshot)),
          details: _fromTheScreenshot,
        ),
      )));
      await tester.pump();
      expect(find.byKey(const ValueKey('error-details')), findsNothing);
      expect(find.textContaining('SocketException'), findsNothing);
      expect(find.textContaining('errno'), findsNothing);
    });

    testWidgets('ووجهُ العطب يبقى لمن يخصّه', (tester) async {
      const e = PostgrestException(message: 'no table', code: '42P01');
      await tester.pumpWidget(_wrap(Scaffold(
        body: ErrorBlock(message: messageOf(e), details: e.toString()),
      )));
      await tester.pump();
      expect(find.byKey(const ValueKey('offline-icon')), findsNothing);
      expect(find.byKey(const ValueKey('error-details')), findsOneWidget);
    });
  });
}
