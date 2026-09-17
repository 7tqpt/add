// شريطُ المحادثة: صورةُ الطرف الآخر، وضغطةٌ تفتح ملفَّه.
//
// ── ما طلبه وما اختاره ─────────────────────────────────────────────────────
//
// «أحسّ الشريط العلوي يبغي تحط صورة وتخليه قابل للضغط وانتقل إلى الملف
// الشخصي». وعُرضت عليه ثلاثةُ أشكالٍ مرسومةٍ فاختار: **قرصٌ ومعه سهمٌ يقول
// إنّ الشريط يُضغط**.
//
// **والوجهةُ اختيارٌ ثانٍ، وقد تبدّل بطلبه.** عُرض عليه أوّلاً: أن تُبنى
// للعميل بطاقةٌ، أو أن تكون الضغطةُ للعميل وحدَه — فاختار الثاني. ثمّ ضغط
// بحساب مقدّم خدمةٍ فلم يقع شيء، فاختار أن تُبنى البطاقة.
//
// **فصار لكلّ جانبٍ وجهتُه:** العميلُ يفتح ملفَّ القاعة العامّ، ومقدّمُ
// الخدمة يفتح بطاقةَ العميل. **ولا تُخلطان** — ويُقاس ذلك.
//
// ── وما يُقاس هنا ──────────────────────────────────────────────────────────
//
// **ولا يُسأل الشريطُ عن نفسه.** وجودُ القرص لا يقول شيئاً عن الضغطة، ووجودُ
// `InkWell` لا يقول أين تذهب. فيُقاس الطرفان:
//
//   ١) **العميلُ يضغط فيُفتح `PublicProviderScreen` فعلاً** — تُسأل الشجرةُ
//      بعد الضغط، لا يُسأل الزرُّ أموجودٌ هو.
//   ٢) **ومقدّمُ الخدمة لا يجد ما يُضغط** — ولا سهمَ يَعِدُه بما لا يوجد.
//   ٣) **والقرصُ يُرسم في الحالين** — فالصورةُ طلبُه للطرفين.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/chat.dart';
import 'package:aras/src/screens/customer_card.dart';
import 'package:aras/src/screens/provider_public.dart';

const _tap = ValueKey('chat-open-profile');
const _disc = ValueKey('chat-other-avatar');

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

Widget _chat({required ChatSide side, String? providerId}) => ChatScreen(
  // **ومعرّفُ محادثةٍ من بيانة العرض**، وإلّا خرجت الشاشةُ فارغةً تُقاس فيها
  // شجرةٌ ناقصة.
  conversationId: 'c1',
  otherName: 'قاعة اللؤلؤة للأفراح',
  providerId: providerId,
  mySide: side,
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('**العميلُ يضغط الشريطَ فيُفتح ملفُّ القاعة**', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _wrap(_chat(side: ChatSide.customer, providerId: 'p1')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_tap), findsOneWidget);
    await tester.tap(find.byKey(_tap));
    await tester.pumpAndSettle();

    // **وتُسأل الشجرةُ بعد الضغط** — لا يُسأل الزرُّ أموجودٌ هو.
    expect(find.byType(PublicProviderScreen), findsOneWidget,
        reason: 'ضُغط الشريطُ فلم يُفتح شيء');
  });

  testWidgets('**ومقدّمُ الخدمة يضغط فتُفتح بطاقةُ العميل**', (tester) async {
    // **وهذا نقضٌ لما كان، بطلبه.** كان الشريطُ عنده لا يُضغط أصلاً — إذ لا
    // ملفَّ عامّ للعميل — فضغطه فلم يقع شيء، فاختار أن تُبنى البطاقة.
    _phone(tester);
    await tester.pumpWidget(
      _wrap(_chat(side: ChatSide.provider, providerId: 'p1')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_tap), findsOneWidget);
    await tester.tap(find.byKey(_tap));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerCardScreen), findsOneWidget,
        reason: 'ضُغط الشريطُ عند مقدّم الخدمة فلم يُفتح شيء');
    // **ولا يُفتح له ملفُّ القاعة**: وجهتُه العميلُ لا قاعتُه هو.
    expect(find.byType(PublicProviderScreen), findsNothing);
  });

  testWidgets('**ولا تُخلط الوجهتان**', (tester) async {
    // العميلُ لا يُفتح له بطاقةُ عميل، ومقدّمُ الخدمة لا يُفتح له ملفُّ
    // قاعة. ولولا هذا لَمرّ كسرٌ يفتح للجميع وجهةً واحدة.
    _phone(tester);
    await tester.pumpWidget(
      _wrap(_chat(side: ChatSide.customer, providerId: 'p1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_tap));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerCardScreen), findsNothing,
        reason: 'فُتحت للعميل بطاقةُ عميل');
  });

  testWidgets('**ولا ضغطةَ بلا مزوّدٍ معروف — عند العميل**', (tester) async {
    // محادثةٌ حُذف مزوّدُها (`on delete set null`) تبقى للعميل — وضغطةٌ
    // تفتح ملفَّ `null` تُسقط الشاشة.
    _phone(tester);
    await tester.pumpWidget(_wrap(_chat(side: ChatSide.customer)));
    await tester.pumpAndSettle();

    expect(find.byKey(_tap), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('**والقرصُ يُرسم للطرفين**', (tester) async {
    _phone(tester);
    for (final side in ChatSide.values) {
      await tester.pumpWidget(_wrap(_chat(side: side, providerId: 'p1')));
      await tester.pumpAndSettle();
      expect(find.byKey(_disc), findsOneWidget,
          reason: 'لا قرصَ في الشريط — وهو طلبُه للطرفين');
    }
  });

  testWidgets('**وحرفُ الاسم حين لا صورة — لا مربّعٌ مكسور**', (tester) async {
    // أكثرُ الناس بلا صورة، ومقدّمُ الخدمة لا تصله صورةُ العميل أصلاً.
    _phone(tester);
    await tester.pumpWidget(
      _wrap(_chat(side: ChatSide.customer, providerId: 'p1')),
    );
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byKey(_disc), matching: find.text('ق')),
        findsOneWidget,
        reason: 'خلا القرصُ من حرفٍ يدلّ على صاحبه');
  });
}
