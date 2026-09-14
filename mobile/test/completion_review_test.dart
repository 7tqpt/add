// رحلةُ «تأكيد التنفيذ»: زرٌّ أخضرُ، وسؤالٌ، ثمّ انتظارُ الإدارة.
//
// ── ما يحرسه هذا الملفّ ──────────────────────────────────────────────────────
//
// «عند ضغط على تأكيد التنفيذ لون أخضر وتظهر له هل أنت متأكد نعم أو لا،
//  وترسل للإدارة لمراجعات تنفيذ الحجز… قبل تنفيذ يطلع له مراجعات الإدارة».
//
// **١) أنّ الضغطةَ لا تُتمّ الحجز.** وهذا لبُّ الطلب: بعد «نعم» يبقى الحجزُ
//    مؤكَّداً وتظهر «قيد مراجعة الإدارة» — لا «تم تنفيذ الحجز». والحارسُ
//    الحقيقيُّ في القاعدة (`api_complete_booking` صارت للإدارة وحدَها)،
//    ومقيسٌ في `supabase/tests/completion_review.test.mjs`.
// **٢) وأنّ «لا» لا تُرسل شيئاً.** سؤالٌ يُطرح ويُرى وجوابُه لا يُقرأ أسوأُ
//    من لا سؤال: من قال «لا» ظنّ أنّه منع وقد أُرسل طلبُه.
// **٣) وأنّ السؤالَ يقول ما سيقع** — لا «هل أنت متأكّد؟» وحدَها. من لا
//    يعرف أنّ مالَه ينتظر مراجعةً يظنّ التطبيقَ معطوباً حين لا يصله شيء.
// **٤) وأنّ سببَ الردّ يُعرض** — وبلا سببٍ يُعاد الطلبُ كما هو فيدور
//    الطابورُ على نفسه.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/requests.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: buildTheme(),
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  // **و`Scaffold` لأنّ الشاشةَ تُظهر رسالة.** في التطبيق تعيش داخل
  // `ProviderShell` وفيه واحد، فبلا هذا يسقط `showMessage` بتأكيدٍ
  // لا علاقةَ له بما يُقاس.
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(body: child),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Session _provider() => Session()
  ..userId = 'u1'
  ..email = 'hall@sdd.company'
  ..appUserId = 'a1'
  ..providerId = 'demo-provider'
  ..loading = false;

Booking _confirmed({
  String requestedAt = '',
  String rejectReason = '',
}) => Booking(
  id: 'r1',
  reference: 'BK-1',
  userName: 'هدى المقطري',
  providerName: 'قاعة التاج',
  serviceTitle: 'خيمة الأفراح',
  eventDate: DateTime.now()
      .subtract(const Duration(days: 2))
      .toIso8601String()
      .substring(0, 10),
  eventTime: '20:00',
  address: 'شارع الستين — صنعاء',
  guestsCount: 350,
  status: BookingStatus.confirmed,
  totalPrice: 480000,
  depositAmount: 144000,
  paidAmount: 480000,
  completionRequestedAt: requestedAt,
  completionRejectReason: rejectReason,
);

final _button = find.byKey(const ValueKey('request-completion-r1'));
final _reviewBar = find.byKey(const ValueKey('booking-under-review'));
final _rejectNote = find.byKey(const ValueKey('completion-rejected'));
final _doneBar = find.byKey(const ValueKey('booking-done'));

/// أطُلب الاعتمادُ فعلاً؟ — يُسأل ما وصل وضعَ العرض لا ما تعرضه الشاشة.
bool get _requested =>
    demoProviderRequests.any((b) => b.awaitingCompletionReview);

Future<void> _open(WidgetTester tester) async {
  _phone(tester);
  await tester.pumpWidget(_wrap(RequestsScreen(session: _provider())));
  await _settle(tester);
}

