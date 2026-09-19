// «الرسائل» تبويباً في شريط المزوّد — وما تبع ذلك في الرأس.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «أريد في شريط تضيف لي الرسائل»، ثمّ «شيلها من الشريط العلويّ أيقون
// الرسائل وحطّ بدلها أيقون الإشعارات».
//
// ── وثلاثةٌ تُقاس هنا ──────────────────────────────────────────────────────
//
// **١) ولا رأسانِ في شاشة.** شاشةُ المحادثات تُفتح طريقاً فلها `AppBar`
//    خاصّ؛ وتبويباً تحت الرأس الزجاجيّ يجب أن يسقط — وإلّا وقف شريطان
//    أحدُهما تحت الآخر. **ويُقاس عددُ `AppBar` لا شكلُ الشاشة.**
//
// **٢) والعدّادُ انتقل معها.** كان على أيقونة الرأس، فلمّا رُفعت لم يبقَ
//    موضعٌ يقول «عندك رسالة». فلو دخل البندُ بلا عدّادٍ لَذهبت فائدةٌ كانت
//    قائمة — وهو نقصٌ لا يُرى إلّا حين تصل رسالةٌ ولا يعلم بها أحد.
//
// **٣) وأيقونةُ الرسائل رُفعت من الرأس والجرسُ وحدَه فيه.**
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/conversations.dart';
import 'package:aras/src/screens/provider_shell.dart';
import 'package:aras/src/ui/kit.dart';

