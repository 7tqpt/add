// قاعُ بطاقة الطلب: خبرٌ للمنفَّذ، وبابٌ لما دونه.
//
// ── ما يحرسه هذا الملفّ ──────────────────────────────────────────────────────
//
// «بعد تأكيد تنفيذ شيل أيقون راسل هدى، خلّه أيقون لون أخضر و«تم تنفيذ
// الحجز»» — واختار **(ب) شريطٌ أخضرُ مصبوغ** من ثلاثةٍ عُرضت عليه.
//
// **١) أنّ المنفَّذَ يُختم** — شريطٌ أخضرُ بكلمته.
// **٢) وأنّ زرَّ المراسلة ذهب من المنفَّذ وحدَه.** وهو نصفُ الطلب الذي
//    لا يقيسه وجودُ الشريط: شريطٌ يُضاف والزرُّ تحته باقٍ يُرضي عيناً
//    تنظر إلى أعلى البطاقة ولا يُرضي الطلب.
// **٣) وأنّ ما دون المنفَّذ ما زال له بابُه** — وهذا أخطرُ ما هنا: شرطٌ
//    يُكتب بالمقلوب يقطع المراسلةَ عن كلّ حجزٍ في التطبيق، والشريطُ
//    الأخضرُ يظهر فوق حجزٍ لم يُنفَّذ بعد.
// **٤) وأنّ الكلمةَ مع الأيقونة لا الأيقونةُ وحدَها** — من لا يفرّق
//    الأخضرَ من الأحمر يقرأ «تم تنفيذ الحجز».
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/money.dart';
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
  home: Directionality(textDirection: TextDirection.rtl, child: child),
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

Booking _booking(BookingStatus status, {String user = 'هدى المقطري'}) => Booking(
  id: 'r1',
  reference: 'BK-1',
  userName: user,
  providerName: 'قاعة التاج',
  serviceTitle: 'خيمة الأفراح',
  eventDate: DateTime.now()
      .subtract(const Duration(days: 12))
      .toIso8601String()
      .substring(0, 10),
  eventTime: '20:00',
  address: 'شارع الستين — صنعاء',
  guestsCount: 350,
  status: status,
  totalPrice: 480000,
  depositAmount: 144000,
  paidAmount: 480000,
);

final _done = find.byKey(const ValueKey('booking-done'));
final _message = find.text('راسل هدى المقطري');

/// أرضيّةُ الشريط كما رُسمت.
///
/// **و`Material` لا `Container`:** صار الشريطُ يُضغط، فأرضيّتُه انتقلت إلى
/// `Material` تحت `InkWell` — ولولا ذلك لَما ظهرت موجةُ اللمس أصلاً.
Color _barColour(WidgetTester tester) => tester
    .widget<Material>(find.ancestor(of: _done, matching: find.byType(Material)).first)
    .color!;

void main() {
  group('**الحجزُ المنفَّذُ يُختم**', () {
    setUp(() {
      demoProviderRequests = [_booking(BookingStatus.completed)];
    });

    testWidgets('شريطٌ أخضرُ بكلمته', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(RequestsScreen(session: _provider())));
      await _settle(tester);

      expect(_done, findsOneWidget);
      expect(find.text('تم تنفيذ الحجز'), findsOneWidget,
          reason: 'الأيقونةُ وحدَها لا يقرؤها من لا يفرّق الألوان');

      // **وأخضرُ التطبيق المقيس لا أيُّ أخضر.**
      final bar = _barColour(tester);
      expect(bar.r, closeTo(AppColors.good.r, 0.001));
      expect(bar.g, closeTo(AppColors.good.g, 0.001));
      expect(bar.b, closeTo(AppColors.good.b, 0.001));
      expect(bar.a, closeTo(Tint.chip, 0.001),
          reason: 'الصبغةُ خضرةٌ صمّاءُ لا صبغةٌ خفيفة');
    });

    testWidgets('**وزرُّ المراسلة ذهب** — وهو نصفُ الطلب', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(RequestsScreen(session: _provider())));
      await _settle(tester);

      expect(_message, findsNothing,
          reason: 'بقي زرُّ المراسلة تحت الشريط في الحجز المنفَّذ');
    });

    testWidgets('**والشريطُ بابٌ إلى «مستحقّاتي»**', (tester) async {
      // «خلّه قابل للضغط وعند ضغط يروح للمستحقات» — ويُقاس بما فُتح لا
      // بوجود `InkWell`: غلافٌ يُضغط ولا يذهب إلى شيءٍ يمرّ على الأوّل.
      _phone(tester);
      await tester.pumpWidget(_wrap(RequestsScreen(session: _provider())));
      await _settle(tester);

      await tester.tap(_done);
      await _settle(tester);
      expect(find.byType(EarningsScreen), findsOneWidget,
          reason: 'ضُغط الشريطُ ولم يُفتح شيء');
    });

    testWidgets('**وبعنوانٍ وسهمِ رجوعٍ كالبابِ الآخر**', (tester) async {
      // `EarningsScreen` لا تبني `Scaffold` لنفسها: تُلفّ في «ملفّي» بواحدٍ
      // عنوانُه «مستحقّاتي». فدفعُها عاريةً يُنزل المزوّدَ في شاشةٍ بلا
      // اسمٍ ولا مخرج — وهو ما وقع فعلاً، ورآه صاحبُ المنصّة قبلي.
      _phone(tester);
      await tester.pumpWidget(_wrap(RequestsScreen(session: _provider())));
      await _settle(tester);

      await tester.tap(_done);
      await _settle(tester);

      expect(find.widgetWithText(AppBar, 'مستحقّاتي'), findsOneWidget,
          reason: 'شاشةٌ بلا اسم');
      expect(find.byType(BackButton), findsOneWidget,
          reason: 'لا مخرجَ إلّا زرُّ الجهاز');
    });

    testWidgets('**والسهمُ يقول إنّه باب**', (tester) async {
      // شريطٌ يُضغط بلا علامةٍ تدلّ عليه لا يعرفه أحد، فيبقى الطريقُ إلى
      // المستحقّات مقفولاً وهو مفتوح.
      _phone(tester);
      await tester.pumpWidget(_wrap(RequestsScreen(session: _provider())));
      await _settle(tester);

      expect(find.descendant(of: _done, matching: find.text('مستحقّاتي')),
          findsOneWidget);
      expect(
        find.descendant(
          of: _done,
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
      );
    });
  });

  group('**وما دون المنفَّذ يبقى له بابُه**', () {
    for (final status in [
      BookingStatus.pendingProvider,
      BookingStatus.confirmed,
      BookingStatus.cancelled,
    ]) {
      testWidgets('$status: الزرُّ باقٍ ولا شريط', (tester) async {
        demoProviderRequests = [_booking(status)];
        _phone(tester);
        await tester.pumpWidget(_wrap(RequestsScreen(session: _provider())));
        await _settle(tester);

        expect(_message, findsOneWidget,
            reason: 'قُطعت المراسلةُ عن حجزٍ لم يُنفَّذ');
        expect(_done, findsNothing,
            reason: 'خُتم حجزٌ لم يُنفَّذ بعد');
      });
    }
  });
}
