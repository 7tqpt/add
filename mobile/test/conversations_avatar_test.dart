// صورةُ الطرف الآخر في قائمة «المحادثات».
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «اجلب لي صورة من ملف العميل، خلّه تظهر في المحادثة بدل الحروف». وكانت
// القائمةُ ترسم حرفَ الاسم لكلّ الناس.
//
// ── وما يُقاس هنا ──────────────────────────────────────────────────────────
//
// **ولا يكفي أن يُقاس أنّ القرصَ موجود** — كان موجوداً قبلُ بالحرف. فيُقاس:
//
//   ١) **مسارُ الصورة يصل القرصَ** — لا يُبتلع في الطريق من الصفّ إليه.
//   ٢) **والحرفُ يبقى لمن لا صورةَ له** — وهو الغالب، ولا يُترك القرصُ أصمّ.
//   ٣) **والصفُّ يقرأ `otherAvatar` لا شيئاً آخر** — فلو غُيّر الحقلُ يوماً
//      سقط، ولم تبقَ القائمةُ ترسم حروفاً وهي تظنّ أنّها ترسم صوراً.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/api.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/conversations.dart';

const _disc = ValueKey('convo-avatar');

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

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1700);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_wrap(const ConversationsScreen()));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // **ولا سلّةَ في `flutter test`** — فتعود `avatarUrl` فارغةً أبداً، فكلُّ
    // قرصٍ يرسم حرفاً ولا يُقاس وصولُ المسار. **وقد كُتب ضابطٌ سالبٌ يمحو
    // المسارَ فلم يسقط**، فرُكّب هذا البديلُ وأُصلح القياس.
    Api.avatarUrlOverride = (path) => 'https://example.invalid/$path';
  });
  tearDown(() => Api.avatarUrlOverride = null);

  testWidgets('**القائمةُ ترسم قرصاً لكلّ صفّ**', (tester) async {
    await _open(tester);
    expect(find.byType(ListTile), findsWidgets);
    expect(find.byKey(_disc), findsWidgets, reason: 'لا قرصَ في الصفوف');
  });

  testWidgets('**ومن له مسارٌ تُرسم له صورة**', (tester) async {
    // **وهذا لبُّ الطلب.** ولا يسقط بسؤال «أموجودٌ القرص؟» — موجودٌ في
    // الحالين. يسقط لأنّ المسارَ يُتتبَّع من الصفّ إلى القرص.
    await _open(tester);

    final withPhoto = find.byKey(_disc).first;
    expect(find.descendant(of: withPhoto, matching: find.byType(Image)),
        findsOneWidget,
        reason: 'لم يصل المسارُ إلى القرص — فيرسم حرفاً وصاحبُه له صورة');
  });

  testWidgets('**والحرفُ لمن لا صورةَ له**', (tester) async {
    // **وهو الغالب:** أكثرُ الحسابات بلا صورة، ولا يُترك القرصُ أصمّ.
    await _open(tester);

    final noPhoto = find.byKey(_disc).at(1);
    expect(find.descendant(of: noPhoto, matching: find.byType(Image)),
        findsNothing,
        reason: 'رُسمت صورةٌ لمن لا مسارَ له');
    // **ويُقاس الحرفُ نفسُه لا وجودُ نصّ.** `Text('')` نصٌّ موجودٌ وقرصٌ
    // أصمّ — وقد كُتب ضابطٌ يمحو الحرفَ فلم يسقط لهذا بعينه.
    final text = tester.widget<Text>(
      find.descendant(of: noPhoto, matching: find.byType(Text)),
    );
    expect(text.data, isNotNull);
    expect(text.data!.isNotEmpty, isTrue, reason: 'قرصٌ أصمّ بلا حرف');
  });

  testWidgets('**والنموذجُ يحمل مسارَ الصورة من الخادم**', (tester) async {
    // **ولولا هذا لَبقي الرسمُ سليماً والمسارُ يضيع قبله.** يُقرأ العمودُ
    // كما يرسله الخادم — فلو غُيّر اسمُه يوماً سقط هنا لا في الجهاز.
    final row = Conversation.fromMap(const {
      'id': 'c1',
      'provider_id': 'p1',
      'other_name': 'قاعة التاج',
      'other_avatar': 'p1/logo-3.jpg',
      'my_side': 'customer',
      'last_message_at': '',
      'last_message_body': '',
      'unread_count': 0,
    });
    expect(row.otherAvatar, 'p1/logo-3.jpg');

    // ومن لم يُنزّل الملفَّ بعد لا يسقط: العمودُ يغيب فيُقرأ فارغاً.
    final old = Conversation.fromMap(const {
      'id': 'c1',
      'other_name': 'قاعة التاج',
      'my_side': 'customer',
      'last_message_at': '',
      'last_message_body': '',
      'unread_count': 0,
    });
    expect(old.otherAvatar, '');
  });
}