Session _provider() => Session()
  ..userId = 'u1'
  ..email = 'hall@sdd.company'
  ..appUserId = 'a1'
  ..providerId = 'p1'
  ..loading = false;

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
    child: ProviderShell(session: s),
  ),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('**الضغطُ على «الرسائل» يفتحها تبويباً**', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(_provider()));
    await _settle(tester);

    expect(find.byType(ConversationsScreen), findsNothing,
        reason: 'المحادثاتُ مفتوحةٌ قبل الضغط');

    await tester.tap(find.text('الرسائل'));
    await _settle(tester);

    expect(find.byType(ConversationsScreen), findsOneWidget);
  });

  testWidgets('**ولا رأسانِ في الشاشة**', (tester) async {
    // شريطُها الخاصُّ يسقط تبويباً — وإلّا وقف شريطان أحدُهما تحت الآخر.
    _phone(tester);
    await tester.pumpWidget(_wrap(_provider()));
    await _settle(tester);

    await tester.tap(find.text('الرسائل'));
    await _settle(tester);

    expect(find.byType(AppBar), findsNothing,
        reason: 'بقي شريطُ المحادثات الخاصّ تحت الرأس الزجاجيّ');
    expect(find.text('المحادثات'), findsNothing);
  });

  testWidgets('**وأيقونةُ الرسائل رُفعت من الرأس، والجرسُ باقٍ**', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(_provider()));
    await _settle(tester);

    expect(find.byType(ChatIconButton), findsNothing,
        reason: 'بقيت أيقونةُ الرسائل في الرأس — فللغرفة بابان');
    expect(find.byType(BellIconButton), findsOneWidget,
        reason: 'ذهب الجرسُ — وهو غيرُ الرسائل');
  });

  testWidgets('**وعنوانُ الرأس هو اسمُ البند المختار — في كلّ بند**',
      (tester) async {
    // **قائمتان تمشيان معاً**: أسماءُ البنود في الشريط، وعناوينُ الرأس في
    // قائمةٍ أخرى. فلو نُقل بندٌ في إحداهما ونُسي في الأخرى لَقال الرأسُ
    // «تقويمي» وصاحبُه في «خدماتي» — ولا شيءَ يكسر.
    //
    // كشفه ضابطٌ سالبٌ لم يسقط: بدّل القائمةَ الأولى وحدَها فبقيت الحزمةُ
    // خضراء.
    _phone(tester);
    await tester.pumpWidget(_wrap(_provider()));
    await _settle(tester);

    const labels = ['الطلبات', 'خدماتي', 'تقويمي', 'الرسائل', 'ملفي'];
    for (final label in labels) {
      await tester.tap(find.text(label));
      await _settle(tester);
      // **والاسمُ مرّةً واحدةً بالضبط**: بندُ المختار صار قرصاً بلا كلمة،
      // فلا يبقى اسمُه إلّا في الرأس. ولو افترقت القائمتان لَقال الرأسُ اسمَ
      // بندٍ آخرَ — فيُعدّ ذلك الاسمُ مرّتين (رأساً وبنداً) ويختفي هذا صفراً.
      expect(find.text(label), findsOneWidget,
          reason: 'عنوانُ الرأس ليس «$label» والبندُ مختار');
    }
  });

  group('عدّادُ ما لم يُقرأ', () {
    testWidgets('**والقشرةُ تمرّره إلى بنده لا تتركه صفراً**', (tester) async {
      // **ولا يُسأل الشريطُ عمّا يعرضه**: يُقرأ ما وصل البندَ، ويُقارَن
      // بما تقوله القاعةُ نفسُها. ولولا ذلك لَمرّ بندٌ مكتوبٌ عدّادُه صفراً.
      _phone(tester);
      await tester.pumpWidget(_wrap(_provider()));
      await _settle(tester);

      // **ولا `await` لنداءٍ مؤجَّلٍ داخل الاختبار**: ساعةُ الاختبار مزيّفةٌ
      // لا تتقدّم إلّا بالنبض، فانتظارُ `Api.myConversations()` هنا يعلّق
      // الاختبارَ إلى الأبد (وقع ذلك فعلاً). و`demoConversationList()` هي
      // البيانةُ نفسُها التي تُرجعها بلا خادم — تُقرأ فوراً.
      final expected = demoConversationList()
          .fold<int>(0, (n, c) => n + c.unreadCount);
      expect(expected, greaterThan(0),
          reason: 'بيانةُ العرض بلا رسائلَ غيرِ مقروءة — فلا شيءَ يُقاس');

      final bar = tester.widget<GlassNavBar>(find.byType(GlassNavBar));
      final chat = bar.items.firstWhere((i) => i.label == 'الرسائل');
      expect(chat.unread, expected, reason: 'العدّادُ لم يصل بندَه');
    });

    testWidgets('**يُرسم على البند حين يكون ثَمّ ما لم يُقرأ**', (tester) async {
      // **ولا يُسأل الشريطُ عن نفسه**: يُبنى بعددٍ معلومٍ ويُقرأ ما رُسم.
      _phone(tester);
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            extendBody: true,
            body: const SizedBox.expand(),
            bottomNavigationBar: GlassNavBar(
              index: 0,
              onSelect: (_) {},
              items: const [
                GlassNavItem(
                  label: 'الطلبات',
                  icon: Icons.inbox_outlined,
                  activeIcon: Icons.inbox,
                ),
                GlassNavItem(
                  label: 'الرسائل',
                  icon: Icons.quickreply_outlined,
                  activeIcon: Icons.quickreply_rounded,
                  unread: 3,
                ),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget, reason: 'لا عدّادَ على البند');
    });

    testWidgets('**ولا حبّةَ إن لم يبقَ ما لم يُقرأ**', (tester) async {
      // حبّةٌ صفريّةٌ تقول «عندك شيء» وليس ثَمّ شيء.
      _phone(tester);
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            extendBody: true,
            body: const SizedBox.expand(),
            bottomNavigationBar: GlassNavBar(
              index: 0,
              onSelect: (_) {},
              items: const [
                GlassNavItem(
                  label: 'الطلبات',
                  icon: Icons.inbox_outlined,
                  activeIcon: Icons.inbox,
                ),
                GlassNavItem(
                  label: 'الرسائل',
                  icon: Icons.quickreply_outlined,
                  activeIcon: Icons.quickreply_rounded,
                ),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(UnreadDot), findsNothing);
    });

    testWidgets('**ولا تزيح الحبّةُ أيقونةَ بندها عن موضعها**', (tester) async {
      // صفٌّ يدفع الأيقونةَ فتقف بنداً واحداً منحرفاً عن إخوته.
      //
      // **ويُقاس البندُ نفسُه بحبّةٍ وبلا حبّة** لا بندٌ بجاره: الخاناتُ
      // تقع في مواضعَ مختلفةٍ من الشريط، فمقارنةُ اثنتين منها تقيس موضعَ
      // الخانة لا أثرَ الحبّة.
      _phone(tester);

      Widget bar({required int unread}) => MaterialApp(
            theme: buildTheme(),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                extendBody: true,
                body: const SizedBox.expand(),
                bottomNavigationBar: GlassNavBar(
                  index: 0,
                  onSelect: (_) {},
                  items: [
                    const GlassNavItem(
                      label: 'أ',
                      icon: Icons.inbox_outlined,
                      activeIcon: Icons.inbox,
                    ),
                    GlassNavItem(
                      label: 'ج',
                      icon: Icons.quickreply_outlined,
                      activeIcon: Icons.quickreply_rounded,
                      unread: unread,
                    ),
                  ],
                ),
              ),
            ),
          );

      await tester.pumpWidget(bar(unread: 0));
      await tester.pumpAndSettle();
      final plain = tester.getCenter(find.byIcon(Icons.quickreply_outlined));

      await tester.pumpWidget(bar(unread: 5));
      await tester.pumpAndSettle();
      final badged = tester.getCenter(find.byIcon(Icons.quickreply_outlined));

      expect(badged.dx, closeTo(plain.dx, 0.5), reason: 'الحبّةُ أزاحت الأيقونة أفقيّاً');
      expect(badged.dy, closeTo(plain.dy, 0.5), reason: 'الحبّةُ أزاحت الأيقونة رأسيّاً');
    });
  });
}
