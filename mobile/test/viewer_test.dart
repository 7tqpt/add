// عارضُ المرفقات: يُفتح المرفقُ داخل التطبيق.
//
// **وما يُقاس هنا وما لا يُقاس، مقولٌ صراحةً:**
//
//   * يُقاس أنّ كلَّ عارضٍ يُفتح، ويعرض عنوانه، ويقول حين يعجز بدل أن يبقى
//     دائرةً تدور إلى الأبد.
//   * ويُقاس أنّ الصورة تُكبَّر بالإصبعين — وهي كلُّ الفائدة لمن أُرسل إليه
//     عقدٌ مصوَّر.
//   * **ولا يُقاس عرضُ ملفٍّ حقيقيّ:** لا شبكةَ في الاختبار ولا مُصيِّرَ
//     PDF أصليّ، فالجلبُ يفشل دائماً هنا. وما يُفحص هو أنّ الفشل **يُقال**،
//     لا أنّ الورقة تُرسم. وذاك يُجرَّب على جهاز.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/chat.dart';
import 'package:aras/src/ui/viewer.dart';

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

/// شاشةٌ فيها زرٌّ يفتح العارض — فيُقاس **الفتحُ** لا بناءُ الودجت وحدها.
Widget _opener(Future<void> Function(BuildContext) open) => Builder(
  builder: (context) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () => open(context),
        child: const Text('افتح'),
      ),
    ),
  ),
);

Future<void> _tapOpen(WidgetTester tester) async {
  await tester.tap(find.text('افتح'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(demoResetChat);

  // ==========================================================================
  //  الصورة
  // ==========================================================================

  testWidgets('عارضُ الصورة يُفتح باسم الملفّ', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(_opener((context) => openImageViewer(
          context,
          url: 'https://example.invalid/a.jpg',
          title: 'العقد.jpg',
        ))));
    await _tapOpen(tester);

    expect(find.text('العقد.jpg'), findsOneWidget);
  });

  testWidgets('**وتُكبَّر بالإصبعين**', (tester) async {
    // وهي كلُّ الفائدة: صورةُ عقدٍ بخطٍّ صغير تُقرأ بالتكبير أو لا تُقرأ.
    _phone(tester);
    await tester.pumpWidget(_wrap(_opener((context) => openImageViewer(
          context, url: 'https://example.invalid/a.jpg'))));
    await _tapOpen(tester);

    final zoom = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    expect(zoom.maxScale, greaterThan(1),
        reason: 'العارضُ لا يُكبّر — فلا فائدةَ من فتحه');
  });

  testWidgets('وصورةٌ لا تصل يُقال فيها ذلك', (tester) async {
    // **ودائرةٌ تدور إلى الأبد أسوأُ من رسالة:** من ينتظرها يظنّ الشبكةَ
    // بطيئةً فيبقى، ومن قرأ «تعذّر» أعاد المحاولة أو سأل صاحبَه.
    _phone(tester);
    await tester.pumpWidget(_wrap(_opener((context) => openImageViewer(
          context, url: 'https://example.invalid/a.jpg'))));
    await _tapOpen(tester);
    for (var n = 0; n < 6; n++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.textContaining('تعذّر'), findsOneWidget);
  });

  // ==========================================================================
  //  المقطع والملفّ
  // ==========================================================================

  testWidgets('وعارضُ المقطع يُفتح', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(_opener((context) =>
        openVideoViewer(context, url: 'https://example.invalid/a.mp4'))));
    await _tapOpen(tester);

    expect(find.text('مقطع'), findsOneWidget);
  });

  testWidgets('**وعارضُ الملفّ يُفتح باسمه ولا يخرج من التطبيق**', (tester) async {
    // وكان يُسلَّم إلى `launchUrl` بـ`externalApplication`: وأندرويد لا يعرض
    // PDF بنفسه، فيُنزّله إلى مجلّد التنزيلات ويترك صاحبَه يبحث عنه هناك.
    _phone(tester);
    await tester.pumpWidget(_wrap(_opener((context) => openPdfViewer(
          context,
          url: 'https://example.invalid/a.pdf',
          name: 'الفاتورة.pdf',
        ))));
    await _tapOpen(tester);

    expect(find.text('الفاتورة.pdf'), findsOneWidget,
        reason: 'لم تُفتح شاشةٌ داخل التطبيق');
  });

  testWidgets('وملفٌّ لا يصل يُقال فيه ذلك', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(_opener((context) => openPdfViewer(
          context, url: 'https://example.invalid/a.pdf', name: 'ملف.pdf'))));
    await _tapOpen(tester);
    for (var n = 0; n < 8; n++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(find.textContaining('تعذّر'), findsOneWidget);
  });

  // ==========================================================================
  //  وصلُ الدردشة
  // ==========================================================================

  testWidgets('**ولا ضغطةَ ميّتةً على مرفقٍ بلا رابط**', (tester) async {
    // الوضعُ التجريبيّ بلا سلّة، فلا رابطَ لمرفق. وفقاعةٌ تُضغط فلا يقع شيء
    // تجعل صاحبَها يضغط مرّاتٍ يظنّ التطبيق معلّقاً — فتُترك بلا `onTap`.
    _phone(tester);
    demoSendAttachment('cv1', ChatSide.customer, ChatAttachment.image);
    demoSendAttachment('cv1', ChatSide.customer, ChatAttachment.file,
        name: 'عقد.pdf');

    await tester.pumpWidget(_wrap(const ChatScreen(
      conversationId: 'cv1',
      otherName: 'قاعة التاج',
      mySide: ChatSide.customer,
    )));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    for (final key in ['chat-image', 'chat-file']) {
      final finder = find.byKey(ValueKey(key), skipOffstage: false);
      await tester.scrollUntilVisible(finder, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(tester.widget<InkWell>(finder).onTap, isNull, reason: key);
    }
  });
}
