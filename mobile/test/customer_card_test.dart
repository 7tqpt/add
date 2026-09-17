// بطاقةُ العميل — وحدُّ ما تعرضه.
//
// ── ما يُقاس هنا ──────────────────────────────────────────────────────────
//
// **ولا يكفي أن تُعرض البطاقة.** ضيقُها هو مقصودُها: سياسةُ `app_users`
// تمنع مقدّمَ الخدمة من قراءة صفّ العميل، فبُنيت على دالّةٍ تُخرج **الصورةَ
// والمحافظةَ وحدَهما**. فلو صارت الشاشةُ يوماً تعرض بريداً أو جوّالاً لَسقط
// العهدُ ولم يسقط شيءٌ في الحزمة — فيُقاس.
//
//   ١) **تُعرض بيانةُ الخادم كما هي** — لا أرقامٌ من عند الشاشة.
//   ٢) **ولا بريدَ ولا جوّالَ فيها بحال.**
//   ٣) **ومن راسل ولم يحجز يُقال له ذلك** لا تُعرض عليه أصفارٌ تُقرأ عطباً.
//   ٤) **وخطأُ الخادم يُقال ويُعاد** — ومن استدعى محادثةً ليست له يُردّ،
//      فيجب أن يرى السببَ لا شاشةً فارغة.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/customer_card.dart';
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
  home: Directionality(textDirection: TextDirection.rtl, child: child),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _open(WidgetTester tester) async {
  _phone(tester);
  await tester.pumpWidget(
    _wrap(const CustomerCardScreen(conversationId: 'c1', name: 'عميل')),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // بيانةُ العرض معلومةٌ، فيُقارَن المعروضُ بها لا بنفسه.
    demoCustomerCardOverride = null;
  });
  tearDown(() => demoCustomerCardOverride = null);

  testWidgets('**تُعرض بيانةُ الخادم كما هي**', (tester) async {
    demoCustomerCardOverride = const CustomerCard(
      fullName: 'أحمد الشرعبي',
      avatarPath: '',
      governorate: 'صنعاء',
      bookingsCount: 7,
      completedCount: 5,
      cancelledCount: 1,
      upcomingCount: 1,
      firstBookingAt: '2025-03-04T10:00:00Z',
      totalPaid: 1250000,
    );
    await _open(tester);

    expect(find.text('أحمد الشرعبي'), findsOneWidget);
    expect(find.text('صنعاء'), findsOneWidget);
    expect(find.text('حجوزاته معك'), findsOneWidget);
    // **والأرقامُ من البيانة لا من الشاشة** — لو حُسبت هنا لَاختلفت.
    //
    // **وبأرقامٍ غربيّةٍ كبقيّة التطبيق.** رسمتُ في المقترح «٥» و«١» بيدي
    // فخرجت هنديّةً بجانب «7 حجوزات» و«1,250,000» الغربيّتين — وهو خلطٌ لا
    // يقع في المشحون: `formatCount` و`formatMoney` يخرجان غربيّةً، فتتبعهما
    // الأعدادُ المجرّدة.
    expect(find.text('5'), findsOneWidget, reason: 'المكتملةُ ليست خمساً');
    expect(find.textContaining('1,250,000'), findsOneWidget);
  });

  testWidgets('**ولا بريدَ ولا جوّالَ فيها بحال**', (tester) async {
    // **وهذا عهدُ الدالّة الضيّقة، ويُقاس في الشاشة أيضاً.** الدالّةُ لا
    // تُرجعهما، والشاشةُ لا تعرضهما — فلو أُضيفا يوماً في أيّ الطرفين سقط.
    demoCustomerCardOverride = const CustomerCard(
      fullName: 'أحمد الشرعبي',
      avatarPath: '',
      governorate: 'صنعاء',
      bookingsCount: 1,
      completedCount: 1,
      cancelledCount: 0,
      upcomingCount: 0,
      firstBookingAt: '2025-03-04T10:00:00Z',
      totalPaid: 100000,
    );
    await _open(tester);

    expect(find.textContaining('@'), findsNothing);
    expect(find.textContaining('77'), findsNothing);
    expect(find.textContaining('+967'), findsNothing);
  });

  testWidgets('**ومن راسل ولم يحجز يُقال له ذلك**', (tester) async {
    // **ولا تُعرض عليه أصفارٌ تُقرأ عطباً.** «الحجوزات ٠ · المكتملة ٠ ·
    // إجمالي ما دفعه ٠» تبدو شاشةً مكسورة، وهي حالٌ سليمة.
    demoCustomerCardOverride = const CustomerCard(
      fullName: 'أحمد الشرعبي',
      avatarPath: '',
      governorate: '',
      bookingsCount: 0,
      completedCount: 0,
      cancelledCount: 0,
      upcomingCount: 0,
      firstBookingAt: '',
      totalPaid: 0,
    );
    await _open(tester);

    expect(find.text('راسلك ولم يحجز بعد.'), findsOneWidget);
    expect(find.text('المكتملة'), findsNothing,
        reason: 'عُرضت أصفارٌ على من لم يحجز');
    // **ولا سطرَ محافظةٍ فارغ**: أيقونةٌ بجانبها فراغٌ تُقرأ عطباً.
    expect(find.byIcon(Icons.location_on_outlined), findsNothing);
  });

  testWidgets('**وخطأُ الخادم يُقال ويُعاد**', (tester) async {
    // من استدعى محادثةً ليست له تردُّه القاعدةُ برسالة — فيجب أن يراها،
    // ويجد ما يُعيد به المحاولة.
    demoCustomerCardThrows = 'المحادثة غير موجودة أو ليست لك.';
    addTearDown(() => demoCustomerCardThrows = null);
    await _open(tester);

    expect(find.byType(ErrorBlock), findsOneWidget);
    expect(find.textContaining('ليست لك'), findsOneWidget);
  });
}
