// **أرضيّةُ التطبيق كلِّه بيضاء — من أوّل شاشةٍ إلى آخرها.**
//
// ── وقرارٌ نُقض بطلبه، والأوّلُ مكتوبٌ لا ممحوّ ────────────────────────────
//
// قال أوّلاً: «أريد شكل الرسائل يكون أبيض والإشعارات كذلك»، فبُيِّضت
// الشاشتان **بكتابة اللون فيهما**، وكان في هذا الملفّ شرطان يحرسان ألّا
// تُبدَّل الثيمة: «**وهو يُبيّض كلَّ شاشةٍ في التطبيق، وذلك ما لم يُطلب**».
//
// ثمّ قال: «أريد كل التطبيق يكون أبيض كذا من أول صفحة إلى آخر صفحة» — وعُرضت
// عليه عشرُ لقطاتٍ حقيقيّةٍ لخمس شاشات، فأمر. **فانقلب الشرطان ولم
// يُحذفا**: صارا يحرسان أنّ الثيمةَ بيضاء، وأنّ الشاشتين لا تكتبان لوناً
// بأيديهما — إذ صارت الكتابةُ زائدةً تُخفي تبدّلَ الثيمة لو عاد يوماً.
//
// ── وما يُقاس هنا ──────────────────────────────────────────────────────────
//
//   ١) الشاشتان بيضاوان **كما تُرسمان**.
//   ٢) **والافتراضيُّ أبيضُ** — يُقرأ من `buildTheme()` ويُرى مرسوماً على
//      هيكلٍ لا يذكر لوناً، فيعمّ ما لم يُقَس من شاشات.
//   ٣) **ولا تكتبان اللونَ بأيديهما** — وإلّا بقيتا بيضاوين لو رُدَّت
//      الثيمةُ، فمرّ الشرطُ الأوّلُ على تطبيقٍ عاد ورديّاً.
//   ٤) **والفاصلُ بين مجموعات الصفوف ليس بلون الأرضيّة** — وإلّا اختفى.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/conversations.dart';
import 'package:aras/src/screens/notifications.dart';
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

/// لونُ أرضيّة الشاشة **كما تُرسم** — لا كما يُظنّ.
///
/// و`Scaffold.backgroundColor` قد يكون `null` فيقع على الثيمة، فيُقرأ الاثنان.
Color _background(WidgetTester tester) {
  final element = tester.element(find.byType(Scaffold).first);
  final scaffold = element.widget as Scaffold;
  return scaffold.backgroundColor ?? Theme.of(element).scaffoldBackgroundColor;
}

/// أيكتب الهيكلُ لونَه بيده؟
bool _ownColour(WidgetTester tester) {
  final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
  return scaffold.backgroundColor != null;
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
    // **ولا تكتب اللونَ بيدها.** انظر رأس الملفّ.
    expect(_ownColour(tester), isFalse,
        reason: 'كتبت لونَها بيدها، فتُخفي تبدّلَ الثيمة');
  });

  testWidgets('**و«الإشعارات» كذلك**', (tester) async {
    await _open(tester, NotificationsScreen(onOpen: (_, _) {}));
    expect(find.byType(ListTile), findsWidgets);
    expect(_background(tester), AppColors.surface);
    expect(_ownColour(tester), isFalse,
        reason: 'كتبت لونَها بيدها، فتُخفي تبدّلَ الثيمة');
  });

  testWidgets('**والافتراضيُّ أبيض — فيعمّ**', (tester) async {
    // وبهذا وحده تبيضّ الشاشاتُ التي لا حزمةَ لها.
    expect(buildTheme().scaffoldBackgroundColor, AppColors.surface,
        reason: 'عاد الافتراضيُّ ورديّاً');
  });

  testWidgets('**ويُرى مرسوماً لا مقروءاً من ثابت**', (tester) async {
    await _open(tester, const Scaffold());
    expect(_background(tester), AppColors.surface);
  });

  testWidgets('**والفاصلُ بين المجموعات يُرى على الأبيض**', (tester) async {
    // **وهذا ما كان يختفي.** `MenuGap` كان بلون الأرضيّة، فلمّا ابيضّت صار
    // أبيضَ على أبيض، فالتصقت أقسامُ «حسابي».
    await _open(tester, const Scaffold(body: MenuGap()));
    final box = tester.widget<Container>(
      find.descendant(of: find.byType(MenuGap), matching: find.byType(Container)),
    );
    expect(box.color, isNot(AppColors.surface),
        reason: 'الفاصلُ بلون الأرضيّة — فلا يُرى');
    expect(box.color, isNot(buildTheme().scaffoldBackgroundColor),
        reason: 'الفاصلُ يتبع الأرضيّةَ أيّاً كانت — فلا يفصل أبداً');
  });
}
