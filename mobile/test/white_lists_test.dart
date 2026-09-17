// أرضيّةُ «المحادثات» و«الإشعارات» بيضاء — **وهاتان وحدَهما**.
//
// ── ما اختاره ──────────────────────────────────────────────────────────────
//
// «أريد شكل الرسائل يكون أبيض والإشعارات كذلك». وعُرضت عليه أربعُ لقطاتٍ
// **حقيقيّة** — الشاشتان المشحونتان، والفرقُ لونُ الأرضيّة لا غير — فأعاد
// البيضاوين.
//
// ── وما يُقاس هنا ──────────────────────────────────────────────────────────
//
// **ولا يكفي أن تُقاس البيضاء.** أقصرُ طريقٍ إلى البياض تبديلُ
// `scaffoldBackgroundColor` في الثيمة — وهو يُبيّض **كلَّ** شاشةٍ في
// التطبيق، وذلك ما لم يُطلب. فلو قيس البياضُ وحدَه لَمرّ ذلك الطريقُ
// وانقلبت الشاشاتُ كلُّها بلا أن يسقط شيء.
//
// فيُقاس الطرفان: أنّ الشاشتين بيضاوان، **وأنّ الافتراضيَّ ما زال ورديّاً**
// — يُقرأ من الثيمة ويُرى مرسوماً على هيكلٍ لا يذكر لوناً.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/conversations.dart';
import 'package:aras/src/screens/notifications.dart';

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

/// لونُ أرضيّة الشاشة **كما تُرسم** — لا كما يُظنّ.
///
/// و`Scaffold.backgroundColor` قد يكون `null` فيقع على الثيمة، فيُقرأ الاثنان.
Color _background(WidgetTester tester) {
  final element = tester.element(find.byType(Scaffold).first);
  final scaffold = element.widget as Scaffold;
  return scaffold.backgroundColor ?? Theme.of(element).scaffoldBackgroundColor;
}

Future<void> _open(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 1700);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_wrap(screen));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('**«المحادثات» على أرضيّةٍ بيضاء**', (tester) async {
    await _open(tester, const ConversationsScreen());
    expect(find.byType(ListTile), findsWidgets,
        reason: 'لم تُبنَ القائمة — فلا معنى لقياس أرضيّتها');
    expect(_background(tester), AppColors.surface);
  });

  testWidgets('**و«الإشعارات» كذلك**', (tester) async {
    await _open(tester, NotificationsScreen(onOpen: (_, _) {}));
    expect(find.byType(ListTile), findsWidgets);
    expect(_background(tester), AppColors.surface);
  });

  testWidgets('**والثيمةُ لم تُمسّ**', (tester) async {
    // **وهذا يمنع أقصرَ طريقٍ إلى البياض من أن يمرّ.** تبديلُ الثيمة يُبيّض
    // التطبيقَ كلَّه — ولم يُطلب إلّا شاشتان.
    expect(buildTheme().scaffoldBackgroundColor, AppColors.page,
        reason: 'بُيِّض التطبيقُ كلُّه من الثيمة');
  });

  testWidgets('**وشاشةٌ لا تذكر لوناً تبقى على الورديّ**', (tester) async {
    // **ولا يكفي أن يُقرأ الثابتُ من `buildTheme()`** — يُقاس ما يُرسم: هيكلٌ
    // لا يذكر لوناً، تحت ثيمة التطبيق، أيُّ لونٍ يخرج له؟
    //
    // **وحدُّ هذا يُقال:** يحرس أن يبقى الافتراضيُّ ورديّاً، **ولا يحرس أن
    // تكون كلُّ شاشةٍ أخرى على الافتراضيّ** — من بيَّض شاشةً ثالثةً بيده لا
    // يُسقطه شيءٌ هنا. ولم يُدَّعَ له ذلك.
    await _open(tester, const Scaffold());
    expect(_background(tester), AppColors.page,
        reason: 'تبدّل الافتراضيُّ فبُيِّض التطبيقُ كلُّه');
  });
}