void main() {
  group('**الزرُّ الأخضرُ والسؤال**', () {
    setUp(() {
      demoProviderRequests = [_confirmed()];
    });

    testWidgets('الزرُّ أخضرُ لا نبيذيّ', (tester) async {
      await _open(tester);

      // **ويُسأل النمطُ المحلولُ لا الشيفرةُ المكتوبة.**
      final style = tester.widget<FilledButton>(_button).style;
      expect(style?.backgroundColor?.resolve({}), AppColors.good,
          reason: 'ختمُ عملٍ تمّ لا خطرٌ يُحذَّر منه');
      expect(find.text('تأكيد التنفيذ'), findsOneWidget);
    });

    testWidgets('**ولا يُرسَل شيءٌ بضغطةٍ واحدة: يسأل أوّلاً**', (tester) async {
      await _open(tester);
      await tester.tap(_button);
      await _settle(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('نعم، نُفِّذ'), findsOneWidget);
      expect(find.text('لا'), findsOneWidget);
      expect(_requested, isFalse, reason: 'أُرسل الطلبُ والسؤالُ مفتوح');
    });

    testWidgets('**والسؤالُ يقول ما سيقع** — لا «متأكّد؟» وحدَها',
        (tester) async {
      await _open(tester);
      await tester.tap(_button);
      await _settle(tester);

      expect(find.textContaining('الإدارة'), findsOneWidget);
      expect(find.textContaining('مستحقّاتك'), findsOneWidget);
    });

    testWidgets('**و«لا» لا تُرسل شيئاً**', (tester) async {
      await _open(tester);
      await tester.tap(_button);
      await _settle(tester);
      await tester.tap(find.text('لا'));
      await _settle(tester);

      expect(_requested, isFalse, reason: 'أُرسل الطلبُ ومن سُئل قال لا');
      expect(_button, findsOneWidget);
    });

    testWidgets('**و«نعم» تُرسل ولا تُتمّ**', (tester) async {
      await _open(tester);
      await tester.tap(_button);
      await _settle(tester);
      await tester.tap(find.text('نعم، نُفِّذ'));
      await _settle(tester);

      expect(_requested, isTrue, reason: 'لم يُرسَل الطلبُ بعد «نعم»');

      // **وهذا لبُّ الطلب:** الحجزُ لم يُنفَّذ — الإدارةُ تعتمده.
      expect(demoProviderRequests.single.status, BookingStatus.confirmed,
          reason: 'أتمّ المزوّدُ حجزَه بنفسه');
      expect(_doneBar, findsNothing, reason: 'ظهر «تم تنفيذ الحجز» بلا اعتماد');
      expect(_reviewBar, findsOneWidget);
      expect(find.text('قيد مراجعة الإدارة'), findsOneWidget);
    });
  });

  group('**وما بين الضغط والموافقة**', () {
    testWidgets('يُعرض الانتظارُ ويختفي الزرّ', (tester) async {
      demoProviderRequests = [_confirmed(requestedAt: '2026-09-01T10:00:00Z')];
      await _open(tester);

      expect(_reviewBar, findsOneWidget);
      expect(_button, findsNothing, reason: 'يُضغط الزرُّ مرّتين فيُنتظر مرّتين');
    });

    testWidgets('**وكهرمانيٌّ لا أخضر** — الأخضرُ يقول «تمّ»', (tester) async {
      // ولو تشابها لَظنّ المزوّدُ أنّ مالَه احتُسب فلا يسأل حين يتأخّر.
      // كشف غيابَ هذا القياسِ ضابطٌ سالب: بُدّل اللونُ بالأخضر فبقيت
      // الحزمةُ خضراء.
      demoProviderRequests = [_confirmed(requestedAt: '2026-09-01T10:00:00Z')];
      await _open(tester);

      final box = tester.widget<Container>(_reviewBar);
      final colour = (box.decoration! as BoxDecoration).color!;
      expect(colour.r, closeTo(AppColors.warning.r, 0.001));
      expect(colour.g, closeTo(AppColors.warning.g, 0.001));
      expect(colour.b, closeTo(AppColors.warning.b, 0.001));
      expect(colour.a, closeTo(Tint.chip, 0.001));
    });

    testWidgets('**وبابُ المراسلة يبقى** — العملُ لم يُختم بعد',
        (tester) async {
      demoProviderRequests = [_confirmed(requestedAt: '2026-09-01T10:00:00Z')];
      await _open(tester);

      expect(find.text('راسل هدى المقطري'), findsOneWidget);
    });
  });

  group('**وردُّ الإدارة**', () {
    setUp(() {
      demoProviderRequests = [_confirmed(rejectReason: 'العربون لم يصل بعد')];
    });

    testWidgets('**السببُ يُعرض** — وبلا سببٍ يُعاد الطلبُ كما هو',
        (tester) async {
      await _open(tester);

      expect(_rejectNote, findsOneWidget);
      expect(find.text('العربون لم يصل بعد'), findsOneWidget);
    });

    testWidgets('والزرُّ يعود ليُطلب من جديد', (tester) async {
      await _open(tester);

      expect(_button, findsOneWidget);
      expect(_reviewBar, findsNothing);
    });

    testWidgets('**والسببُ فوق الزرّ لا تحته** — ليُقرأ قبل أن يُعاد',
        (tester) async {
      await _open(tester);

      final note = tester.getCenter(_rejectNote);
      final button = tester.getCenter(_button);
      expect(note.dy, lessThan(button.dy));
    });
  });
}
